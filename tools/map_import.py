#!/usr/bin/env python3
"""Read-only, deterministic analysis of Goonstation DMM/TGM maps.

The pinned Goon checkout may be sparse. Map bytes are therefore read from Git
blobs at an exact commit instead of from the working tree. Output is JSON on
stdout and contains no timestamps or host-specific absolute paths.

Examples:

    python3 tools/map_import.py inventory
    python3 tools/map_import.py inventory --prefix maps/ --max-depth 1
    python3 tools/map_import.py analyze maps/cogmap.dmm --top 30 --pretty
"""

from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import tomllib
from typing import Iterable, Iterator, Sequence

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REPOSITORY = ROOT / "assets" / "cache" / "goonstation"
GOON_LOCK = ROOT / "assets" / "upstream" / "goon" / "upstream.lock.toml"
FORMAT_VERSION = 1
TGM_MARKER = "MAP CONVERTED BY dmm2tgm.py"
PATH_TOKEN = re.compile(r"/[A-Za-z0-9_/-]+")
INTEGER = re.compile(r"[+-]?[0-9]+")
IDENTIFIER = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
SIMSTATION_MAP_FORMAT = "simstation-map-v1"
SIMSTATION_SCENARIO_SCHEMA = 1
DEFAULT_STARTING_INVENTORY = {
    "org.simstation.core:item/cable-coil": 24,
    "org.simstation.core:item/iron-ore": 36,
    "org.simstation.core:item/steel-sheet": 8,
}

JOB_ADAPTATIONS = {
    "bartender": "chef",
    "botanist": "botanist",
    "captain": "assistant",
    "chef": "chef",
    "chief_engineer": "engineer",
    "detective": "security_officer",
    "engineer": "engineer",
    "geneticist": "doctor",
    "head_of_security": "security_officer",
    "janitor": "janitor",
    "mail_courier": "cargo_technician",
    "medical_director": "doctor",
    "medical_doctor": "doctor",
    "medical_trainee": "doctor",
    "miner": "cargo_technician",
    "quartermaster": "cargo_technician",
    "rancher": "botanist",
    "research_director": "scientist",
    "roboticist": "scientist",
    "scientist": "scientist",
    "security_assistant": "security_officer",
    "security_officer": "security_officer",
    "technical_trainee": "engineer",
}


class MapError(ValueError):
    """A map grammar or validation error with stable source context."""


@dataclass(frozen=True)
class Atom:
    path: str
    variables: tuple[str, ...]
    literal_overrides: tuple[tuple[str, int | str | bool], ...] = ()


@dataclass(frozen=True)
class DictionaryEntry:
    key: str
    atoms: tuple[Atom, ...]


@dataclass(frozen=True)
class GridBlock:
    origin: tuple[int, int, int]
    rows: tuple[tuple[str, ...], ...]


@dataclass(frozen=True)
class ParsedMap:
    source: str
    format: str
    key_width: int
    entries: dict[str, DictionaryEntry]
    blocks: tuple[GridBlock, ...]


@dataclass(frozen=True)
class GitBlob:
    oid: str
    size: int
    path: str


def _location(text: str, offset: int) -> str:
    line = text.count("\n", 0, offset) + 1
    last_newline = text.rfind("\n", 0, offset)
    column = offset + 1 if last_newline < 0 else offset - last_newline
    return f"{line}:{column}"


def _error(source: str, text: str, offset: int, message: str) -> MapError:
    return MapError(f"{source}:{_location(text, offset)}: {message}")


def _skip_ignored(text: str, offset: int) -> int:
    """Skip whitespace plus DM line/block comments."""

    length = len(text)
    while offset < length:
        if text[offset].isspace():
            offset += 1
            continue
        if text.startswith("//", offset):
            newline = text.find("\n", offset + 2)
            return length if newline < 0 else _skip_ignored(text, newline + 1)
        if text.startswith("/*", offset):
            end = text.find("*/", offset + 2)
            if end < 0:
                return length
            offset = end + 2
            continue
        break
    return offset


def _read_quoted(text: str, offset: int, source: str) -> tuple[str, int]:
    if offset >= len(text) or text[offset] != '"':
        raise _error(source, text, offset, "expected '\"'")
    result: list[str] = []
    offset += 1
    while offset < len(text):
        character = text[offset]
        if character == '"':
            return "".join(result), offset + 1
        if character == "\\":
            if offset + 1 >= len(text):
                raise _error(source, text, offset, "unterminated escape")
            escaped = text[offset + 1]
            result.append(
                {
                    "n": "\n",
                    "r": "\r",
                    "t": "\t",
                    '"': '"',
                    "\\": "\\",
                }.get(escaped, escaped)
            )
            offset += 2
            continue
        result.append(character)
        offset += 1
    raise _error(source, text, offset, "unterminated quoted string")


def _expect(text: str, offset: int, expected: str, source: str) -> int:
    offset = _skip_ignored(text, offset)
    if not text.startswith(expected, offset):
        raise _error(source, text, offset, f"expected {expected!r}")
    return offset + len(expected)


def _balanced_content(
    text: str,
    offset: int,
    opening: str,
    closing: str,
    source: str,
) -> tuple[str, int]:
    """Return content and the offset after a balanced delimiter pair."""

    if offset >= len(text) or text[offset] != opening:
        raise _error(source, text, offset, f"expected {opening!r}")
    start = offset + 1
    offset = start
    depth = 1
    quoted = False
    escaped = False
    while offset < len(text):
        character = text[offset]
        if quoted:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == '"':
                quoted = False
            offset += 1
            continue
        if text.startswith("//", offset):
            newline = text.find("\n", offset + 2)
            if newline < 0:
                break
            offset = newline + 1
            continue
        if text.startswith("/*", offset):
            end = text.find("*/", offset + 2)
            if end < 0:
                raise _error(source, text, offset, "unterminated block comment")
            offset = end + 2
            continue
        if character == '"':
            quoted = True
        elif character == opening:
            depth += 1
        elif character == closing:
            depth -= 1
            if depth == 0:
                return text[start:offset], offset + 1
        offset += 1
    raise _error(source, text, offset, f"unterminated {opening!r} block")


def _variable_names(content: str) -> tuple[str, ...]:
    """Extract only top-level map override assignment names."""

    names: set[str] = set()
    offset = 0
    parens = 0
    brackets = 0
    while offset < len(content):
        if content.startswith("//", offset):
            newline = content.find("\n", offset + 2)
            offset = len(content) if newline < 0 else newline + 1
            continue
        if content.startswith("/*", offset):
            end = content.find("*/", offset + 2)
            offset = len(content) if end < 0 else end + 2
            continue
        if content[offset] == '"':
            _, offset = _read_quoted(content, offset, "<override>")
            continue
        character = content[offset]
        if character == "(":
            parens += 1
            offset += 1
            continue
        if character == ")":
            parens = max(0, parens - 1)
            offset += 1
            continue
        if character == "[":
            brackets += 1
            offset += 1
            continue
        if character == "]":
            brackets = max(0, brackets - 1)
            offset += 1
            continue
        if parens == 0 and brackets == 0:
            match = IDENTIFIER.match(content, offset)
            if match:
                cursor = match.end()
                while cursor < len(content) and content[cursor].isspace():
                    cursor += 1
                if (
                    cursor < len(content)
                    and content[cursor] == "="
                    and not content.startswith("==", cursor)
                ):
                    names.add(match.group(0))
                offset = match.end()
                continue
        offset += 1
    return tuple(sorted(names))


def _literal_override_value(value: str) -> int | str | bool | None:
    """Decode the deliberately small, data-only subset used by map fixtures.

    Map compilation must never evaluate DM.  Integer-valued decimal/scientific
    literals, booleans, and quoted strings are safe to preserve as instance
    data; expressions and type paths remain visible through ``variables`` but
    are not imported as executable values.
    """

    value = value.strip()
    if value in {"TRUE", "true"}:
        return True
    if value in {"FALSE", "false"}:
        return False
    if re.fullmatch(r"[+-]?\d+", value):
        return int(value)
    if re.fullmatch(
        r"[+-]?(?:\d+\.\d*|\d*\.\d+|\d+)[eE][+-]?\d+",
        value,
    ):
        try:
            number = Decimal(value)
        except InvalidOperation:
            return None
        if (
            number.is_finite()
            and number == number.to_integral_value()
            and abs(number) <= 9_007_199_254_740_991
        ):
            return int(number)
        return None
    if len(value) >= 2 and value[0] == value[-1] == '"':
        try:
            decoded = json.loads(value)
        except json.JSONDecodeError:
            return None
        return decoded if isinstance(decoded, str) else None
    return None


def _literal_overrides(content: str) -> tuple[tuple[str, int | str | bool], ...]:
    """Extract top-level ``name = literal`` assignments without running DM."""

    assignments: dict[str, int | str | bool] = {}
    offset = 0
    start = 0
    quoted = False
    escaped = False
    parens = 0
    brackets = 0
    segments: list[str] = []
    while offset < len(content):
        character = content[offset]
        if quoted:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == '"':
                quoted = False
            offset += 1
            continue
        if content.startswith("//", offset):
            newline = content.find("\n", offset + 2)
            offset = len(content) if newline < 0 else newline + 1
            continue
        if content.startswith("/*", offset):
            end = content.find("*/", offset + 2)
            offset = len(content) if end < 0 else end + 2
            continue
        if character == '"':
            quoted = True
        elif character == "(":
            parens += 1
        elif character == ")":
            parens = max(0, parens - 1)
        elif character == "[":
            brackets += 1
        elif character == "]":
            brackets = max(0, brackets - 1)
        elif character == ";" and parens == 0 and brackets == 0:
            segments.append(content[start:offset])
            start = offset + 1
        offset += 1
    segments.append(content[start:])

    for segment in segments:
        match = re.match(r"\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$", segment, re.S)
        if not match:
            continue
        decoded = _literal_override_value(match.group(2))
        if decoded is not None:
            assignments[match.group(1)] = decoded
    return tuple(sorted(assignments.items()))


def _parse_atoms(body: str, source: str) -> tuple[Atom, ...]:
    atoms: list[Atom] = []
    offset = 0
    while True:
        offset = _skip_ignored(body, offset)
        while offset < len(body) and body[offset] == ",":
            offset = _skip_ignored(body, offset + 1)
        if offset >= len(body):
            break
        match = PATH_TOKEN.match(body, offset)
        if not match:
            raise _error(source, body, offset, "expected an atom type path")
        path = match.group(0).rstrip("/")
        if not path:
            raise _error(source, body, offset, "empty atom type path")
        offset = _skip_ignored(body, match.end())
        variables: tuple[str, ...] = ()
        literal_overrides: tuple[tuple[str, int | str | bool], ...] = ()
        if offset < len(body) and body[offset] == "{":
            overrides, offset = _balanced_content(body, offset, "{", "}", source)
            variables = _variable_names(overrides)
            literal_overrides = _literal_overrides(overrides)
            offset = _skip_ignored(body, offset)
        atoms.append(
            Atom(
                path=path,
                variables=variables,
                literal_overrides=literal_overrides,
            )
        )
        if offset < len(body) and body[offset] != ",":
            raise _error(source, body, offset, "expected ',' between atoms")
    return tuple(atoms)


def _read_integer(text: str, offset: int, source: str) -> tuple[int, int]:
    offset = _skip_ignored(text, offset)
    match = INTEGER.match(text, offset)
    if not match:
        raise _error(source, text, offset, "expected integer coordinate")
    return int(match.group(0)), match.end()


def _grid_rows(
    payload: str,
    key_width: int,
    source: str,
    origin: tuple[int, int, int],
) -> tuple[tuple[str, ...], ...]:
    payload = payload.replace("\r\n", "\n").replace("\r", "\n")
    if payload.startswith("\n"):
        payload = payload[1:]
    if payload.endswith("\n"):
        payload = payload[:-1]
    if not payload:
        raise MapError(f"{source}: empty grid payload at {origin}")
    rows: list[tuple[str, ...]] = []
    for row_number, line in enumerate(payload.split("\n"), 1):
        if not line:
            raise MapError(f"{source}: empty grid row {row_number} at {origin}")
        if len(line) % key_width:
            raise MapError(
                f"{source}: grid row {row_number} at {origin} has "
                f"{len(line)} characters, not a multiple of key width "
                f"{key_width}"
            )
        rows.append(
            tuple(
                line[index : index + key_width]
                for index in range(0, len(line), key_width)
            )
        )
    widths = {len(row) for row in rows}
    if len(widths) != 1:
        raise MapError(f"{source}: ragged grid block at {origin}")
    return tuple(rows)


def parse_map(data: bytes, source: str = "<map>") -> ParsedMap:
    """Parse a DMM/TGM byte string without interpreting DM expressions."""

    try:
        text = data.decode("utf-8-sig")
    except UnicodeDecodeError as error:
        raise MapError(f"{source}:{error.start}: map is not valid UTF-8") from error

    entries: dict[str, DictionaryEntry] = {}
    raw_blocks: list[tuple[tuple[int, int, int], str]] = []
    offset = _skip_ignored(text, 0)
    while offset < len(text):
        if text[offset] == '"':
            key, offset = _read_quoted(text, offset, source)
            offset = _expect(text, offset, "=", source)
            offset = _skip_ignored(text, offset)
            body, offset = _balanced_content(text, offset, "(", ")", source)
            if key in entries:
                raise MapError(f"{source}: duplicate dictionary key {key!r}")
            entries[key] = DictionaryEntry(
                key=key,
                atoms=_parse_atoms(body, f"{source}:key {key!r}"),
            )
        elif text[offset] == "(":
            offset += 1
            x, offset = _read_integer(text, offset, source)
            offset = _expect(text, offset, ",", source)
            y, offset = _read_integer(text, offset, source)
            offset = _expect(text, offset, ",", source)
            z, offset = _read_integer(text, offset, source)
            offset = _expect(text, offset, ")", source)
            offset = _expect(text, offset, "=", source)
            offset = _expect(text, offset, "{", source)
            offset = _skip_ignored(text, offset)
            payload, offset = _read_quoted(text, offset, source)
            offset = _expect(text, offset, "}", source)
            raw_blocks.append(((x, y, z), payload))
        else:
            raise _error(
                source,
                text,
                offset,
                "expected dictionary key or coordinate block",
            )
        offset = _skip_ignored(text, offset)

    if not entries:
        raise MapError(f"{source}: map has no dictionary entries")
    if not raw_blocks:
        raise MapError(f"{source}: map has no coordinate blocks")
    key_widths = {len(key) for key in entries}
    if 0 in key_widths or len(key_widths) != 1:
        raise MapError(
            f"{source}: dictionary keys do not share one non-zero width: "
            f"{sorted(key_widths)}"
        )
    key_width = next(iter(key_widths))
    blocks = tuple(
        GridBlock(
            origin=origin,
            rows=_grid_rows(payload, key_width, source, origin),
        )
        for origin, payload in raw_blocks
    )
    generated_tgm = TGM_MARKER in text[:256]
    singleton_columns = all(
        all(len(row) == 1 for row in block.rows) for block in blocks
    )
    map_format = (
        "tgm" if generated_tgm else ("tgm-like" if singleton_columns else "dmm")
    )
    return ParsedMap(
        source=source,
        format=map_format,
        key_width=key_width,
        entries=entries,
        blocks=blocks,
    )


def _atom_kind(path: str) -> str:
    if path == "/area" or path.startswith("/area/"):
        return "area"
    if path == "/turf" or path.startswith("/turf/"):
        return "turf"
    if path == "/obj" or path.startswith("/obj/"):
        return "object"
    if path == "/mob" or path.startswith("/mob/"):
        return "mob"
    return "other"


def _cells(
    parsed: ParsedMap,
) -> tuple[dict[tuple[int, int, int], str], int]:
    cells: dict[tuple[int, int, int], str] = {}
    overlap_count = 0
    for block in parsed.blocks:
        origin_x, origin_y, z = block.origin
        height = len(block.rows)
        for row_offset, row in enumerate(block.rows):
            for column_offset, key in enumerate(row):
                coordinate = (
                    origin_x + column_offset,
                    origin_y + (height - 1 - row_offset),
                    z,
                )
                if coordinate in cells:
                    overlap_count += 1
                cells[coordinate] = key
    return cells, overlap_count


def _entry_facts(
    parsed: ParsedMap,
) -> dict[str, tuple[tuple[str, ...], tuple[str, ...], tuple[str, ...]]]:
    facts = {}
    for key, entry in parsed.entries.items():
        areas = tuple(
            atom.path for atom in entry.atoms if _atom_kind(atom.path) == "area"
        )
        turfs = tuple(
            atom.path for atom in entry.atoms if _atom_kind(atom.path) == "turf"
        )
        objects = tuple(
            atom.path for atom in entry.atoms if _atom_kind(atom.path) == "object"
        )
        facts[key] = (areas, turfs, objects)
    return facts


def _bounds(
    cells: Iterable[tuple[int, int, int]],
) -> list[dict[str, int]]:
    levels: dict[int, list[int]] = {}
    counts: Counter[int] = Counter()
    for x, y, z in cells:
        if z not in levels:
            levels[z] = [x, y, x, y]
        else:
            bounds = levels[z]
            bounds[0] = min(bounds[0], x)
            bounds[1] = min(bounds[1], y)
            bounds[2] = max(bounds[2], x)
            bounds[3] = max(bounds[3], y)
        counts[z] += 1
    result = []
    for z in sorted(levels):
        min_x, min_y, max_x, max_y = levels[z]
        result.append(
            {
                "z": z,
                "min_x": min_x,
                "min_y": min_y,
                "max_x": max_x,
                "max_y": max_y,
                "width": max_x - min_x + 1,
                "height": max_y - min_y + 1,
                "mapped_cells": counts[z],
            }
        )
    return result


def _ordered_counts(counter: Counter[str], top: int) -> dict[str, object]:
    records = [
        {"path": path, "instances": instances}
        for path, instances in sorted(
            counter.items(), key=lambda item: (-item[1], item[0])
        )[:top]
    ]
    return {
        "unique": len(counter),
        "shown": len(records),
        "top": records,
    }


def summarize_map(parsed: ParsedMap) -> dict[str, object]:
    """Return stable selection signals and structural validation."""

    cells, overlaps = _cells(parsed)
    key_counts = Counter(cells.values())
    facts = _entry_facts(parsed)
    unknown_keys = sorted(set(key_counts) - set(parsed.entries))
    unused_keys = sorted(set(parsed.entries) - set(key_counts))

    path_counts: dict[str, Counter[str]] = {
        kind: Counter() for kind in ("area", "turf", "object", "mob", "other")
    }
    definition_paths: dict[str, set[str]] = {kind: set() for kind in path_counts}
    override_counts: Counter[str] = Counter()
    for entry in parsed.entries.values():
        for atom in entry.atoms:
            kind = _atom_kind(atom.path)
            definition_paths[kind].add(atom.path)
            override_counts.update(atom.variables)
    missing_area = 0
    multiple_area = 0
    missing_turf = 0
    multiple_turf = 0
    station_area_cells = 0
    station_departments: set[str] = set()
    non_space_turf_cells = 0
    machinery_instances = 0
    for key, placements in key_counts.items():
        entry = parsed.entries.get(key)
        if entry is None:
            continue
        areas, turfs, _ = facts[key]
        if not areas:
            missing_area += placements
        elif len(areas) > 1:
            multiple_area += placements
        if not turfs:
            missing_turf += placements
        elif len(turfs) > 1:
            multiple_turf += placements
        for atom in entry.atoms:
            kind = _atom_kind(atom.path)
            path_counts[kind][atom.path] += placements
            if atom.path.startswith("/area/station"):
                station_area_cells += placements
                suffix = atom.path.removeprefix("/area/station").strip("/")
                if suffix:
                    station_departments.add(suffix.split("/", 1)[0])
            if kind == "turf" and not atom.path.startswith("/turf/space"):
                non_space_turf_cells += placements
            if atom.path.startswith("/obj/machinery"):
                machinery_instances += placements

    mapped_cells = len(cells)
    object_instances = sum(path_counts["object"].values())
    bounds = _bounds(cells)
    bounding_cells = sum(level["width"] * level["height"] for level in bounds)
    issues = {
        "overlapping_cell_writes": overlaps,
        "unknown_grid_keys": unknown_keys,
        "unused_dictionary_keys": unused_keys,
        "cells_without_area": missing_area,
        "cells_with_multiple_areas": multiple_area,
        "cells_without_turf": missing_turf,
        "cells_with_multiple_turfs": multiple_turf,
    }
    issue_count = (
        overlaps
        + len(unknown_keys)
        + missing_area
        + multiple_area
        + missing_turf
        + multiple_turf
    )
    return {
        "format": parsed.format,
        "key_width": parsed.key_width,
        "dictionary_entries": len(parsed.entries),
        "coordinate_blocks": len(parsed.blocks),
        "z_levels": [level["z"] for level in bounds],
        "bounds": bounds,
        "mapped_cells": mapped_cells,
        "atom_kinds": {
            kind: {
                "unique_paths": len(definition_paths[kind]),
                "instances": sum(path_counts[kind].values()),
            }
            for kind in ("area", "turf", "object", "mob", "other")
        },
        "selection_signals": {
            "station_area_cells": station_area_cells,
            "station_department_families": len(station_departments),
            "non_space_turf_cells": non_space_turf_cells,
            "machinery_instances": machinery_instances,
            "object_instances": object_instances,
            "objects_per_1000_cells": (
                (object_instances * 1000 + mapped_cells // 2) // mapped_cells
                if mapped_cells
                else 0
            ),
            "map_fill_per_1000": (
                (mapped_cells * 1000 + bounding_cells // 2) // bounding_cells
                if bounding_cells
                else 0
            ),
        },
        "validation": {
            "ok": issue_count == 0,
            "issues": issues,
        },
    }


def _coordinate_bounds(
    coordinates: Iterable[tuple[int, int, int]],
) -> dict[str, int] | None:
    coordinates = list(coordinates)
    if not coordinates:
        return None
    return {
        "min_x": min(point[0] for point in coordinates),
        "min_y": min(point[1] for point in coordinates),
        "min_z": min(point[2] for point in coordinates),
        "max_x": max(point[0] for point in coordinates),
        "max_y": max(point[1] for point in coordinates),
        "max_z": max(point[2] for point in coordinates),
    }


def analyze_map(parsed: ParsedMap, top: int = 25) -> dict[str, object]:
    """Return compact path, area-placement, and adjacency analysis."""

    summary = summarize_map(parsed)
    cells, _ = _cells(parsed)
    facts = _entry_facts(parsed)
    path_counts: dict[str, Counter[str]] = {
        kind: Counter() for kind in ("area", "turf", "object", "mob", "other")
    }
    definition_counts: Counter[str] = Counter()
    variable_counts: Counter[str] = Counter()
    for entry in parsed.entries.values():
        for atom in entry.atoms:
            definition_counts[atom.path] += 1
            variable_counts.update(atom.variables)

    area_cells: Counter[str] = Counter()
    area_coordinates: dict[str, list[tuple[int, int, int]]] = defaultdict(list)
    area_objects: dict[str, Counter[str]] = defaultdict(Counter)
    area_machinery: Counter[str] = Counter()
    selected_area: dict[tuple[int, int, int], str] = {}
    for coordinate in sorted(cells, key=lambda point: (point[2], point[1], point[0])):
        key = cells[coordinate]
        entry = parsed.entries.get(key)
        if entry is None:
            continue
        areas, _, objects = facts[key]
        area = areas[0] if areas else "<missing-area>"
        selected_area[coordinate] = area
        area_cells[area] += 1
        area_coordinates[area].append(coordinate)
        for object_path in objects:
            area_objects[area][object_path] += 1
            if object_path.startswith("/obj/machinery"):
                area_machinery[area] += 1
        placements = 1
        for atom in entry.atoms:
            path_counts[_atom_kind(atom.path)][atom.path] += placements

    adjacency: Counter[tuple[str, str]] = Counter()
    for coordinate, area in selected_area.items():
        x, y, z = coordinate
        for neighbor in ((x + 1, y, z), (x, y + 1, z)):
            other = selected_area.get(neighbor)
            if other is not None and other != area:
                pair = tuple(sorted((area, other)))
                adjacency[pair] += 1

    area_profiles = []
    for area, count in sorted(area_cells.items(), key=lambda item: (-item[1], item[0]))[
        :top
    ]:
        object_counter = area_objects[area]
        top_objects = [
            {"path": path, "instances": instances}
            for path, instances in sorted(
                object_counter.items(), key=lambda item: (-item[1], item[0])
            )[: min(10, top)]
        ]
        area_profiles.append(
            {
                "path": area,
                "cells": count,
                "bounds": _coordinate_bounds(area_coordinates[area]),
                "object_instances": sum(object_counter.values()),
                "machinery_instances": area_machinery[area],
                "top_objects": top_objects,
            }
        )

    adjacency_records = [
        {"areas": list(pair), "shared_edges": edges}
        for pair, edges in sorted(
            adjacency.items(), key=lambda item: (-item[1], item[0])
        )[:top]
    ]
    departments: Counter[str] = Counter()
    for path, count in area_cells.items():
        if path.startswith("/area/station/"):
            remainder = path.removeprefix("/area/station/")
            departments[remainder.split("/", 1)[0]] += count

    path_report = {}
    for kind in ("area", "turf", "object", "mob", "other"):
        report = _ordered_counts(path_counts[kind], top)
        for record in report["top"]:
            record["dictionary_entries"] = definition_counts[record["path"]]
        path_report[kind] = report

    return {
        "summary": summary,
        "paths": path_report,
        "station_departments": [
            {"name": name, "cells": count}
            for name, count in sorted(
                departments.items(), key=lambda item: (-item[1], item[0])
            )
        ],
        "area_profiles": {
            "total": len(area_cells),
            "shown": len(area_profiles),
            "areas": area_profiles,
        },
        "area_adjacencies": {
            "total": len(adjacency),
            "shown": len(adjacency_records),
            "pairs": adjacency_records,
        },
        "override_variables": [
            {"name": name, "dictionary_atoms": count}
            for name, count in sorted(
                variable_counts.items(), key=lambda item: (-item[1], item[0])
            )[:top]
        ],
    }


def _station_department(area_path: str) -> str:
    """Adapt a Goon area path to Sim Station's small department vocabulary."""

    value = area_path.lower()
    if any(token in value for token in ("/engine", "/engineering", "/electrical")):
        return "engineering"
    if any(
        token in value for token in ("/quartermaster", "/cargo", "/mining", "/hangar")
    ):
        return "cargo"
    if any(token in value for token in ("/medical", "/medbay", "/robotics")):
        return "medical"
    if any(token in value for token in ("/science", "/research", "/tox")):
        return "science"
    if any(token in value for token in ("/security", "/brig", "/armory")):
        return "security"
    if any(
        token in value
        for token in (
            "/bridge",
            "/command",
            "/captain",
            "/hop",
            "/ai",
        )
    ):
        return "command"
    if any(
        token in value
        for token in (
            "/crew",
            "/chapel",
            "/hydro",
            "/kitchen",
            "/bar",
            "/cafeteria",
            "/janitor",
        )
    ):
        return "service"
    return "general"


def _station_access(area_path: str) -> str:
    value = area_path.lower()
    if "/maintenance" in value:
        return "maintenance"
    department = _station_department(area_path)
    if department in {
        "cargo",
        "command",
        "engineering",
        "medical",
        "science",
        "security",
    }:
        return department
    if department == "service":
        return "service"
    return "public"


def _area_name(path: str) -> str:
    suffix = path.removeprefix("/area/station/").strip("/")
    if not suffix:
        return "Station"
    words = suffix.replace("_", " ").replace("/", " · ")
    return " ".join(
        word.capitalize() if word != "·" else word for word in words.split()
    )


def _door_access(objects: tuple[str, ...], area_path: str) -> str:
    joined = "\n".join(objects).lower()
    explicit = (
        ("maintenance", ("access/maint", "/maintenance")),
        ("engineering", ("access/engineering", "/engineering")),
        ("medical", ("access/medical", "/medical", "/med")),
        ("science", ("access/research", "/science", "/sci")),
        ("security", ("access/security", "/security", "/weapons")),
        ("cargo", ("access/cargo", "/cargo", "/qm")),
        ("command", ("access/command", "/command")),
    )
    for access, tokens in explicit:
        if any(token in joined for token in tokens):
            return access
    return _station_access(area_path)


def _is_type_path(path: str, root: str) -> bool:
    """Return whether a DM type path is exactly root or one of its children."""

    return path == root or path.startswith(root + "/")


def _has_path_segment(path: str, segment: str) -> bool:
    return segment in path.strip("/").split("/")


def _is_wall_turf(path: str) -> bool:
    return _is_type_path(path, "/turf") and _has_path_segment(path, "wall")


def _is_airless_turf(path: str) -> bool:
    return any(token in path for token in ("/airless", "/vacuum"))


def _is_door_object(path: str) -> bool:
    return _is_type_path(path, "/obj/machinery/door")


def _is_window_object(path: str) -> bool:
    return _is_type_path(path, "/obj/window") or _is_type_path(
        path, "/obj/mapping_helper/wingrille_spawn"
    )


def _is_grille_object(path: str) -> bool:
    return (
        _is_type_path(path, "/obj/mesh/grille")
        or _is_type_path(path, "/obj/grille")
        or _is_type_path(path, "/obj/mapping_helper/wingrille_spawn")
    )


def _is_disposal_object(path: str) -> bool:
    return any(
        _is_type_path(path, root)
        for root in (
            "/obj/disposaloutlet",
            "/obj/disposalpipe",
            "/obj/machinery/disposal",
            "/obj/machinery/disposal_pipedispenser",
        )
    )


def _object_features(path: str) -> tuple[str, ...]:
    features = set()
    if _is_window_object(path):
        features.add("window")
    if _is_grille_object(path):
        features.add("grille")
    if _is_type_path(path, "/obj/table"):
        features.add("table")
    if _is_type_path(path, "/obj/stool/chair") or _is_type_path(
        path, "/obj/item/chair"
    ):
        features.add("chair")
    if _is_type_path(path, "/obj/machinery/light"):
        features.add("light")
    if _is_type_path(path, "/obj/storage"):
        features.add("storage")
        if _has_path_segment(path, "crate"):
            features.add("crate")
    if _is_type_path(path, "/obj/lattice"):
        features.add("lattice")
    if _is_type_path(path, "/obj/mesh/catwalk"):
        features.add("catwalk")
    if _is_type_path(path, "/obj/machinery/atmospherics/pipe"):
        features.add("pipe")
    if _is_disposal_object(path):
        features.add("disposal")
    if _is_type_path(path, "/obj/decal"):
        features.add("decal")
        if _has_path_segment(path, "wallsign"):
            features.add("sign")
    if _is_type_path(path, "/obj/wallsign") or _is_type_path(path, "/obj/sign"):
        features.add("sign")
    return tuple(sorted(features))


def _turf_kind(turfs: tuple[str, ...]) -> str | None:
    if not turfs:
        return "space"
    if any(_is_wall_turf(path) for path in turfs):
        return None
    if not any(not _is_type_path(path, "/turf/space") for path in turfs):
        return "space"
    if any(_is_type_path(path, "/turf/simulated/floor/engine") for path in turfs):
        return "reinforced_floor"
    if any(_has_path_segment(path, "plating") for path in turfs):
        return "plating"
    return "floor"


def _preserve_source_object(path: str) -> bool:
    """Keep reviewed tile/object provenance without exploding map palettes."""

    return bool(
        _object_features(path)
        or _is_door_object(path)
        or _is_type_path(path, "/obj/cable")
    )


def _fixture_kind(path: str) -> str | None:
    if path.startswith("/obj/machinery/power/apc"):
        return "apc"
    if path.startswith("/obj/machinery/power/smes"):
        return "battery"
    if path.startswith("/obj/submachine/cargopad"):
        return "cargo_pad"
    if path.startswith("/obj/machinery/computer/supplycomp"):
        return "supply_console"
    if path.startswith("/obj/machinery/computer/barcode/qm"):
        return "barcode_computer"
    if path.startswith("/obj/machinery/manufacturer"):
        return "fabricator"
    if path.startswith("/obj/machinery/nanofab"):
        return "nanofab"
    if path.startswith("/obj/machinery/portable_reclaimer"):
        return "reclaimer"
    if path.startswith("/obj/machinery/portable_atmospherics/scrubber"):
        return "portable_scrubber"
    if path.startswith("/obj/machinery/atmospherics/unary/vent_pump"):
        return "vent_pump"
    if path.startswith("/obj/machinery/atmospherics/unary/vent"):
        return "vent"
    if path.startswith("/obj/machinery/atmospherics/binary/circulatorTemp"):
        return "circulator"
    if path.startswith("/obj/machinery/power/generator"):
        return "generator"
    return None


def _fixture_definition_id(kind: str) -> str:
    names = {
        "apc": "goon-apc",
        "barcode_computer": "goon-qm-barcode-computer",
        "battery": "goon-smes",
        "cargo_pad": "goon-cargo-pad",
        "circulator": "goon-teg-circulator",
        "fabricator": "goon-manufacturer",
        "generator": "goon-teg-generator",
        "nanofab": "goon-nanofab",
        "portable_scrubber": "goon-portable-scrubber",
        "reclaimer": "goon-portable-reclaimer",
        "supply_console": "goon-supply-console",
        "vent": "goon-passive-vent",
        "vent_pump": "goon-vent-pump",
    }
    return "org.simstation.core:machine/" + names[kind]


def _fixture_name(kind: str, path: str) -> str:
    subtype = path.rsplit("/", 1)[-1].replace("_", " ")
    if subtype.lower() in {
        "apc",
        "manufacturer",
        "portable reclaimer",
        "scrubber",
        "vent",
        "vent pump",
    }:
        subtype = kind.replace("_", " ")
    return " ".join(word.capitalize() for word in subtype.split())


def _content_slug(value: str) -> str:
    value = value.lower().replace("_", "-")
    value = re.sub(r"[^a-z0-9/-]+", "-", value)
    value = re.sub(r"-+", "-", value)
    value = re.sub(r"/+", "/", value)
    return value.strip("-/")


def _job_content_id(job: str) -> str:
    return "org.simstation.core:job/" + _content_slug(job)


def _scenario_namespace(scenario_id: str, nested_kind: str) -> str:
    match = re.fullmatch(
        r"([a-z0-9][a-z0-9.-]*):scenario/([a-z0-9][a-z0-9_/%-]*)",
        scenario_id,
    )
    if not match or "." not in match.group(1) or "//" in scenario_id:
        raise MapError("scenario ID must be <reverse-dns-pack>:scenario/<name>")
    return f"{match.group(1)}:{nested_kind}/{match.group(2)}"


def _adapted_object(path: str) -> bool:
    return bool(
        _fixture_kind(path)
        or _preserve_source_object(path)
        or _is_type_path(path, "/obj/landmark/start/job")
        or _is_type_path(path, "/obj/mapping_helper/access")
    )


def _native_coordinate(
    coordinate: tuple[int, int, int],
    crop: tuple[int, int, int, int],
) -> tuple[int, int]:
    source_x, source_y, _ = coordinate
    min_x, _, _, max_y = crop
    return source_x - min_x + 1, max_y - source_y + 1


def _station_area_path(entry: DictionaryEntry) -> str:
    for atom in entry.atoms:
        if (
            atom.path.startswith("/area/")
            and atom.path != "/area/space"
            and not atom.path.startswith("/area/space/")
        ):
            return atom.path
    return ""


def _cell_contract(
    entry: DictionaryEntry | None,
    area_ids: dict[str, int],
) -> tuple[object, ...]:
    if entry is None:
        return (
            "space",
            "empty",
            False,
            False,
            0,
            False,
            "space",
            None,
            (),
            (),
            (),
        )
    turfs = tuple(
        sorted(
            {
                atom.path
                for atom in entry.atoms
                if _atom_kind(atom.path) == "turf"
            }
        )
    )
    objects = tuple(
        atom.path for atom in entry.atoms if _atom_kind(atom.path) == "object"
    )
    area_path = _station_area_path(entry)
    non_space = any(not _is_type_path(path, "/turf/space") for path in turfs)
    tile = "floor" if non_space else "space"
    structure = "wall" if any(_is_wall_turf(path) for path in turfs) else "empty"
    if any(_is_window_object(path) for path in objects):
        structure = "wall"
    if any(_is_door_object(path) for path in objects):
        structure = "door_closed"
    cable = any(_is_type_path(path, "/obj/cable") for path in objects)
    pressurized = bool(
        area_path
        and non_space
        and structure != "wall"
        and not any(_is_airless_turf(path) for path in turfs)
    )
    area_id = area_ids.get(area_path, 0)
    access: str | bool = False
    if structure == "door_closed":
        access = _door_access(objects, area_path)
    turf_kind = _turf_kind(turfs)
    wall_kind = None
    if structure == "wall":
        wall_kind = (
            "reinforced"
            if any(
                _is_wall_turf(path) and _has_path_segment(path, "reinforced")
                for path in turfs
            )
            else "standard"
        )
    features = tuple(
        sorted(
            {
                feature
                for path in objects
                for feature in _object_features(path)
            }
            | (
                {"catwalk"}
                if any(_has_path_segment(path, "catwalk") for path in turfs)
                else set()
            )
        )
    )
    source_objects = tuple(
        sorted({path for path in objects if _preserve_source_object(path)})
    )
    return (
        tile,
        structure,
        cable,
        pressurized,
        area_id,
        access,
        turf_kind,
        wall_kind,
        features,
        turfs,
        source_objects,
    )


def _palette_record(key: str, contract: tuple[object, ...]) -> dict[str, object]:
    (
        tile,
        structure,
        cable,
        pressurized,
        area_id,
        access,
        turf_kind,
        wall_kind,
        features,
        source_turfs,
        source_objects,
    ) = contract
    record: dict[str, object] = {
        "key": key,
        "tile": tile,
        "structure": structure,
        "area": area_id,
    }
    if cable:
        record["cable"] = True
    if pressurized:
        record["pressurized"] = True
    if access:
        record["access"] = access
    if turf_kind is not None:
        record["turf_kind"] = turf_kind
    if wall_kind is not None:
        record["wall_kind"] = wall_kind
    if features:
        record["features"] = list(features)
    if source_turfs:
        record["source_turfs"] = list(source_turfs)
    if source_objects:
        record["source_objects"] = list(source_objects)
    return record


def _sample_hull_targets(
    contracts: list[tuple[object, ...]],
    width: int,
    height: int,
    maximum: int = 64,
) -> list[dict[str, int]]:
    candidates = []
    for y in range(1, height + 1):
        for x in range(1, width + 1):
            index = (y - 1) * width + x
            tile, structure, _, _, area_id, *_ = contracts[index - 1]
            if tile != "floor" or structure != "wall" or area_id == 0:
                continue
            neighbors = (
                (x - 1, y),
                (x + 1, y),
                (x, y - 1),
                (x, y + 1),
            )
            exposed = False
            for neighbor_x, neighbor_y in neighbors:
                if (
                    neighbor_x < 1
                    or neighbor_y < 1
                    or neighbor_x > width
                    or neighbor_y > height
                ):
                    exposed = True
                    break
                neighbor = contracts[(neighbor_y - 1) * width + neighbor_x - 1]
                if neighbor[0] == "space":
                    exposed = True
                    break
            if exposed:
                candidates.append({"x": x, "y": y})
    if len(candidates) <= maximum:
        return candidates
    return [
        candidates[(index * len(candidates)) // maximum] for index in range(maximum)
    ]


def compile_scenario(
    parsed: ParsedMap,
    source: dict[str, object],
    *,
    scenario_id: str,
    name: str,
    crop: tuple[int, int, int, int],
    z_level: int = 1,
    power_supply_w: int = 750_000,
) -> dict[str, object]:
    """Compile a bounded Goon map view into deterministic native scenario data.

    DM values and behavior are deliberately not executed. The compiler adapts
    only observable type-path placement into Sim Station's explicit contracts.
    """

    min_x, min_y, max_x, max_y = crop
    if min_x > max_x or min_y > max_y:
        raise MapError("crop minimums must not exceed maximums")
    width = max_x - min_x + 1
    height = max_y - min_y + 1
    if not 16 <= width <= 256 or not 16 <= height <= 256:
        raise MapError("compiled dimensions must be from 16 through 256")
    area_namespace = _scenario_namespace(scenario_id, "scenario-area")
    fixture_namespace = _scenario_namespace(scenario_id, "scenario-fixture")
    spawn_namespace = _scenario_namespace(scenario_id, "scenario-spawn")

    cells, overlaps = _cells(parsed)
    if overlaps:
        raise MapError("cannot compile a map with overlapping cell writes")
    selected = {
        coordinate: key
        for coordinate, key in cells.items()
        if coordinate[2] == z_level
        and min_x <= coordinate[0] <= max_x
        and min_y <= coordinate[1] <= max_y
    }
    if not selected:
        raise MapError("crop contains no mapped cells on the requested z level")

    area_paths = sorted(
        {
            path
            for key in selected.values()
            for path in (_station_area_path(parsed.entries[key]),)
            if path
        }
    )
    area_ids = {path: index for index, path in enumerate(area_paths, 1)}
    areas = [
        {
            "id": area_ids[path],
            "key": (area_namespace + "/" + _content_slug(path.removeprefix("/area/"))),
            "name": _area_name(path),
            "department": _station_department(path),
            "access": _station_access(path),
            "source_path": path,
        }
        for path in area_paths
    ]

    native_entries: dict[tuple[int, int], DictionaryEntry] = {}
    for coordinate, key in selected.items():
        native_entries[_native_coordinate(coordinate, crop)] = parsed.entries[key]
    contracts = []
    for native_y in range(1, height + 1):
        for native_x in range(1, width + 1):
            contracts.append(
                _cell_contract(native_entries.get((native_x, native_y)), area_ids)
            )

    default_contract: tuple[object, ...] = (
        "space",
        "empty",
        False,
        False,
        0,
        False,
        "space",
        None,
        (),
        (),
        (),
    )
    unique_contracts = sorted(
        set(contracts) - {default_contract},
        key=lambda value: json.dumps(value, separators=(",", ":")),
    )
    ordered_contracts = [default_contract, *unique_contracts]
    if len(ordered_contracts) > 2048:
        raise MapError(
            "compiled map requires "
            f"{len(ordered_contracts)} palette records; maximum is 2048"
        )
    palette_index = {
        contract: index for index, contract in enumerate(ordered_contracts, 1)
    }
    palette = [
        _palette_record(f"p{index:04d}", contract)
        for index, contract in enumerate(ordered_contracts, 1)
    ]
    runs: list[list[int]] = []
    for y in range(1, height + 1):
        row_start = (y - 1) * width
        x = 1
        while x <= width:
            contract = contracts[row_start + x - 1]
            if contract == default_contract:
                x += 1
                continue
            end_x = x
            while end_x < width and contracts[row_start + end_x] == contract:
                end_x += 1
            runs.append(
                [
                    row_start + x,
                    end_x - x + 1,
                    palette_index[contract],
                ]
            )
            x = end_x + 1

    fixture_candidates = []
    spawns = []
    placement_omissions = []
    object_counts: Counter[str] = Counter()
    for coordinate, key in selected.items():
        entry = parsed.entries[key]
        native_x, native_y = _native_coordinate(coordinate, crop)
        area_path = _station_area_path(entry)
        department = _station_department(area_path)
        for atom in entry.atoms:
            if _atom_kind(atom.path) == "object":
                object_counts[atom.path] += 1
            if atom.path.startswith("/obj/landmark/start/job/"):
                upstream_job = atom.path.rsplit("/", 1)[-1]
                job = JOB_ADAPTATIONS.get(upstream_job, "assistant")
                spawns.append(
                    {
                        "x": native_x,
                        "y": native_y,
                        "job_id": _job_content_id(job),
                        "department": _station_department(area_path),
                        "source_path": atom.path,
                    }
                )
            kind = _fixture_kind(atom.path)
            if kind:
                if kind == "apc" and not area_path:
                    placement_omissions.append(
                        {
                            "x": native_x,
                            "y": native_y,
                            "kind": kind,
                            "source_path": atom.path,
                            "reason": "APC source cell has no station area",
                        }
                    )
                else:
                    fixture_candidates.append(
                        (
                            native_y,
                            native_x,
                            kind,
                            atom.path,
                            department,
                            dict(atom.literal_overrides),
                        )
                    )
    fixtures = []
    fixture_occurrences: Counter[tuple[int, int, str]] = Counter()
    collision_omissions: list[dict[str, object]] = []
    for native_y, native_x, kind, path, department, overrides in sorted(
        fixture_candidates,
        key=lambda record: (
            record[0],
            record[1],
            record[2],
            record[3],
            json.dumps(record[5], sort_keys=True),
        ),
    ):
        identity = (native_x, native_y, kind)
        fixture_occurrences[identity] += 1
        occurrence = fixture_occurrences[identity]
        suffix = f"-{occurrence:02d}" if occurrence > 1 else ""
        fixtures.append(
            {
                "id": (
                    fixture_namespace + "/"
                    f"{kind.replace('_', '-')}-x{native_x:03d}-y{native_y:03d}"
                    f"{suffix}"
                ),
                "kind": kind,
                "definition_id": _fixture_definition_id(kind),
                "name": _fixture_name(kind, path),
                "x": native_x,
                "y": native_y,
                "department": department,
                "source_path": path,
                **({"source_overrides": overrides} if overrides else {}),
            }
        )
    fixtures.sort(key=lambda record: record["id"])
    spawns.sort(
        key=lambda record: (
            record["job_id"],
            record["y"],
            record["x"],
            record["source_path"],
        )
    )
    spawn_duplicate_omissions = []
    unique_spawns = []
    spawn_positions: set[tuple[int, int]] = set()
    for spawn in spawns:
        position = (spawn["x"], spawn["y"])
        if position in spawn_positions:
            spawn_duplicate_omissions.append(
                {
                    "x": spawn["x"],
                    "y": spawn["y"],
                    "job": spawn["job_id"],
                    "source_path": spawn["source_path"],
                }
            )
        else:
            spawn_positions.add(position)
            unique_spawns.append(spawn)
    spawns = unique_spawns
    spawn_occurrences: Counter[tuple[int, int, str]] = Counter()
    for spawn in spawns:
        identity = (spawn["x"], spawn["y"], spawn["job_id"])
        spawn_occurrences[identity] += 1
        occurrence = spawn_occurrences[identity]
        job_slug = spawn["job_id"].rsplit("/", 1)[-1]
        spawn["id"] = (
            spawn_namespace + "/"
            f"{job_slug}-x{spawn['x']:03d}-y{spawn['y']:03d}-{occurrence:02d}"
        )
        spawn["job"] = spawn.pop("job_id")
    spawns.sort(key=lambda record: record["id"])

    omitted_counts = Counter(
        {
            path: count
            for path, count in object_counts.items()
            if not _adapted_object(path)
        }
    )
    for omission in collision_omissions:
        omitted_counts[omission["omitted_source_path"]] += 1
    for omission in spawn_duplicate_omissions:
        omitted_counts[omission["source_path"]] += 1
    for omission in placement_omissions:
        omitted_counts[omission["source_path"]] += 1

    provenance = {
        "schema": 1,
        "method": "reviewed-path-conversion",
        "license": "CC-BY-NC-SA-3.0-US",
        "sources": [
            {
                "repository": "goonstation/goonstation",
                "commit": source["commit"],
                "path": source["path"],
                "git_blob": source["git_blob"],
                "sha256": source["sha256"],
                "role": "geometry-and-placement-source",
            }
        ],
        "tool": {
            "path": "tools/map_import.py",
            "format_version": FORMAT_VERSION,
            "profile": "goon-type-path-adapter-v1",
        },
        "crop": {
            "z": z_level,
            "min_x": min_x,
            "min_y": min_y,
            "max_x": max_x,
            "max_y": max_y,
            "native_y_axis": "down; source Y flipped",
        },
        "omissions": {
            "included_object_instances": sum(object_counts.values())
            - sum(omitted_counts.values()),
            "omitted_object_instances": sum(omitted_counts.values()),
            "omitted_unique_object_paths": len(omitted_counts),
            "fixture_collision_omissions": collision_omissions,
            "spawn_duplicate_omissions": spawn_duplicate_omissions,
            "placement_omissions": placement_omissions,
            "top_omitted_object_paths": [
                {"source_path": path, "instances": instances}
                for path, instances in sorted(
                    omitted_counts.items(),
                    key=lambda item: (-item[1], item[0]),
                )[:25]
            ],
        },
        "notes": (
            "DM code and override expressions are not executed. Unsupported "
            "objects and placement limitations are counted explicitly; "
            "compatible source-layered fixtures are retained."
        ),
    }
    scenario = {
        "id": scenario_id,
        "kind": "scenario",
        "schema": SIMSTATION_SCENARIO_SCHEMA,
        "name": name,
        "description": (
            "A native, deterministic Sim Station scenario compiled from the "
            "pinned Goonstation map geometry and adapted system landmarks."
        ),
        "provenance": provenance,
        "areas": areas,
        "map": {
            "format": SIMSTATION_MAP_FORMAT,
            "width": width,
            "height": height,
            "default_palette": 1,
            "palette": palette,
            "runs": runs,
        },
        "fixtures": fixtures,
        "spawns": spawns,
        "meteor_targets": _sample_hull_targets(contracts, width, height),
        "power_supply_w": power_supply_w,
        "starting_inventory": dict(sorted(DEFAULT_STARTING_INVENTORY.items())),
    }
    return {"schema": 1, "definitions": [scenario]}


class GitRepository:
    """Read immutable blobs efficiently from one Git commit."""

    def __init__(self, path: Path, revision: str, allow_unpinned: bool):
        self.path = path.resolve()
        if not (self.path / ".git").exists():
            raise MapError(f"not a Git checkout: {path}")
        self.commit = self._git_text(
            ["rev-parse", "--verify", f"{revision}^{{commit}}"]
        ).strip()
        pinned = pinned_goon_commit()
        if not allow_unpinned and self.commit != pinned:
            raise MapError(
                f"refusing unpinned Goon commit {self.commit}; expected "
                f"{pinned} (pass --allow-unpinned to inspect deliberately)"
            )
        self._batch: subprocess.Popen[bytes] | None = None

    def _git_bytes(self, arguments: Sequence[str]) -> bytes:
        result = subprocess.run(
            ["git", "-C", str(self.path), *arguments],
            check=False,
            capture_output=True,
        )
        if result.returncode:
            message = result.stderr.decode("utf-8", "replace").strip()
            raise MapError(message or f"git {' '.join(arguments)} failed")
        return result.stdout

    def _git_text(self, arguments: Sequence[str]) -> str:
        return self._git_bytes(arguments).decode("utf-8")

    def map_blobs(self) -> list[GitBlob]:
        records = self._git_bytes(["ls-tree", "-rlz", self.commit]).split(b"\0")
        blobs = []
        for raw in records:
            if not raw:
                continue
            metadata, raw_path = raw.split(b"\t", 1)
            mode, kind, oid, size = metadata.decode("ascii").split()
            del mode
            path = raw_path.decode("utf-8")
            if kind == "blob" and path.lower().endswith((".dmm", ".tgm")):
                blobs.append(GitBlob(oid=oid, size=int(size), path=path))
        return sorted(blobs, key=lambda blob: blob.path)

    def read_blob(self, blob: GitBlob) -> bytes:
        if self._batch is None:
            self._batch = subprocess.Popen(
                ["git", "-C", str(self.path), "cat-file", "--batch"],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        assert self._batch.stdin is not None
        assert self._batch.stdout is not None
        self._batch.stdin.write((blob.oid + "\n").encode("ascii"))
        self._batch.stdin.flush()
        header = self._batch.stdout.readline().decode("ascii").strip().split()
        if len(header) != 3 or header[1] != "blob":
            raise MapError(f"cannot read Git blob {blob.oid}: {' '.join(header)}")
        size = int(header[2])
        data = self._batch.stdout.read(size)
        separator = self._batch.stdout.read(1)
        if len(data) != size or separator != b"\n":
            raise MapError(f"truncated Git blob {blob.oid}")
        return data

    def close(self) -> None:
        if self._batch is not None:
            if self._batch.stdin is not None:
                self._batch.stdin.close()
            self._batch.wait(timeout=5)
            self._batch = None

    def __enter__(self) -> "GitRepository":
        return self

    def __exit__(self, *_: object) -> None:
        self.close()


def pinned_goon_commit() -> str:
    with GOON_LOCK.open("rb") as handle:
        manifest = tomllib.load(handle)
    commit = manifest.get("commit")
    if not isinstance(commit, str) or not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise MapError(f"invalid commit in {GOON_LOCK.relative_to(ROOT)}")
    return commit


def _select_blobs(
    blobs: Iterable[GitBlob],
    prefix: str,
    max_depth: int | None,
) -> list[GitBlob]:
    normalized = prefix.replace("\\", "/").lstrip("/")
    if normalized and not normalized.endswith("/"):
        normalized += "/"
    selected = []
    for blob in blobs:
        if normalized and not blob.path.startswith(normalized):
            continue
        relative = blob.path[len(normalized) :] if normalized else blob.path
        depth = len(PurePosixPath(relative).parts) - 1
        if max_depth is not None and depth > max_depth:
            continue
        selected.append(blob)
    return selected


def _source_record(
    repository: GitRepository,
    blob: GitBlob,
    data: bytes,
) -> dict[str, object]:
    return {
        "commit": repository.commit,
        "path": blob.path,
        "git_blob": blob.oid,
        "bytes": blob.size,
        "sha256": hashlib.sha256(data).hexdigest(),
    }


def command_inventory(arguments: argparse.Namespace) -> int:
    errors = []
    maps = []
    with GitRepository(
        arguments.repo, arguments.revision, arguments.allow_unpinned
    ) as repository:
        all_blobs = repository.map_blobs()
        blobs = _select_blobs(all_blobs, arguments.prefix, arguments.max_depth)
        for blob in blobs:
            data = repository.read_blob(blob)
            try:
                parsed = parse_map(data, blob.path)
                record = {
                    "source": _source_record(repository, blob, data),
                    **summarize_map(parsed),
                }
                maps.append(record)
            except MapError as error:
                errors.append({"path": blob.path, "error": str(error)})
        report = {
            "format_version": FORMAT_VERSION,
            "source": {
                "commit": repository.commit,
                "repository": "goonstation",
            },
            "filter": {
                "prefix": arguments.prefix,
                "max_depth": arguments.max_depth,
            },
            "corpus_map_count": len(all_blobs),
            "selected_map_count": len(blobs),
            "parsed_map_count": len(maps),
            "error_count": len(errors),
            "maps": maps,
            "errors": errors,
        }
    _emit_json(report, arguments.pretty)
    return 1 if errors else 0


def command_analyze(arguments: argparse.Namespace) -> int:
    requested = arguments.path.replace("\\", "/").lstrip("/")
    with GitRepository(
        arguments.repo, arguments.revision, arguments.allow_unpinned
    ) as repository:
        matches = {blob.path: blob for blob in repository.map_blobs()}
        blob = matches.get(requested)
        if blob is None:
            raise MapError(
                f"{requested!r} is not a tracked DMM/TGM map at " f"{repository.commit}"
            )
        data = repository.read_blob(blob)
        parsed = parse_map(data, blob.path)
        report = {
            "format_version": FORMAT_VERSION,
            "source": _source_record(repository, blob, data),
            "analysis": analyze_map(parsed, arguments.top),
        }
    _emit_json(report, arguments.pretty)
    return 0


def command_compile(arguments: argparse.Namespace) -> int:
    requested = arguments.path.replace("\\", "/").lstrip("/")
    with GitRepository(
        arguments.repo, arguments.revision, arguments.allow_unpinned
    ) as repository:
        matches = {blob.path: blob for blob in repository.map_blobs()}
        blob = matches.get(requested)
        if blob is None:
            raise MapError(
                f"{requested!r} is not a tracked DMM/TGM map at " f"{repository.commit}"
            )
        data = repository.read_blob(blob)
        parsed = parse_map(data, blob.path)
        value = compile_scenario(
            parsed,
            _source_record(repository, blob, data),
            scenario_id=arguments.scenario_id,
            name=arguments.name,
            crop=tuple(arguments.crop),
            z_level=arguments.z,
            power_supply_w=arguments.power_supply_w,
        )
    if arguments.output is None:
        _emit_json(value, arguments.pretty)
        return 0
    indent = 2 if arguments.pretty else None
    separators = None if arguments.pretty else (",", ":")
    encoded = (
        json.dumps(
            value,
            indent=indent,
            sort_keys=True,
            separators=separators,
        )
        + "\n"
    )
    output = arguments.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(encoded, encoding="utf-8", newline="\n")
    _emit_json(
        {
            "bytes": len(encoded.encode("utf-8")),
            "output": (
                output.relative_to(ROOT).as_posix()
                if output.is_relative_to(ROOT)
                else str(output)
            ),
            "scenario_id": arguments.scenario_id,
            "sha256": hashlib.sha256(encoded.encode("utf-8")).hexdigest(),
        },
        pretty=True,
    )
    return 0


def _emit_json(value: object, pretty: bool) -> None:
    if pretty:
        json.dump(value, sys.stdout, indent=2, sort_keys=True)
    else:
        json.dump(
            value,
            sys.stdout,
            sort_keys=True,
            separators=(",", ":"),
        )
    sys.stdout.write("\n")


def _repository_path(value: str) -> Path:
    return Path(value).expanduser()


def _add_source_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--repo",
        type=_repository_path,
        default=DEFAULT_REPOSITORY,
        help="local Goonstation Git checkout (default: pinned asset cache)",
    )
    parser.add_argument(
        "--revision",
        default="HEAD",
        help="Git revision to read (default: HEAD)",
    )
    parser.add_argument(
        "--allow-unpinned",
        action="store_true",
        help="permit a revision other than the asset lock commit",
    )
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="indent JSON output (compact deterministic JSON is the default)",
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Inventory and analyze immutable DMM/TGM maps from the pinned "
            "Goonstation Git tree."
        )
    )
    commands = parser.add_subparsers(dest="command", required=True)

    inventory = commands.add_parser(
        "inventory",
        help="summarize map candidates with deterministic selection signals",
    )
    _add_source_arguments(inventory)
    inventory.add_argument(
        "--prefix",
        default="maps/",
        help="tracked path prefix (default: maps/)",
    )
    inventory.add_argument(
        "--max-depth",
        type=int,
        default=0,
        help=(
            "maximum directory depth below prefix; 0 selects direct files, "
            "omit a limit with -1"
        ),
    )
    inventory.set_defaults(handler=command_inventory)

    analyze = commands.add_parser(
        "analyze",
        help="analyze one tracked map's layout and atom placements",
    )
    _add_source_arguments(analyze)
    analyze.add_argument("path", help="repository-relative DMM/TGM path")
    analyze.add_argument(
        "--top",
        type=int,
        default=25,
        help="maximum records per ranked section (default: 25)",
    )
    analyze.set_defaults(handler=command_analyze)

    compile_map = commands.add_parser(
        "compile",
        help="compile one bounded map view into native Sim Station JSON",
    )
    _add_source_arguments(compile_map)
    compile_map.add_argument("path", help="repository-relative DMM/TGM path")
    compile_map.add_argument(
        "--scenario-id",
        required=True,
        help="namespaced scenario content ID",
    )
    compile_map.add_argument("--name", required=True, help="scenario display name")
    compile_map.add_argument(
        "--crop",
        nargs=4,
        type=int,
        metavar=("MIN_X", "MIN_Y", "MAX_X", "MAX_Y"),
        required=True,
        help="inclusive source-coordinate crop",
    )
    compile_map.add_argument("--z", type=int, default=1, help="source z level")
    compile_map.add_argument(
        "--power-supply-w",
        type=int,
        default=750_000,
        help="initial station generation capacity",
    )
    compile_map.add_argument(
        "--output",
        type=Path,
        help="write scenario JSON to this path instead of stdout",
    )
    compile_map.set_defaults(handler=command_compile)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    arguments = parser.parse_args(argv)
    max_depth = getattr(arguments, "max_depth", None)
    if max_depth is not None and max_depth < 0:
        arguments.max_depth = None
    if getattr(arguments, "top", 1) < 1:
        parser.error("--top must be at least 1")
    try:
        return arguments.handler(arguments)
    except (MapError, OSError, subprocess.SubprocessError) as error:
        print(f"map-import: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
