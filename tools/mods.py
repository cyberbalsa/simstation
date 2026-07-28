#!/usr/bin/env python3
"""Validate and reproducibly package Sim Station folder/ZIP mods."""

from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import struct
import sys
import tomllib
import unicodedata
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PACK_ID = re.compile(r"^[a-z0-9][a-z0-9-]*(?:\.[a-z0-9][a-z0-9-]*)+$")
SEMVER = re.compile(
    r"^(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)"
    r"(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?"
    r"(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$"
)
CONTENT_ID = re.compile(
    r"^(?P<pack>[a-z0-9][a-z0-9-]*(?:\.[a-z0-9][a-z0-9-]*)+)"
    r":(?P<kind>[a-z][a-z0-9-]*)/(?P<name>[a-z0-9][a-z0-9/_-]*)$"
)
ROOT_KEYS = {
    "schema",
    "id",
    "version",
    "name",
    "description",
    "authors",
    "license",
    "homepage",
    "api",
    "class",
    "load_priority",
    "content",
    "localization",
    "atlas_indexes",
    "audio_manifests",
    "scenario_maps",
    "dependencies",
    "optional_dependencies",
    "conflicts",
    "load_after",
    "load_before",
    "replaces",
    "entrypoints",
    "state",
}
IGNORED_PARTS = {".git", ".cache", "__pycache__"}
IGNORED_FILES = {".DS_Store", "Thumbs.db"}
NATIVE_EXTENSIONS = {
    ".dll",
    ".dylib",
    ".exe",
    ".so",
    ".bat",
    ".cmd",
    ".com",
    ".ps1",
}
NESTED_ARCHIVE_EXTENSIONS = {".simmod", ".zip"}
DECLARED_ROOTS = {
    "content",
    "locales",
    "graphics",
    "audio",
    "generated",
    "lua",
    "maps",
    "scenarios",
    "tests",
}
MAX_ENTRIES = 20_000
MAX_PATH_BYTES = 240
MAX_ENTRY_SIZE = 512 * 1024 * 1024
MAX_TOTAL_SIZE = 2 * 1024 * 1024 * 1024
MAX_RATIO = 200


class ModError(ValueError):
    pass


def normalize_path(value: str) -> str:
    if "\0" in value or "\\" in value:
        raise ModError(f"unsafe package path: {value!r}")
    path = PurePosixPath(value)
    if path.is_absolute() or not value or value.endswith("/"):
        raise ModError(f"unsafe package path: {value!r}")
    if any(part in {"", ".", ".."} for part in path.parts):
        raise ModError(f"unsafe package path: {value!r}")
    if path.parts[0].endswith(":"):
        raise ModError(f"drive-prefixed package path: {value!r}")
    if len(value.encode("utf-8")) > MAX_PATH_BYTES:
        raise ModError(f"package path exceeds {MAX_PATH_BYTES} bytes: {value!r}")
    return path.as_posix()


def canonical_name(value: str) -> str:
    return unicodedata.normalize("NFC", value).lower()


def folder_files(folder: Path) -> list[tuple[str, bytes]]:
    result: list[tuple[str, bytes]] = []
    for path in sorted(folder.rglob("*")):
        if path.is_dir():
            continue
        relative = path.relative_to(folder).as_posix()
        if any(part in IGNORED_PARTS for part in PurePosixPath(relative).parts):
            continue
        if path.name in IGNORED_FILES:
            continue
        normalized = normalize_path(relative)
        if path.is_symlink():
            raise ModError(f"symlink is not allowed: {relative}")
        result.append((normalized, path.read_bytes()))
    return result


def archive_files(archive: Path) -> list[tuple[str, bytes]]:
    result: list[tuple[str, bytes]] = []
    seen: set[str] = set()
    total = 0
    with zipfile.ZipFile(archive) as package:
        entries = package.infolist()
        if len(entries) > MAX_ENTRIES:
            raise ModError(f"archive contains more than {MAX_ENTRIES} entries")
        for info in entries:
            if info.is_dir():
                continue
            name = normalize_path(info.filename)
            folded = canonical_name(name)
            if folded in seen:
                raise ModError(f"duplicate/case-colliding archive path: {name}")
            seen.add(folded)
            unix_mode = (info.external_attr >> 16) & 0o170000
            if unix_mode == 0o120000:
                raise ModError(f"archive symlink is not allowed: {name}")
            if unix_mode not in {0, 0o100000}:
                raise ModError(f"non-regular archive entry is not allowed: {name}")
            if info.flag_bits & 0x1:
                raise ModError(f"encrypted archive entry is not allowed: {name}")
            if info.file_size > MAX_ENTRY_SIZE:
                raise ModError(f"archive entry is too large: {name}")
            total += info.file_size
            if total > MAX_TOTAL_SIZE:
                raise ModError("archive expands beyond the 2 GiB package limit")
            if info.compress_size == 0:
                if info.file_size > 0:
                    raise ModError(
                        f"archive entry has invalid compression size: {name}"
                    )
            elif info.file_size / info.compress_size > MAX_RATIO:
                raise ModError(f"archive entry exceeds compression ratio limit: {name}")
            data = package.read(info)
            if len(data) != info.file_size:
                raise ModError(f"archive entry length mismatch: {name}")
            result.append((name, data))
    return sorted(result)


def parse_manifest(files: dict[str, bytes]) -> dict:
    raw = files.get("mod.toml")
    if raw is None:
        raise ModError("mod.toml must exist at the package root")
    if len(raw) > 1024 * 1024:
        raise ModError("mod.toml exceeds 1 MiB")
    try:
        manifest = tomllib.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, tomllib.TOMLDecodeError) as error:
        raise ModError(f"invalid mod.toml: {error}") from error
    unknown = sorted(set(manifest) - ROOT_KEYS)
    if unknown:
        raise ModError(f"unknown manifest keys: {', '.join(unknown)}")
    if manifest.get("schema") != 1:
        raise ModError("manifest schema must be 1")
    pack_id = manifest.get("id")
    if not isinstance(pack_id, str) or not PACK_ID.fullmatch(pack_id):
        raise ModError("manifest id must be a lower-case reverse-DNS ID")
    version = manifest.get("version")
    if not isinstance(version, str) or not SEMVER.fullmatch(version):
        raise ModError("manifest version must be strict SemVer 2.0")
    if manifest.get("class") not in {"data", "code"}:
        raise ModError("manifest class must be 'data' or 'code'")
    if not isinstance(manifest.get("name"), str) or not manifest["name"]:
        raise ModError("manifest name is required")
    if not isinstance(manifest.get("authors"), list) or not manifest["authors"]:
        raise ModError("manifest authors must be a non-empty array")
    if not isinstance(manifest.get("license"), str) or not manifest["license"]:
        raise ModError("manifest license is required")
    priority = manifest.get("load_priority", 0)
    if not isinstance(priority, int) or not -1000 <= priority <= 1000:
        raise ModError("load_priority must be an integer from -1000 through 1000")
    for field in ("dependencies", "optional_dependencies", "conflicts"):
        for index, record in enumerate(manifest.get(field, []), 1):
            if not isinstance(record, dict) or set(record) - {"id", "version"}:
                raise ModError(f"{field}[{index}] must contain only id/version")
            if not PACK_ID.fullmatch(str(record.get("id", ""))):
                raise ModError(f"{field}[{index}] has an invalid ID")
            if not isinstance(record.get("version"), str):
                raise ModError(f"{field}[{index}] version is required")
    if manifest["class"] == "code" and not manifest.get("entrypoints"):
        raise ModError("code packs require at least one entrypoint")
    for field in (
        "content",
        "localization",
        "atlas_indexes",
        "audio_manifests",
        "scenario_maps",
        "entrypoints",
    ):
        values = manifest.get(field, [])
        if not isinstance(values, list) or not all(
            isinstance(value, str) for value in values
        ):
            raise ModError(f"{field} must be an array of paths")
        for value in values:
            normalize_path(value.replace("*", "x").replace("?", "x"))
    for field in ("load_after", "load_before", "replaces"):
        values = manifest.get(field, [])
        if not isinstance(values, list) or not all(
            isinstance(value, str) for value in values
        ):
            raise ModError(f"{field} must be an array of strings")
    for path in manifest.get("entrypoints", []):
        if path not in files:
            raise ModError(f"entrypoint does not exist: {path}")
    return manifest


def glob_matches(pattern: str, names: list[str]) -> list[str]:
    normalize_path(pattern.replace("*", "x"))
    # pathlib's recursive matcher and fnmatch differ around **. Accept both,
    # then canonicalize ordering for identical folder/ZIP results.
    return sorted(
        name
        for name in names
        if fnmatch.fnmatchcase(name, pattern) or PurePosixPath(name).match(pattern)
    )


def content_id_kind(value: object, expected: str, label: str) -> re.Match[str]:
    match = CONTENT_ID.fullmatch(str(value or ""))
    if not match or match.group("kind") != expected:
        raise ModError(f"{label}: expected namespaced {expected} content ID")
    return match


def exact_integer(value: object) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def validate_scenario(definition: dict, path: str, index: int) -> None:
    prefix = f"{path}/definitions/{index}"
    allowed_definition = {
        "id",
        "kind",
        "schema",
        "name",
        "description",
        "replaces",
        "provenance",
        "areas",
        "map",
        "fixtures",
        "spawns",
        "meteor_targets",
        "power_supply_w",
        "starting_inventory",
    }
    unknown = sorted(set(definition) - allowed_definition)
    if unknown:
        raise ModError(f"{prefix}: unknown scenario keys: {', '.join(unknown)}")
    if definition.get("kind") != "scenario" or definition.get("schema") != 1:
        raise ModError(f"{prefix}: scenario maps require kind=scenario and schema=1")
    scenario_match = content_id_kind(
        definition.get("id"),
        "scenario",
        f"{prefix}/id",
    )
    nested_prefixes = {
        kind: (
            f"{scenario_match.group('pack')}:{kind}/"
            f"{scenario_match.group('name')}/"
        )
        for kind in ("scenario-area", "scenario-fixture", "scenario-spawn")
    }

    def nested_id(value: object, kind: str, label: str) -> str:
        content_id_kind(value, kind, label)
        identifier = str(value)
        if not identifier.startswith(nested_prefixes[kind]):
            raise ModError(
                f"{label}: ID must belong to scenario "
                f"{definition.get('id')}"
            )
        return identifier

    if not isinstance(definition.get("name"), str) or not definition["name"]:
        raise ModError(f"{prefix}: scenario name is required")
    map_data = definition.get("map")
    if not isinstance(map_data, dict) or map_data.get("format") != "simstation-map-v1":
        raise ModError(f"{prefix}: unsupported scenario map format")
    unknown = sorted(
        set(map_data)
        - {
            "format",
            "width",
            "height",
            "default_palette",
            "palette",
            "runs",
        }
    )
    if unknown:
        raise ModError(f"{prefix}: unknown map keys: {', '.join(unknown)}")
    width = map_data.get("width")
    height = map_data.get("height")
    if (
        not exact_integer(width)
        or not 16 <= width <= 256
        or not exact_integer(height)
        or not 16 <= height <= 256
    ):
        raise ModError(f"{prefix}: map dimensions must be integers from 16 to 256")
    areas = definition.get("areas", [])
    palette = map_data.get("palette")
    runs = map_data.get("runs", [])
    departments = {
        "cargo",
        "command",
        "engineering",
        "general",
        "medical",
        "science",
        "security",
        "service",
    }
    if not isinstance(areas, list) or len(areas) > 1024:
        raise ModError(f"{prefix}: invalid area table")
    area_keys: set[str] = set()
    for area_index, area in enumerate(areas, 1):
        if (
            not isinstance(area, dict)
            or set(area) - {"id", "key", "name", "department", "access", "source_path"}
            or area.get("id") != area_index
            or not isinstance(area.get("key"), str)
            or not area["key"]
            or not isinstance(area.get("name"), str)
            or not area["name"]
            or area.get("department") not in departments
            or (
                "source_path" in area
                and not isinstance(area["source_path"], str)
            )
        ):
            raise ModError(f"{prefix}: invalid area record {area_index}")
        nested_id(
            area["key"],
            "scenario-area",
            f"{prefix}/areas/{area_index}/key",
        )
        if area["key"] in area_keys:
            raise ModError(f"{prefix}: duplicate area key: {area['key']}")
        area_keys.add(area["key"])
        if not isinstance(area.get("access", "public"), str) or not area.get(
            "access", "public"
        ):
            raise ModError(f"{prefix}: invalid area access {area_index}")
    if not isinstance(palette, list) or not palette or len(palette) > 2048:
        raise ModError(f"{prefix}: invalid map palette")
    palette_keys: set[str] = set()
    palette_semantics: set[str] = set()
    for palette_index, cell in enumerate(palette, 1):
        if not isinstance(cell, dict) or set(cell) - {
            "key",
            "tile",
            "structure",
            "cable",
            "pressurized",
            "area",
            "access",
            "turf_kind",
            "wall_kind",
            "features",
            "source_turfs",
            "source_objects",
        }:
            raise ModError(f"{prefix}: palette {palette_index} must be an object")
        key = cell.get("key")
        if not isinstance(key, str) or not key or key in palette_keys:
            raise ModError(f"{prefix}: invalid/duplicate palette key")
        palette_keys.add(key)
        if cell.get("tile") not in {"space", "floor"}:
            raise ModError(f"{prefix}: invalid palette tile")
        if cell.get("structure", "empty") not in {
            "empty",
            "wall",
            "door_closed",
            "door_open",
        }:
            raise ModError(f"{prefix}: invalid palette structure")
        tile = cell["tile"]
        turf_kind = cell.get("turf_kind")
        if turf_kind is not None and (
            turf_kind
            not in {"space", "plating", "floor", "reinforced_floor"}
            or (tile == "space") != (turf_kind == "space")
        ):
            raise ModError(f"{prefix}: palette turf kind must agree with tile")
        structure = cell.get("structure", "empty")
        wall_kind = cell.get("wall_kind")
        if wall_kind is not None and (
            wall_kind not in {"standard", "reinforced"}
            or structure != "wall"
        ):
            raise ModError(f"{prefix}: palette wall kind requires a wall")
        allowed_features = {
            "window",
            "grille",
            "table",
            "chair",
            "light",
            "storage",
            "crate",
            "lattice",
            "catwalk",
            "pipe",
            "disposal",
            "sign",
            "decal",
        }
        features = cell.get("features", [])
        if (
            not isinstance(features, list)
            or any(
                not isinstance(feature, str)
                or feature not in allowed_features
                for feature in features
            )
            or features != sorted(set(features))
        ):
            raise ModError(
                f"{prefix}: palette features must be sorted and unique"
            )
        feature_set = set(features)
        if "window" in feature_set and structure not in {
            "wall",
            "door_closed",
            "door_open",
        }:
            raise ModError(
                f"{prefix}: palette window feature requires a boundary"
            )
        if "crate" in feature_set and "storage" not in feature_set:
            raise ModError(f"{prefix}: palette crate feature requires storage")
        for source_key, source_root in (
            ("source_turfs", "/turf"),
            ("source_objects", "/obj"),
        ):
            values = cell.get(source_key, [])
            if (
                not isinstance(values, list)
                or len(values) > 64
                or any(
                    not isinstance(value, str)
                    or not value
                    or len(value) > 1024
                    or not (
                        value == source_root
                        or value.startswith(source_root + "/")
                    )
                    for value in values
                )
                or values != sorted(set(values))
            ):
                raise ModError(
                    f"{prefix}: palette {source_key} must be sorted unique "
                    f"{source_root} paths"
                )
        for flag in ("cable", "pressurized"):
            if flag in cell and not isinstance(cell[flag], bool):
                raise ModError(f"{prefix}: palette {flag} must be boolean")
        area_id = cell.get("area", 0)
        if not exact_integer(area_id) or not 0 <= area_id <= len(areas):
            raise ModError(f"{prefix}: invalid palette area")
        if "access" in cell and (
            not isinstance(cell["access"], str)
            or not cell["access"]
            or structure not in {"door_closed", "door_open"}
        ):
            raise ModError(f"{prefix}: palette access requires a door")
        semantic = json.dumps(
            {
                "access": cell.get("access", ""),
                "area": area_id,
                "cable": cell.get("cable", False),
                "features": features,
                "pressurized": cell.get("pressurized", False),
                "source_objects": cell.get("source_objects", []),
                "source_turfs": cell.get("source_turfs", []),
                "structure": structure,
                "tile": tile,
                "turf_kind": turf_kind
                or ("space" if tile == "space" else "floor"),
                "wall_kind": wall_kind or "",
            },
            sort_keys=True,
            separators=(",", ":"),
        )
        if semantic in palette_semantics:
            raise ModError(f"{prefix}: duplicate semantic palette record")
        palette_semantics.add(semantic)
    default_palette = map_data.get("default_palette", 1)
    if not exact_integer(default_palette) or not 1 <= default_palette <= len(palette):
        raise ModError(f"{prefix}: invalid default palette")
    if not isinstance(runs, list) or len(runs) > 200_000:
        raise ModError(f"{prefix}: invalid map runs")
    previous_end = 0
    previous_palette = 0
    size = width * height
    dense = [default_palette] * size
    for run_index, run in enumerate(runs, 1):
        if (
            not isinstance(run, list)
            or len(run) != 3
            or any(not exact_integer(value) for value in run)
        ):
            raise ModError(f"{prefix}: invalid map run {run_index}")
        start, length, palette_index = run
        finish = start + length - 1
        if (
            start <= previous_end
            or start < 1
            or finish > size
            or length < 1
            or length > width
            or (start - 1) // width != (finish - 1) // width
            or not 1 <= palette_index <= len(palette)
            or palette_index == default_palette
        ):
            raise ModError(f"{prefix}: out-of-order or invalid map run {run_index}")
        if (
            start == previous_end + 1
            and palette_index == previous_palette
            and (start - 1) // width == (previous_end - 1) // width
        ):
            raise ModError(f"{prefix}: adjacent map runs must be merged")
        dense[start - 1 : finish] = [palette_index] * length
        previous_end = finish
        previous_palette = palette_index

    def cell_at(x: int, y: int) -> dict:
        return palette[dense[(y - 1) * width + x - 1] - 1]

    def position(record: dict, label: str) -> tuple[int, int]:
        x = record.get("x")
        y = record.get("y")
        if (
            not exact_integer(x)
            or not 1 <= x <= width
            or not exact_integer(y)
            or not 1 <= y <= height
        ):
            raise ModError(f"{prefix}: invalid {label} coordinate")
        return x, y

    def passable(cell: dict) -> bool:
        dense_features = {"grille", "table", "storage", "crate"}
        return (
            cell["tile"] == "floor"
            and cell.get("structure", "empty")
            not in {"wall", "door_closed"}
            and not dense_features.intersection(cell.get("features", []))
        )

    def fixture_anchorable(cell: dict) -> bool:
        # Upstream wall-mounted and over-table machines legitimately share a
        # source turf with dense furniture. They remain adjacent-interaction
        # targets even though actors and spawn points cannot occupy that turf.
        return (
            cell["tile"] == "floor"
            and cell.get("structure", "empty")
            not in {"wall", "door_closed"}
        )

    def touches_cable(x: int, y: int) -> bool:
        for candidate_x, candidate_y in (
            (x, y),
            (x - 1, y),
            (x + 1, y),
            (x, y - 1),
            (x, y + 1),
        ):
            if (
                1 <= candidate_x <= width
                and 1 <= candidate_y <= height
                and cell_at(candidate_x, candidate_y).get("cable", False)
            ):
                return True
        return False

    fixtures = definition.get("fixtures", [])
    if not isinstance(fixtures, list) or len(fixtures) > 8192:
        raise ModError(f"{prefix}: invalid fixtures")
    fixture_ids: set[str] = set()
    last_fixture_id = ""
    fixture_kinds = {
        "apc",
        "barcode_computer",
        "battery",
        "cargo_pad",
        "circulator",
        "fabricator",
        "generator",
        "generic",
        "nanofab",
        "portable_scrubber",
        "reclaimer",
        "refinery",
        "scrubber",
        "supply_console",
        "vent",
        "vent_pump",
    }
    for record_index, fixture in enumerate(fixtures, 1):
        if not isinstance(fixture, dict) or set(fixture) - {
            "definition_id",
            "id",
            "kind",
            "name",
            "source_overrides",
            "x",
            "y",
            "department",
            "source_path",
        }:
            raise ModError(f"{prefix}: invalid fixture record {record_index}")
        if (
            fixture.get("department", "general") not in departments
            or (
                "name" in fixture
                and (
                    not isinstance(fixture["name"], str)
                    or not fixture["name"]
                )
            )
            or (
                "source_path" in fixture
                and not isinstance(fixture["source_path"], str)
            )
            or (
                "definition_id" in fixture
                and (
                    not CONTENT_ID.fullmatch(str(fixture["definition_id"]))
                    or CONTENT_ID.fullmatch(
                        str(fixture["definition_id"])
                    ).group("kind")
                    != "machine"
                )
            )
        ):
            raise ModError(f"{prefix}: invalid fixture metadata {record_index}")
        source_overrides = fixture.get("source_overrides", {})
        if not isinstance(source_overrides, dict):
            raise ModError(f"{prefix}: invalid fixture source overrides {record_index}")
        for override_name, override_value in source_overrides.items():
            if (
                not isinstance(override_name, str)
                or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", override_name)
                or not isinstance(override_value, (str, int, bool))
                or isinstance(override_value, float)
                or (
                    isinstance(override_value, int)
                    and not isinstance(override_value, bool)
                    and abs(override_value) > 9_007_199_254_740_991
                )
            ):
                raise ModError(
                    f"{prefix}: unsafe fixture source override {record_index}"
                )
        fixture_id = fixture.get("id")
        nested_id(
            fixture_id,
            "scenario-fixture",
            f"{prefix}/fixtures/{record_index}/id",
        )
        if (
            fixture_id in fixture_ids
            or fixture_id <= last_fixture_id
            or fixture.get("kind") not in fixture_kinds
        ):
            raise ModError(f"{prefix}: invalid/unsorted fixture {record_index}")
        fixture_ids.add(fixture_id)
        last_fixture_id = fixture_id
        x, y = position(fixture, f"fixture {record_index}")
        if not fixture_anchorable(cell_at(x, y)):
            raise ModError(f"{prefix}: invalid fixture anchor at {x},{y}")
        if fixture["kind"] == "apc":
            if cell_at(x, y).get("area", 0) == 0 or not touches_cable(x, y):
                raise ModError(f"{prefix}: invalid APC service at {x},{y}")
        elif fixture["kind"] == "generator" and not touches_cable(x, y):
            raise ModError(f"{prefix}: unwired generator at {x},{y}")

    spawns = definition.get("spawns", [])
    if not isinstance(spawns, list) or len(spawns) > 1024:
        raise ModError(f"{prefix}: invalid spawns")
    spawn_ids: set[str] = set()
    spawn_positions: set[tuple[int, int]] = set()
    last_spawn_id = ""
    for record_index, spawn in enumerate(spawns, 1):
        if not isinstance(spawn, dict) or set(spawn) - {
            "id",
            "x",
            "y",
            "job",
            "department",
            "source_path",
        }:
            raise ModError(f"{prefix}: invalid spawn record {record_index}")
        if (
            spawn.get("department", "general") not in departments
            or (
                "source_path" in spawn
                and not isinstance(spawn["source_path"], str)
            )
        ):
            raise ModError(f"{prefix}: invalid spawn metadata {record_index}")
        spawn_id = spawn.get("id")
        nested_id(
            spawn_id,
            "scenario-spawn",
            f"{prefix}/spawns/{record_index}/id",
        )
        if spawn_id in spawn_ids or spawn_id <= last_spawn_id:
            raise ModError(f"{prefix}: invalid/unsorted spawn {record_index}")
        spawn_ids.add(spawn_id)
        last_spawn_id = spawn_id
        if "job" in spawn:
            content_id_kind(
                spawn["job"],
                "job",
                f"{prefix}/spawns/{record_index}/job",
            )
        x, y = position(spawn, f"spawn {record_index}")
        if (x, y) in spawn_positions or not passable(cell_at(x, y)):
            raise ModError(f"{prefix}: invalid spawn anchor at {x},{y}")
        spawn_positions.add((x, y))

    targets = definition.get("meteor_targets", [])
    if not isinstance(targets, list) or len(targets) > 1024:
        raise ModError(f"{prefix}: invalid meteor targets")
    target_positions: set[tuple[int, int]] = set()
    last_target = (0, 0)
    for target_index, target in enumerate(targets, 1):
        if not isinstance(target, dict) or set(target) != {"x", "y"}:
            raise ModError(f"{prefix}: invalid meteor target {target_index}")
        x, y = position(target, f"meteor target {target_index}")
        order_key = (y, x)
        cell = cell_at(x, y)
        neighbors = (
            (x - 1, y),
            (x + 1, y),
            (x, y - 1),
            (x, y + 1),
        )
        exposed = any(
            candidate_x < 1
            or candidate_x > width
            or candidate_y < 1
            or candidate_y > height
            or cell_at(candidate_x, candidate_y)["tile"] == "space"
            for candidate_x, candidate_y in neighbors
        )
        if (
            order_key <= last_target
            or (x, y) in target_positions
            or cell["tile"] != "floor"
            or cell.get("structure", "empty") != "wall"
            or not exposed
        ):
            raise ModError(f"{prefix}: invalid meteor target at {x},{y}")
        target_positions.add((x, y))
        last_target = order_key

    power_supply = definition.get("power_supply_w", 0)
    if not exact_integer(power_supply) or not 0 <= power_supply <= 1_000_000_000:
        raise ModError(f"{prefix}: invalid power supply")
    inventory = definition.get("starting_inventory", {})
    if not isinstance(inventory, dict):
        raise ModError(f"{prefix}: invalid starting inventory")
    for item_id, quantity in inventory.items():
        content_id_kind(item_id, "item", f"{prefix}/starting_inventory")
        if not exact_integer(quantity) or not 0 <= quantity <= 1_000_000_000:
            raise ModError(f"{prefix}: invalid inventory quantity for {item_id}")

    provenance = definition.get("provenance")
    if provenance is not None:
        if (
            not isinstance(provenance, dict)
            or provenance.get("schema") != 1
            or not isinstance(provenance.get("method"), str)
            or not provenance["method"]
            or not isinstance(provenance.get("sources"), list)
            or not provenance["sources"]
            or not isinstance(provenance.get("tool"), dict)
        ):
            raise ModError(f"{prefix}: invalid scenario provenance")
        for source_index, source in enumerate(provenance["sources"], 1):
            if (
                not isinstance(source, dict)
                or not re.fullmatch(r"[0-9a-f]{40}", str(source.get("commit", "")))
                or not re.fullmatch(r"[0-9a-f]{40}", str(source.get("git_blob", "")))
                or not re.fullmatch(r"[0-9a-f]{64}", str(source.get("sha256", "")))
                or not isinstance(source.get("path"), str)
                or source["path"].startswith("/")
                or ".." in PurePosixPath(source["path"]).parts
            ):
                raise ModError(f"{prefix}: invalid provenance source {source_index}")


def _validate_machine_state(value: object, label: str, depth: int = 0) -> None:
    if depth > 8:
        raise ModError(f"{label}: machine state is nested too deeply")
    if value is None or isinstance(value, (str, bool)):
        return
    if exact_integer(value):
        if abs(value) > 9_007_199_254_740_991:
            raise ModError(f"{label}: machine state integer is out of range")
        return
    if isinstance(value, list):
        if len(value) > 4096:
            raise ModError(f"{label}: machine state array is too large")
        for child_index, child in enumerate(value, 1):
            _validate_machine_state(child, f"{label}/{child_index}", depth + 1)
        return
    if isinstance(value, dict):
        if len(value) > 4096:
            raise ModError(f"{label}: machine state object is too large")
        for key, child in value.items():
            if (
                not isinstance(key, str)
                or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_.-]*", key)
            ):
                raise ModError(f"{label}: invalid machine state key")
            _validate_machine_state(child, f"{label}/{key}", depth + 1)
        return
    raise ModError(f"{label}: machine state must use JSON integer primitives")


def validate_machine(definition: dict, path: str, index: int) -> None:
    prefix = f"{path}/definitions/{index}"
    allowed = {
        "actions",
        "behavior",
        "fidelity",
        "fixture_kind",
        "health",
        "id",
        "kind",
        "map_override_fields",
        "name_key",
        "power",
        "process",
        "replaces",
        "schema",
        "source",
        "state_defaults",
        "tags",
        "wires",
    }
    unknown = sorted(set(definition) - allowed)
    if unknown:
        raise ModError(f"{prefix}: unknown machine keys: {', '.join(unknown)}")
    if definition.get("kind") != "machine" or definition.get("schema") != 2:
        raise ModError(f"{prefix}: machine definitions require kind=machine/schema=2")
    content_id_kind(definition.get("id"), "machine", f"{prefix}/id")
    if (
        not isinstance(definition.get("name_key"), str)
        or not definition["name_key"]
        or not isinstance(definition.get("fixture_kind"), str)
        or not re.fullmatch(r"[a-z][a-z0-9_]*", definition["fixture_kind"])
        or not isinstance(definition.get("behavior"), str)
        or not re.fullmatch(
            r"[a-z0-9.-]+:machine-behavior/[a-z0-9/_-]+",
            definition["behavior"],
        )
    ):
        raise ModError(f"{prefix}: invalid machine identity")

    source = definition.get("source")
    if (
        not isinstance(source, dict)
        or set(source) - {"commit", "files", "repository", "type_path"}
        or source.get("repository") != "goonstation/goonstation"
        or not re.fullmatch(r"[0-9a-f]{40}", str(source.get("commit", "")))
        or not isinstance(source.get("type_path"), str)
        or not source["type_path"].startswith("/")
        or not isinstance(source.get("files"), list)
        or not source["files"]
        or not all(
            isinstance(file, str)
            and file
            and not file.startswith("/")
            and ".." not in PurePosixPath(file).parts
            for file in source["files"]
        )
    ):
        raise ModError(f"{prefix}: invalid machine source provenance")

    process = definition.get("process")
    if (
        not isinstance(process, dict)
        or set(process)
        - {
            "class",
            "interval_ds",
            "mult_base_ds",
            "mult_cap_ds",
            "tier",
        }
        or process.get("class") not in {"atmos", "general", "none"}
        or not exact_integer(process.get("tier"))
        or not 0 <= process["tier"] <= 6
        or not exact_integer(process.get("interval_ds"))
        or not 0 <= process["interval_ds"] <= 1_000_000
        or not exact_integer(process.get("mult_base_ds"))
        or not 0 <= process["mult_base_ds"] <= 10_000_000
        or not exact_integer(process.get("mult_cap_ds"))
        or not process["mult_base_ds"] <= process["mult_cap_ds"] <= 100_000_000
    ):
        raise ModError(f"{prefix}: invalid machine process contract")

    power = definition.get("power")
    if (
        not isinstance(power, dict)
        or set(power)
        - {"channel", "idle_w", "priority", "requires_power"}
        or not isinstance(power.get("requires_power"), bool)
        or power.get("channel")
        not in {"environment", "equipment", "lighting", "none"}
        or not exact_integer(power.get("idle_w"))
        or not 0 <= power["idle_w"] <= 1_000_000_000
        or not exact_integer(power.get("priority"))
        or not 0 <= power["priority"] <= 1000
    ):
        raise ModError(f"{prefix}: invalid machine power contract")

    health = definition.get("health")
    if health is not None:
        if (
            not isinstance(health, dict)
            or set(health) - {"break_at", "maximum", "repair_at"}
            or not exact_integer(health.get("maximum"))
            or not 1 <= health["maximum"] <= 1_000_000
            or not exact_integer(health.get("break_at"))
            or not 0 <= health["break_at"] <= health["maximum"]
            or not exact_integer(health.get("repair_at"))
            or not health["break_at"]
            <= health["repair_at"]
            <= health["maximum"]
        ):
            raise ModError(f"{prefix}: invalid machine health contract")

    tags = definition.get("tags", [])
    if (
        not isinstance(tags, list)
        or tags != sorted(set(tags))
        or not all(
            isinstance(tag, str) and re.fullmatch(r"[a-z][a-z0-9_-]*", tag)
            for tag in tags
        )
    ):
        raise ModError(f"{prefix}: machine tags must be sorted and unique")
    overrides = definition.get("map_override_fields", [])
    if (
        not isinstance(overrides, list)
        or overrides != sorted(set(overrides))
        or not all(
            isinstance(field, str)
            and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", field)
            for field in overrides
        )
    ):
        raise ModError(f"{prefix}: invalid machine map override fields")
    _validate_machine_state(
        definition.get("state_defaults", {}),
        f"{prefix}/state_defaults",
    )

    wires = definition.get("wires", [])
    wire_ids: set[str] = set()
    wire_indexes: set[int] = set()
    if not isinstance(wires, list) or len(wires) > 64:
        raise ModError(f"{prefix}: invalid machine wire harness")
    for wire_index, wire in enumerate(wires, 1):
        if (
            not isinstance(wire, dict)
            or set(wire) - {"id", "index", "source_symbol"}
            or not isinstance(wire.get("id"), str)
            or not re.fullmatch(r"[a-z][a-z0-9-]*", wire["id"])
            or not exact_integer(wire.get("index"))
            or not 1 <= wire["index"] <= 64
            or not isinstance(wire.get("source_symbol"), str)
            or not wire["source_symbol"]
            or wire["id"] in wire_ids
            or wire["index"] in wire_indexes
        ):
            raise ModError(f"{prefix}: invalid wire record {wire_index}")
        wire_ids.add(wire["id"])
        wire_indexes.add(wire["index"])

    actions = definition.get("actions", [])
    action_ids: set[str] = set()
    allowed_requirement_keys = {
        "access_any",
        "allow_remote",
        "modes",
        "not_broken",
        "panel_open",
        "power",
        "tools_all",
        "tools_any",
    }
    if not isinstance(actions, list) or len(actions) > 256:
        raise ModError(f"{prefix}: invalid machine actions")
    for action_index, action in enumerate(actions, 1):
        if (
            not isinstance(action, dict)
            or set(action)
            - {
                "duration_ds",
                "handler",
                "id",
                "implemented",
                "parameters",
                "range",
                "requires",
                "source_symbol",
                "tags",
            }
            or not isinstance(action.get("id"), str)
            or not re.fullmatch(r"[a-z][a-z0-9-]*", action["id"])
            or action["id"] in action_ids
            or not isinstance(action.get("handler"), str)
            or not re.fullmatch(r"[a-z][a-z0-9_.-]*", action["handler"])
            or not isinstance(action.get("source_symbol"), str)
            or not action["source_symbol"]
            or not isinstance(action.get("implemented"), bool)
            or action.get("range") not in {"adjacent", "none", "remote-or-adjacent"}
            or not exact_integer(action.get("duration_ds"))
            or not 0 <= action["duration_ds"] <= 10_000_000
        ):
            raise ModError(f"{prefix}: invalid machine action {action_index}")
        action_ids.add(action["id"])
        requirements = action.get("requires", {})
        if (
            not isinstance(requirements, dict)
            or set(requirements) - allowed_requirement_keys
        ):
            raise ModError(f"{prefix}: invalid action requirements {action_index}")
        for boolean_key in (
            "allow_remote",
            "not_broken",
            "panel_open",
            "power",
        ):
            if boolean_key in requirements and not isinstance(
                requirements[boolean_key], bool
            ):
                raise ModError(
                    f"{prefix}: invalid {boolean_key} requirement {action_index}"
                )
        for list_key in ("access_any", "modes", "tools_all", "tools_any"):
            values = requirements.get(list_key, [])
            if (
                not isinstance(values, list)
                or values != sorted(set(values))
                or not all(isinstance(value, str) and value for value in values)
            ):
                raise ModError(
                    f"{prefix}: invalid {list_key} requirement {action_index}"
                )
        parameters = action.get("parameters", {})
        if not isinstance(parameters, dict):
            raise ModError(f"{prefix}: invalid action parameters {action_index}")
        for parameter_name, parameter in parameters.items():
            if (
                not re.fullmatch(r"[a-z][a-z0-9_]*", str(parameter_name))
                or not isinstance(parameter, dict)
                or set(parameter) - {"maximum", "minimum", "type", "values"}
                or parameter.get("type")
                not in {"boolean", "content-id", "enum", "integer"}
            ):
                raise ModError(
                    f"{prefix}: invalid action parameter {action_index}"
                )
            if parameter["type"] == "integer":
                if (
                    not exact_integer(parameter.get("minimum"))
                    or not exact_integer(parameter.get("maximum"))
                    or parameter["minimum"] > parameter["maximum"]
                ):
                    raise ModError(
                        f"{prefix}: invalid integer parameter {action_index}"
                    )
            elif parameter["type"] == "enum":
                values = parameter.get("values")
                if (
                    not isinstance(values, list)
                    or not values
                    or values != sorted(set(values), key=str)
                    or not all(isinstance(value, (str, int)) for value in values)
                ):
                    raise ModError(
                        f"{prefix}: invalid enum parameter {action_index}"
                    )
        action_tags = action.get("tags", [])
        if (
            not isinstance(action_tags, list)
            or action_tags != sorted(set(action_tags))
            or not all(isinstance(tag, str) and tag for tag in action_tags)
        ):
            raise ModError(f"{prefix}: invalid action tags {action_index}")

    fidelity = definition.get("fidelity")
    if (
        not isinstance(fidelity, dict)
        or set(fidelity) - {"ledger", "profile"}
        or fidelity.get("profile") != "goon-near-1"
        or not isinstance(fidelity.get("ledger"), list)
        or not fidelity["ledger"]
    ):
        raise ModError(f"{prefix}: invalid machine fidelity ledger")
    ledger_features: set[str] = set()
    for ledger_index, record in enumerate(fidelity["ledger"], 1):
        if (
            not isinstance(record, dict)
            or set(record) - {"feature", "note", "source", "status"}
            or not isinstance(record.get("feature"), str)
            or not record["feature"]
            or record["feature"] in ledger_features
            or record.get("status")
            not in {
                "deferred",
                "deterministic-equivalent",
                "engine-adapted",
                "exact",
                "intentional-fix",
                "not-applicable",
            }
            or not isinstance(record.get("source"), str)
            or not record["source"]
            or ("note" in record and not isinstance(record["note"], str))
        ):
            raise ModError(f"{prefix}: invalid fidelity record {ledger_index}")
        ledger_features.add(record["feature"])


def validate_structure(definition: dict, path: str, index: int) -> None:
    prefix = f"{path}/definitions/{index}"
    allowed = {
        "actions",
        "fidelity",
        "id",
        "interaction_profile",
        "kind",
        "material_cost",
        "name_key",
        "native_component",
        "replaces",
        "schema",
        "source",
        "sprites",
        "work_milliticks",
    }
    unknown = sorted(set(definition) - allowed)
    if unknown:
        raise ModError(f"{prefix}: unknown structure keys: {', '.join(unknown)}")
    if definition.get("kind") != "structure" or definition.get("schema") != 2:
        raise ModError(
            f"{prefix}: structure definitions require kind=structure/schema=2"
        )
    content_id_kind(definition.get("id"), "structure", f"{prefix}/id")
    if (
        not isinstance(definition.get("name_key"), str)
        or not definition["name_key"]
        or not isinstance(definition.get("native_component"), str)
        or not re.fullmatch(
            r"[a-z][a-z0-9_-]*",
            definition["native_component"],
        )
        or not isinstance(definition.get("interaction_profile"), str)
        or not re.fullmatch(
            r"[a-z0-9][a-z0-9.-]*-v[1-9]\d*",
            definition["interaction_profile"],
        )
        or not exact_integer(definition.get("material_cost"))
        or not 0 <= definition["material_cost"] <= 1_000_000
        or not exact_integer(definition.get("work_milliticks"))
        or not 0 <= definition["work_milliticks"] <= 1_000_000_000
    ):
        raise ModError(f"{prefix}: invalid structure identity")

    sprites = definition.get("sprites")
    if (
        not isinstance(sprites, dict)
        or not sprites
        or not all(
            isinstance(state, str)
            and re.fullmatch(r"[a-z][a-z0-9_]*", state)
            and isinstance(alias, str)
            and re.fullmatch(r"[a-z][a-z0-9_]*", alias)
            for state, alias in sprites.items()
        )
    ):
        raise ModError(f"{prefix}: invalid structure sprites")

    source = definition.get("source")
    if (
        not isinstance(source, dict)
        or set(source) - {"commit", "files", "repository", "type_path"}
        or source.get("repository") != "goonstation/goonstation"
        or not re.fullmatch(r"[0-9a-f]{40}", str(source.get("commit", "")))
        or not isinstance(source.get("type_path"), str)
        or not source["type_path"].startswith("/")
        or not isinstance(source.get("files"), list)
        or not source["files"]
        or source["files"] != sorted(set(source["files"]))
        or not all(
            isinstance(file, str)
            and file
            and not file.startswith("/")
            and ".." not in PurePosixPath(file).parts
            for file in source["files"]
        )
    ):
        raise ModError(f"{prefix}: invalid structure source provenance")

    actions = definition.get("actions")
    if not isinstance(actions, list) or not actions or len(actions) > 128:
        raise ModError(f"{prefix}: invalid structure actions")
    action_ids: set[str] = set()
    ordered_action_ids: list[str] = []
    allowed_requirement_keys = {
        "access_any",
        "allow_remote",
        "power",
        "tools_all",
        "tools_any",
        "unoccupied",
    }
    for action_index, action in enumerate(actions, 1):
        if (
            not isinstance(action, dict)
            or set(action)
            - {
                "duration_ds",
                "handler",
                "id",
                "implemented",
                "parameters",
                "range",
                "requires",
                "source_symbol",
                "tags",
            }
            or not isinstance(action.get("id"), str)
            or not re.fullmatch(r"[a-z][a-z0-9-]*", action["id"])
            or action["id"] in action_ids
            or not isinstance(action.get("handler"), str)
            or not re.fullmatch(r"[a-z][a-z0-9_.-]*", action["handler"])
            or not isinstance(action.get("source_symbol"), str)
            or not action["source_symbol"].startswith("/")
            or not isinstance(action.get("implemented"), bool)
            or action.get("range") not in {"adjacent", "none", "remote-or-adjacent"}
            or not exact_integer(action.get("duration_ds"))
            or not 0 <= action["duration_ds"] <= 10_000_000
        ):
            raise ModError(f"{prefix}: invalid structure action {action_index}")
        action_ids.add(action["id"])
        ordered_action_ids.append(action["id"])

        requirements = action.get("requires", {})
        if (
            not isinstance(requirements, dict)
            or set(requirements) - allowed_requirement_keys
        ):
            raise ModError(
                f"{prefix}: invalid structure action requirements {action_index}"
            )
        for boolean_key in ("allow_remote", "power", "unoccupied"):
            if boolean_key in requirements and not isinstance(
                requirements[boolean_key],
                bool,
            ):
                raise ModError(
                    f"{prefix}: invalid {boolean_key} requirement {action_index}"
                )
        for list_key in ("access_any", "tools_all", "tools_any"):
            values = requirements.get(list_key, [])
            if (
                not isinstance(values, list)
                or values != sorted(set(values))
                or not all(isinstance(value, str) and value for value in values)
            ):
                raise ModError(
                    f"{prefix}: invalid {list_key} requirement {action_index}"
                )

        parameters = action.get("parameters", {})
        if not isinstance(parameters, dict):
            raise ModError(
                f"{prefix}: invalid structure action parameters {action_index}"
            )
        for parameter_name, parameter in parameters.items():
            if (
                not re.fullmatch(r"[a-z][a-z0-9_]*", str(parameter_name))
                or not isinstance(parameter, dict)
                or set(parameter) - {"maximum", "minimum", "type", "values"}
                or parameter.get("type")
                not in {"boolean", "content-id", "enum", "integer"}
            ):
                raise ModError(
                    f"{prefix}: invalid structure action parameter {action_index}"
                )
            if parameter["type"] == "integer" and (
                not exact_integer(parameter.get("minimum"))
                or not exact_integer(parameter.get("maximum"))
                or parameter["minimum"] > parameter["maximum"]
            ):
                raise ModError(
                    f"{prefix}: invalid structure integer parameter {action_index}"
                )
            if parameter["type"] == "enum":
                values = parameter.get("values")
                if (
                    not isinstance(values, list)
                    or not values
                    or values != sorted(set(values), key=str)
                    or not all(isinstance(value, (str, int)) for value in values)
                ):
                    raise ModError(
                        f"{prefix}: invalid structure enum parameter {action_index}"
                    )

        action_tags = action.get("tags", [])
        if (
            not isinstance(action_tags, list)
            or action_tags != sorted(set(action_tags))
            or not all(isinstance(tag, str) and tag for tag in action_tags)
        ):
            raise ModError(
                f"{prefix}: invalid structure action tags {action_index}"
            )
    if ordered_action_ids != sorted(ordered_action_ids):
        raise ModError(f"{prefix}: structure actions must be sorted by ID")

    fidelity = definition.get("fidelity")
    if (
        not isinstance(fidelity, dict)
        or set(fidelity) - {"ledger", "profile"}
        or fidelity.get("profile") != "goon-near-1"
        or not isinstance(fidelity.get("ledger"), list)
        or not fidelity["ledger"]
    ):
        raise ModError(f"{prefix}: invalid structure fidelity ledger")
    ledger_features: set[str] = set()
    for ledger_index, record in enumerate(fidelity["ledger"], 1):
        if (
            not isinstance(record, dict)
            or set(record) - {"feature", "note", "source", "status"}
            or not isinstance(record.get("feature"), str)
            or not record["feature"]
            or record["feature"] in ledger_features
            or record.get("status")
            not in {
                "deferred",
                "deterministic-equivalent",
                "engine-adapted",
                "exact",
                "intentional-fix",
                "not-applicable",
            }
            or not isinstance(record.get("source"), str)
            or not record["source"].startswith("/")
            or ("note" in record and not isinstance(record["note"], str))
        ):
            raise ModError(f"{prefix}: invalid structure fidelity {ledger_index}")
        ledger_features.add(record["feature"])


def validate_content(manifest: dict, files: dict[str, bytes]) -> dict:
    names = sorted(files)
    selected_by_field: dict[str, list[str]] = {
        "content": [],
        "scenario_maps": [],
    }
    definitions = 0
    seen_ids: set[str] = set()
    declared_replacements = set(manifest.get("replaces", []))
    for field in ("content", "scenario_maps"):
        for pattern in manifest.get(field, []):
            if not isinstance(pattern, str):
                raise ModError(f"{field} patterns must be strings")
            matches = glob_matches(pattern, names)
            if not matches:
                raise ModError(f"{field} pattern matched no files: {pattern}")
            selected_by_field[field].extend(matches)
    selected = sorted(
        set(selected_by_field["content"]) | set(selected_by_field["scenario_maps"])
    )
    scenario_paths = set(selected_by_field["scenario_maps"])
    for path in selected:
        if not path.endswith(".json"):
            raise ModError(f"content/scenario file must be JSON: {path}")
        try:
            document = json.loads(files[path])
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise ModError(f"invalid JSON in {path}: {error}") from error
        values = document.get("definitions") if isinstance(document, dict) else document
        if not isinstance(values, list):
            raise ModError(f"{path}: definitions must be an array")
        for index, definition in enumerate(values):
            if not isinstance(definition, dict):
                raise ModError(f"{path}/definitions/{index}: expected object")
            content_id = definition.get("id")
            match = CONTENT_ID.fullmatch(str(content_id or ""))
            if not match:
                raise ModError(f"{path}/definitions/{index}: invalid content ID")
            if content_id in seen_ids:
                raise ModError(f"duplicate content ID inside pack: {content_id}")
            seen_ids.add(content_id)
            replacement = definition.get("replaces")
            if match.group("pack") != manifest["id"] and not replacement:
                raise ModError(f"new ID is outside pack namespace: {content_id}")
            if definition.get("kind", match.group("kind")) != match.group("kind"):
                raise ModError(f"kind does not match content ID: {content_id}")
            if replacement:
                if (
                    replacement != content_id
                    or replacement not in declared_replacements
                ):
                    raise ModError(
                        f"undeclared or mismatched replacement: {content_id}"
                    )
            if path in scenario_paths:
                validate_scenario(definition, path, index)
            elif match.group("kind") == "machine":
                validate_machine(definition, path, index)
            elif match.group("kind") == "structure":
                validate_structure(definition, path, index)
            definitions += 1
    return {
        "content_files": sorted(set(selected_by_field["content"])),
        "scenario_map_files": sorted(scenario_paths),
        "definition_count": definitions,
        "content_ids": sorted(seen_ids),
    }


def validate_path(path: Path) -> dict:
    if path.is_dir():
        records = folder_files(path)
        representation = "folder"
    elif path.is_file() and path.suffix == ".simmod":
        records = archive_files(path)
        representation = "simmod"
    else:
        raise ModError("mod path must be a folder or .simmod archive")
    if len(records) > MAX_ENTRIES:
        raise ModError(f"package contains more than {MAX_ENTRIES} files")
    folded: set[str] = set()
    total = 0
    files: dict[str, bytes] = {}
    for name, data in records:
        canonical = canonical_name(name)
        if canonical in folded:
            raise ModError(f"duplicate/case-colliding path: {name}")
        folded.add(canonical)
        total += len(data)
        if len(data) > MAX_ENTRY_SIZE or total > MAX_TOTAL_SIZE:
            raise ModError("package exceeds expansion limits")
        suffix = PurePosixPath(name).suffix.lower()
        if suffix in NATIVE_EXTENSIONS:
            raise ModError(f"native/executable file is not allowed: {name}")
        if suffix in NESTED_ARCHIVE_EXTENSIONS:
            raise ModError(f"nested archive is not allowed: {name}")
        files[name] = data
    manifest = parse_manifest(files)
    for name in files:
        first = PurePosixPath(name).parts[0]
        allowed_root_file = name == "mod.toml" or first.startswith(
            ("README", "LICENSE", "NOTICE", "CREDITS")
        )
        if not allowed_root_file and first not in DECLARED_ROOTS:
            raise ModError(f"undeclared package root entry: {first}")
        if manifest["class"] == "data" and name.endswith(".lua"):
            raise ModError(f"data-only pack contains Lua code: {name}")
    content = validate_content(manifest, files)
    canonical = hashlib.sha256()
    for name, data in records:
        encoded = name.encode("utf-8")
        canonical.update(struct.pack("<Q", len(encoded)))
        canonical.update(encoded)
        canonical.update(struct.pack("<Q", len(data)))
        canonical.update(data)
    return {
        "ok": True,
        "path": str(path),
        "representation": representation,
        "id": manifest["id"],
        "version": manifest["version"],
        "class": manifest["class"],
        "file_count": len(files),
        "expanded_bytes": total,
        "tree_sha256": canonical.hexdigest(),
        **content,
    }


def package_folder(folder: Path, output: Path | None) -> tuple[Path, dict]:
    report = validate_path(folder)
    manifest = tomllib.loads((folder / "mod.toml").read_text(encoding="utf-8"))
    if output is None:
        output = (
            ROOT / "dist" / "mods" / f"{manifest['id']}-{manifest['version']}.simmod"
        )
    output.parent.mkdir(parents=True, exist_ok=True)
    records = folder_files(folder)
    with zipfile.ZipFile(
        output,
        "w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=9,
        strict_timestamps=True,
    ) as archive:
        for name, data in records:
            info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            archive.writestr(info, data, compresslevel=9)
    archive_report = validate_path(output)
    archive_report["archive_sha256"] = hashlib.sha256(output.read_bytes()).hexdigest()
    archive_report["source_tree_sha256"] = report["tree_sha256"]
    return output, archive_report


def print_report(report: dict) -> None:
    print(json.dumps(report, indent=2, sort_keys=True))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    validate = commands.add_parser("validate")
    validate.add_argument("path", type=Path)
    package = commands.add_parser("package")
    package.add_argument("path", type=Path)
    package.add_argument("--output", type=Path)
    test = commands.add_parser("test")
    test.add_argument("path", type=Path)
    return parser


def main() -> None:
    args = build_parser().parse_args()
    try:
        if args.command == "validate":
            print_report(validate_path(args.path.resolve()))
        elif args.command == "package":
            output, report = package_folder(
                args.path.resolve(),
                args.output.resolve() if args.output else None,
            )
            report["output"] = str(output)
            print_report(report)
        elif args.command == "test":
            source = validate_path(args.path.resolve())
            output, packaged = package_folder(args.path.resolve(), None)
            if source["content_ids"] != packaged["content_ids"]:
                raise ModError("folder/archive registries differ")
            print_report(
                {
                    "ok": True,
                    "folder": source,
                    "archive": packaged,
                    "temporary_output": str(output),
                }
            )
    except (OSError, ModError, zipfile.BadZipFile) as error:
        print(f"mod error: {error}", file=sys.stderr)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
