#!/usr/bin/env python3
"""Fetch and compile the pinned Goon graphics and audio forks.

The game never reads DMI or tracker formats at runtime. This tool preserves
immutable upstream inputs, emits editable PNG/TOML source, and builds portable
LÖVE atlases and Ogg audio catalogs.
"""

from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from decimal import Decimal, InvalidOperation
import hashlib
import json
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
from typing import Any, Iterable

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
UPSTREAM = ASSETS / "upstream" / "goon"
SOURCE = ASSETS / "source" / "goon"
RUNTIME = ASSETS / "runtime" / "goon"
CACHE = ASSETS / "cache" / "goonstation"
GOON_REPOSITORY = "https://github.com/goonstation/goonstation.git"
GOON_COMMIT = "1b2b250abb5be747d55e274de0203a59cfc8da78"
PAGE_SIZE = 2048
GUTTER = 1
PACK_ID = "org.simstation.goon"
DM_APPEARANCE_PROFILE = SOURCE / "dm-appearance-profile.json"
DM_APPEARANCE_RUNTIME = RUNTIME / "graphics" / "dm-appearances.json"
DM_APPEARANCE_BUNDLE = "dm_appearances"
DM_APPEARANCE_ATLAS = RUNTIME / "graphics" / DM_APPEARANCE_BUNDLE

FOUNDATION_SPRITES = {
    "apc": (
        "org.simstation.goon:sprite/icons/obj/power-dmi/"
        "apc0--afcf739cd9-o01"
    ),
    "catwalk": (
        "org.simstation.goon:sprite/icons/obj/grille-dmi/"
        "catwalk--b98443a7fa-o01"
    ),
    "chair": (
        "org.simstation.goon:sprite/icons/obj/furniture/chairs-dmi/"
        "chair--851e13a653-o01"
    ),
    "crate": (
        "org.simstation.goon:sprite/icons/obj/storage/crate-dmi/"
        "crate--1673dc3970-o01"
    ),
    "crew_female": (
        "org.simstation.goon:sprite/icons/mob/human-dmi/"
        "body_f--4ed48d58ce-o01"
    ),
    "crew_male": (
        "org.simstation.goon:sprite/icons/mob/human-dmi/"
        "body_m--04641b6d93-o01"
    ),
    "door_closed": (
        "org.simstation.goon:sprite/icons/obj/doors/doorclassic-dmi/"
        "door_closed--553558f5ff-o01"
    ),
    "door_open": (
        "org.simstation.goon:sprite/icons/obj/doors/doorclassic-dmi/"
        "door_open--5fe7ebb3c8-o01"
    ),
    "decal": (
        "org.simstation.goon:sprite/icons/obj/hazard_stripes-dmi/"
        "stripe--2fcb5a43a4-o01"
    ),
    "disposal": (
        "org.simstation.goon:sprite/icons/obj/disposal-dmi/"
        "disposal--4edc28b0fb-o01"
    ),
    "floor": (
        "org.simstation.goon:sprite/icons/turf/floors-dmi/"
        "floor--3684c9d3c0-o01"
    ),
    "floor_white": (
        "org.simstation.goon:sprite/icons/turf/floors-dmi/"
        "white--528cef87d0-o01"
    ),
    "fabricator": (
        "org.simstation.goon:sprite/icons/obj/manufacturer-dmi/"
        "fab-general--cf2f46a0d3-o01"
    ),
    "generator": (
        "org.simstation.goon:sprite/icons/obj/power-dmi/"
        "teg--7c8224529a-o01"
    ),
    "grille": (
        "org.simstation.goon:sprite/icons/obj/grille-dmi/"
        "grille-0--59a5a19a50-o01"
    ),
    "lattice": (
        "org.simstation.goon:sprite/icons/obj/structures-dmi/"
        "lattice--6e0a57eb0d-o01"
    ),
    "light": (
        "org.simstation.goon:sprite/icons/obj/lighting-dmi/"
        "tube1--75faa72913-o01"
    ),
    "pipe": (
        "org.simstation.goon:sprite/icons/obj/atmospherics/pipes/pipe-dmi/"
        "normal--9c2a6e4809-o01"
    ),
    "plating": (
        "org.simstation.goon:sprite/icons/turf/floors-dmi/"
        "plating--eea474ed21-o01"
    ),
    "refinery": (
        "org.simstation.goon:sprite/icons/obj/crafting-dmi/"
        "fab2-on--e654caa777-o01"
    ),
    "reinforced_floor": (
        "org.simstation.goon:sprite/icons/turf/floors-dmi/"
        "engine--c64033672f-o01"
    ),
    "reinforced_wall": (
        "org.simstation.goon:sprite/icons/turf/walls-dmi/"
        "r_wall--a3c258120b-o01"
    ),
    "scrubber": (
        "org.simstation.goon:sprite/icons/obj/atmospherics/"
        "vent_scrubber-dmi/on-map--a3645389b9-o01"
    ),
    "sign": (
        "org.simstation.goon:sprite/icons/obj/decals/wallsigns-dmi/"
        "wall_caution--1756bab6e8-o01"
    ),
    "storage": (
        "org.simstation.goon:sprite/icons/obj/storage/locker-dmi/"
        "closed--ea88fbaa99-o01"
    ),
    "table": (
        "org.simstation.goon:sprite/icons/obj/furniture/table-dmi/"
        "0--b6589fc6ab-o01"
    ),
    "vent": (
        "org.simstation.goon:sprite/icons/obj/atmospherics/"
        "vent_pump-dmi/out-map--60b67c84ae-o01"
    ),
    "wall": (
        "org.simstation.goon:sprite/icons/turf/walls-dmi/"
        "riveted--b2df855a7c-o01"
    ),
    "window": (
        "org.simstation.goon:sprite/icons/obj/window-dmi/"
        "window--320ad267d8-o01"
    ),
}
FOUNDATION_CELL_SIZE = 32

FOUNDATION_AUDIO = {
    "bailout": "org.simstation.goon:audio/sound/misc/cashregister",
    "construction": "org.simstation.goon:audio/sound/machines/constructor_work",
    "door_close": "org.simstation.goon:audio/sound/machines/door_close",
    "door_open": "org.simstation.goon:audio/sound/machines/door_open",
    "major_alert": "org.simstation.goon:audio/sound/effects/ship_alert_major",
    "medical_alert": "org.simstation.goon:audio/sound/items/medical_alert",
    "meteor": "org.simstation.goon:audio/sound/effects/explosion_new1",
    "rejected": "org.simstation.goon:audio/sound/machines/warning-buzzer",
    "shift_bell": "org.simstation.goon:audio/sound/machines/bellalert",
    "station_chime": "org.simstation.goon:audio/sound/machines/chime",
    "ui_click": "org.simstation.goon:audio/sound/impact_sounds/generic_click_1",
}

FETCH_PATHS = [
    "icons",
    "assets/icons",
    "sound",
    "LICENSE",
    "README.md",
    ".github/AUDIO_GUIDELINES.md",
    "strings/changelog_attribution/spriters.txt",
    "tools/dmi",
    "maps/atlas.dmm",
]

AUDIO_EXTENSIONS = {".ogg", ".xm", ".mod", ".s3m"}
GRAPHICS_SOURCE_EXTENSIONS = {".dmi", ".png", ".psd", ".xcf", ".pdn"}
DIRECTIONS = [
    "south",
    "north",
    "east",
    "west",
    "southeast",
    "southwest",
    "northeast",
    "northwest",
]
KNOWN_DMI_KEYS = {
    "version",
    "width",
    "height",
    "state",
    "dirs",
    "frames",
    "delay",
    "loop",
    "rewind",
    "movement",
    "hotspot",
}


def run(
    command: list[str],
    *,
    cwd: Path = ROOT,
    capture: bool = False,
    quiet: bool = False,
) -> subprocess.CompletedProcess[str]:
    if not quiet:
        print("+", " ".join(command), flush=True)
    return subprocess.run(
        command,
        cwd=cwd,
        check=True,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )


def safe_clean(path: Path) -> None:
    path = path.resolve()
    expected_parent = ASSETS.resolve()
    if expected_parent not in path.parents or path in {expected_parent, ROOT.resolve()}:
        raise RuntimeError(f"refusing to clean unsafe path: {path}")
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def git_blob_oid(path: Path) -> str:
    data = path.read_bytes()
    digest = hashlib.sha1()
    digest.update(f"blob {len(data)}\0".encode("ascii"))
    digest.update(data)
    return digest.hexdigest()


def normalize_component(value: str) -> str:
    value = value.replace("\\", "/").lower()
    value = re.sub(r"[^a-z0-9/_-]+", "-", value)
    value = re.sub(r"-+", "-", value)
    value = re.sub(r"/+", "/", value)
    return value.strip("-/")


def sprite_id(relative: str, state: str, occurrence: int) -> str:
    # Keep the source extension in the ID because the pinned tree contains
    # same-stem DMI and PNG files which are distinct upstream assets.
    path = normalize_component(relative)
    slug = normalize_component(state) or "default"
    state_hash = hashlib.sha1(state.encode("utf-8")).hexdigest()[:10]
    return f"{PACK_ID}:sprite/{path}/{slug}--{state_hash}-o{occurrence:02d}"


def audio_id(relative: str) -> str:
    path = normalize_component(str(Path(relative).with_suffix("")))
    return f"{PACK_ID}:audio/{path}"


def json_dump(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, sort_keys=True, ensure_ascii=False)
        handle.write("\n")


def fetch_goon(_: argparse.Namespace) -> None:
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    if not (CACHE / ".git").exists():
        run([
            "git",
            "clone",
            "--filter=blob:none",
            "--no-checkout",
            GOON_REPOSITORY,
            str(CACHE),
        ])
    run(["git", "fetch", "--depth", "1", "origin", GOON_COMMIT], cwd=CACHE)
    sparse_patterns = [
        "/icons/",
        "/assets/icons/",
        "/sound/",
        "/LICENSE",
        "/README.md",
        "/.github/AUDIO_GUIDELINES.md",
        "/strings/changelog_attribution/spriters.txt",
        "/tools/dmi/",
        "/maps/atlas.dmm",
    ]
    run(["git", "sparse-checkout", "init", "--no-cone"], cwd=CACHE)
    run(
        ["git", "sparse-checkout", "set", "--no-cone", *sparse_patterns],
        cwd=CACHE,
    )
    run(["git", "checkout", "--detach", GOON_COMMIT], cwd=CACHE)

    preserved_lock = UPSTREAM / "upstream.lock.toml"
    lock_text = preserved_lock.read_text(encoding="utf-8")
    safe_clean(UPSTREAM)
    preserved_lock.write_text(lock_text, encoding="utf-8", newline="\n")

    for relative in FETCH_PATHS:
        source = CACHE / relative
        destination = UPSTREAM / relative
        if source.is_dir():
            shutil.copytree(source, destination, dirs_exist_ok=True)
        elif source.exists():
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
        else:
            raise FileNotFoundError(f"pinned path is missing: {relative}")

    tree = run(
        ["git", "ls-tree", "-r", "-l", GOON_COMMIT, "--", *FETCH_PATHS],
        cwd=CACHE,
        capture=True,
    ).stdout
    records: list[dict[str, Any]] = []
    pattern = re.compile(
        r"^(?P<mode>\d+) blob (?P<oid>[0-9a-f]+)\s+(?P<size>\d+|-)\t(?P<path>.+)$"
    )
    for line in tree.splitlines():
        match = pattern.match(line)
        if not match:
            continue
        records.append({
            "path": match.group("path"),
            "git_blob_oid": match.group("oid"),
            "size": int(match.group("size")),
        })
    json_dump(UPSTREAM / "upstream-files.json", {
        "repository": GOON_REPOSITORY,
        "commit": GOON_COMMIT,
        "files": sorted(records, key=lambda row: row["path"]),
    })
    print(f"fetched {len(records):,} pinned files")


@dataclass
class DmiState:
    name: str
    dirs: int = 1
    frames: int = 1
    raw_delay: list[str] = field(default_factory=list)
    loop: int = 0
    rewind: bool = False
    movement: bool = False
    hotspots: list[list[int]] = field(default_factory=list)

    def normalized_delay(self) -> list[str]:
        result: list[str] = []
        for index in range(self.frames):
            raw = self.raw_delay[index] if index < len(self.raw_delay) else "1"
            try:
                value = Decimal(raw)
            except InvalidOperation:
                value = Decimal(1)
            result.append(format(value, "f"))
        return result


@dataclass
class DmiMetadata:
    width: int
    height: int
    version: str
    states: list[DmiState]


def parse_quoted(value: str) -> str:
    if len(value) < 2 or value[0] != '"' or value[-1] != '"':
        raise ValueError(f"invalid DMI quoted value: {value}")
    body = value[1:-1]
    result: list[str] = []
    position = 0
    while position < len(body):
        character = body[position]
        if character == "\\" and position + 1 < len(body):
            position += 1
            character = body[position]
        result.append(character)
        position += 1
    return "".join(result)


def parse_dmi_metadata(description: str, source: Path) -> DmiMetadata:
    version = ""
    width = 32
    height = 32
    states: list[DmiState] = []
    current: DmiState | None = None
    in_descriptor = False

    for raw_line in description.splitlines():
        line = raw_line.strip()
        if line == "# BEGIN DMI":
            in_descriptor = True
            continue
        if line == "# END DMI":
            break
        if not in_descriptor or not line or line.startswith("#"):
            continue
        if "=" not in line:
            raise ValueError(f"{source}: malformed DMI metadata line: {line}")
        key, raw_value = (part.strip() for part in line.split("=", 1))
        if key not in KNOWN_DMI_KEYS:
            raise ValueError(f"{source}: unknown DMI metadata key: {key}")
        if key == "version":
            version = raw_value
        elif key == "width":
            width = int(raw_value)
        elif key == "height":
            height = int(raw_value)
        elif key == "state":
            current = DmiState(name=parse_quoted(raw_value))
            states.append(current)
        elif current is None:
            raise ValueError(f"{source}: state field {key} appears before a state")
        elif key == "dirs":
            current.dirs = int(raw_value)
        elif key == "frames":
            current.frames = int(raw_value)
        elif key == "delay":
            current.raw_delay = [part.strip() for part in raw_value.split(",")]
        elif key == "loop":
            current.loop = int(raw_value)
        elif key == "rewind":
            current.rewind = int(raw_value) != 0
        elif key == "movement":
            current.movement = int(raw_value) != 0
        elif key == "hotspot":
            current.hotspots.append(
                [int(part.strip()) for part in raw_value.split(",")]
            )

    if not version or not states:
        raise ValueError(f"{source}: missing DMI descriptor or states")
    if any(state.dirs not in {1, 4, 8} for state in states):
        raise ValueError(f"{source}: unsupported direction count")
    return DmiMetadata(width=width, height=height, version=version, states=states)


def read_dmi(path: Path) -> tuple[Image.Image, DmiMetadata]:
    image = Image.open(path)
    image.load()
    description = image.info.get("Description")
    if not isinstance(description, str):
        raise ValueError(f"{path}: PNG has no DMI Description")
    metadata = parse_dmi_metadata(description, path)
    columns = image.width // metadata.width
    rows = image.height // metadata.height
    expected = sum(state.dirs * state.frames for state in metadata.states)
    if columns * rows < expected:
        raise ValueError(
            f"{path}: descriptor needs {expected} cells, sheet has {columns * rows}"
        )
    return image.convert("RGBA"), metadata


def toml_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def write_dmi_toml(
    path: Path,
    relative: str,
    metadata: DmiMetadata,
    source_hash: str,
) -> None:
    lines = [
        "format_version = 1",
        f"source_path = {toml_string(relative)}",
        f"source_commit = {toml_string(GOON_COMMIT)}",
        f"source_sha256 = {toml_string(source_hash)}",
        f"dmi_version = {toml_string(metadata.version)}",
        f"cell_width = {metadata.width}",
        f"cell_height = {metadata.height}",
        "",
    ]
    for state in metadata.states:
        lines.extend([
            "[[states]]",
            f"name = {toml_string(state.name)}",
            f"dirs = {state.dirs}",
            f"frames = {state.frames}",
            "raw_delay_ds = ["
            + ", ".join(toml_string(value) for value in state.raw_delay)
            + "]",
            "delay_ds = ["
            + ", ".join(toml_string(value) for value in state.normalized_delay())
            + "]",
            f"loop = {state.loop}",
            f"rewind = {str(state.rewind).lower()}",
            f"movement = {str(state.movement).lower()}",
            "hotspots_raw = ["
            + ", ".join(toml_string(",".join(map(str, row))) for row in state.hotspots)
            + "]",
            "",
        ])
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def graphics_paths() -> list[Path]:
    result: list[Path] = []
    for base in [UPSTREAM / "icons", UPSTREAM / "assets" / "icons"]:
        if base.exists():
            result.extend(
                path for path in base.rglob("*")
                if path.is_file() and path.suffix.lower() in GRAPHICS_SOURCE_EXTENSIONS
            )
    return sorted(result, key=lambda path: path.relative_to(UPSTREAM).as_posix())


def import_graphics_source(_: argparse.Namespace) -> None:
    if not (UPSTREAM / "icons").exists():
        raise SystemExit("run fetch-goon first")
    output = SOURCE / "graphics"
    safe_clean(output)
    inventory: list[dict[str, Any]] = []
    errors: list[str] = []
    paths = graphics_paths()
    for number, source_path in enumerate(paths, 1):
        relative = source_path.relative_to(UPSTREAM).as_posix()
        destination = output / relative
        source_hash = sha256_file(source_path)
        record: dict[str, Any] = {
            "path": relative,
            "sha256": source_hash,
            "bytes": source_path.stat().st_size,
            "kind": source_path.suffix.lower().lstrip("."),
        }
        if source_path.suffix.lower() == ".dmi":
            try:
                image, metadata = read_dmi(source_path)
                image.close()
                png_destination = destination.with_suffix(".dmi.png")
                png_destination.parent.mkdir(parents=True, exist_ok=True)
                # DMI is already a valid lossless PNG; retain its bytes and
                # move human-editable animation metadata into TOML.
                shutil.copy2(source_path, png_destination)
                write_dmi_toml(
                    destination.with_suffix(".dmi.toml"),
                    relative,
                    metadata,
                    source_hash,
                )
                record.update({
                    "states": len(metadata.states),
                    "cells": sum(s.dirs * s.frames for s in metadata.states),
                    "cell_width": metadata.width,
                    "cell_height": metadata.height,
                })
            except Exception as error:  # continue to produce a full audit
                errors.append(f"{relative}: {error}")
        else:
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source_path, destination)
        inventory.append(record)
        if number % 100 == 0:
            print(f"source graphics {number:,}/{len(paths):,}")
    json_dump(output / "graphics-source.json", {
        "format_version": 1,
        "source_commit": GOON_COMMIT,
        "files": inventory,
        "errors": errors,
    })
    if errors:
        raise SystemExit(f"graphics source import reported {len(errors)} errors")
    print(f"imported {len(inventory):,} graphics source files")


def bundle_for(relative: str) -> str:
    path = relative.lower()
    if "/cursors/" in path or "/ui/" in path or "widescreen" in path:
        return "ui"
    if "/turf/" in path:
        return "core_tiles"
    if "/mob/" in path:
        return "crew"
    if "/effects/" in path:
        return "effects"
    if "/obj/machinery" in path or "/obj/doors" in path:
        return "machines"
    if "/obj/item" in path or "/obj/food" in path:
        return "items"
    if "/map-editing/" in path or "/testing/" in path:
        return "development"
    return "specialty"


class AtlasPage:
    def __init__(self, bundle: str, number: int, output: Path) -> None:
        self.bundle = bundle
        self.number = number
        self.output = output
        self.image = Image.new("RGBA", (PAGE_SIZE, PAGE_SIZE), (0, 0, 0, 0))
        self.x = GUTTER
        self.y = GUTTER
        self.row_height = 0
        self.used = False

    @property
    def filename(self) -> str:
        return f"atlas-{self.number:03d}.png"

    def place(self, frame: Image.Image) -> tuple[int, int] | None:
        width, height = frame.size
        padded_width = width + GUTTER * 2
        padded_height = height + GUTTER * 2
        if padded_width > PAGE_SIZE or padded_height > PAGE_SIZE:
            raise ValueError(f"frame {width}x{height} exceeds atlas page")
        if self.x + width + GUTTER > PAGE_SIZE:
            self.x = GUTTER
            self.y += self.row_height + GUTTER * 2
            self.row_height = 0
        if self.y + height + GUTTER > PAGE_SIZE:
            return None
        x, y = self.x, self.y
        self.image.paste(frame, (x, y))
        self.image.paste(frame.crop((0, 0, 1, height)), (x - 1, y))
        self.image.paste(frame.crop((width - 1, 0, width, height)), (x + width, y))
        self.image.paste(frame.crop((0, 0, width, 1)), (x, y - 1))
        self.image.paste(frame.crop((0, height - 1, width, height)), (x, y + height))
        self.image.putpixel((x - 1, y - 1), frame.getpixel((0, 0)))
        self.image.putpixel((x + width, y - 1), frame.getpixel((width - 1, 0)))
        self.image.putpixel((x - 1, y + height), frame.getpixel((0, height - 1)))
        self.image.putpixel(
            (x + width, y + height),
            frame.getpixel((width - 1, height - 1)),
        )
        self.x += padded_width
        self.row_height = max(self.row_height, height)
        self.used = True
        return x, y

    def save(self) -> dict[str, Any] | None:
        if not self.used:
            return None
        path = self.output / self.filename
        path.parent.mkdir(parents=True, exist_ok=True)
        self.image.save(path, "PNG", optimize=False, compress_level=9)
        self.image.close()
        return {
            "file": self.filename,
            "width": PAGE_SIZE,
            "height": PAGE_SIZE,
            "format": "rgba8-png",
            "sha256": sha256_file(path),
        }


def iter_dmi_frames(
    image: Image.Image,
    metadata: DmiMetadata,
) -> Iterable[tuple[DmiState, int, int, str, Image.Image]]:
    columns = image.width // metadata.width
    cell = 0
    for state in metadata.states:
        delays = state.normalized_delay()
        for frame_index in range(state.frames):
            for direction_index in range(state.dirs):
                column = cell % columns
                row = cell // columns
                left = column * metadata.width
                top = row * metadata.height
                frame = image.crop(
                    (left, top, left + metadata.width, top + metadata.height)
                )
                direction = DIRECTIONS[direction_index]
                yield state, frame_index, direction_index, direction, frame
                cell += 1


def build_graphics(_: argparse.Namespace) -> None:
    if not (UPSTREAM / "icons").exists():
        raise SystemExit("run fetch-goon first")
    output = RUNTIME / "graphics"
    safe_clean(output)
    dmis = [
        path for path in graphics_paths()
        if path.suffix.lower() in {".dmi", ".png"}
    ]
    grouped: dict[str, list[Path]] = defaultdict(list)
    for path in dmis:
        relative = path.relative_to(UPSTREAM).as_posix()
        grouped[bundle_for(relative)].append(path)

    catalog: dict[str, Any] = {
        "format_version": 1,
        "pack_id": PACK_ID,
        "source_commit": GOON_COMMIT,
        "tile_size": 32,
        "page_size": PAGE_SIZE,
        "gutter": GUTTER,
        "bundles": {},
        "sprites": {},
        "warnings": [],
    }
    all_ids: set[str] = set()
    total_cells = 0

    for bundle in sorted(grouped):
        bundle_output = output / bundle
        bundle_output.mkdir(parents=True, exist_ok=True)
        page_number = 0
        page = AtlasPage(bundle, page_number, bundle_output)
        pages: list[dict[str, Any]] = []
        dedupe: dict[str, dict[str, Any]] = {}
        bundle_sprites: list[str] = []

        for file_number, source_path in enumerate(grouped[bundle], 1):
            relative = source_path.relative_to(UPSTREAM).as_posix()
            if source_path.suffix.lower() == ".dmi":
                image, metadata = read_dmi(source_path)
            else:
                image = Image.open(source_path).convert("RGBA")
                metadata = DmiMetadata(
                    width=image.width,
                    height=image.height,
                    version="png",
                    states=[DmiState(name="", dirs=1, frames=1)],
                )

            state_entries: dict[int, dict[str, Any]] = {}
            source_digest = sha256_file(source_path)
            state_occurrences: Counter[str] = Counter()
            for state_index, state in enumerate(metadata.states, 1):
                state_occurrences[state.name] += 1
                occurrence = state_occurrences[state.name]
                identifier = sprite_id(relative, state.name, occurrence)
                if identifier in all_ids:
                    raise ValueError(f"duplicate generated sprite ID: {identifier}")
                all_ids.add(identifier)
                state_entries[id(state)] = {
                    "id": identifier,
                    "bundle": bundle,
                    "source_path": relative,
                    "source_sha256": source_digest,
                    "source_state": state.name,
                    "source_state_index": state_index,
                    "source_state_occurrence": occurrence,
                    "cell_width": metadata.width,
                    "cell_height": metadata.height,
                    "dirs": state.dirs,
                    "frames": state.frames,
                    "raw_delay_ds": state.raw_delay,
                    "delay_ds": state.normalized_delay(),
                    "loop": state.loop,
                    "rewind": state.rewind,
                    "movement": state.movement,
                    "hotspots_raw": state.hotspots,
                    "directions": {},
                }
                if len(state.raw_delay) > state.frames:
                    catalog["warnings"].append({
                        "path": relative,
                        "state": state.name,
                        "warning": "extra delay values preserved and ignored at runtime",
                    })
                bundle_sprites.append(identifier)

            for state, frame_index, _, direction, frame in iter_dmi_frames(
                image, metadata
            ):
                entry = state_entries[id(state)]
                digest = hashlib.sha256(
                    f"{frame.width}x{frame.height}:".encode("ascii")
                    + frame.tobytes()
                ).hexdigest()
                location = dedupe.get(digest)
                if location is None:
                    placed = page.place(frame)
                    if placed is None:
                        page_record = page.save()
                        assert page_record
                        pages.append(page_record)
                        page_number += 1
                        page = AtlasPage(bundle, page_number, bundle_output)
                        placed = page.place(frame)
                        assert placed
                    location = {
                        "page": page.number,
                        "x": placed[0],
                        "y": placed[1],
                        "w": frame.width,
                        "h": frame.height,
                    }
                    dedupe[digest] = location
                direction_frames = entry["directions"].setdefault(direction, [])
                delay = entry["delay_ds"][frame_index]
                direction_frames.append({
                    **location,
                    "duration_ds": delay,
                    "frame": frame_index + 1,
                })
                total_cells += 1
                frame.close()
            for entry in state_entries.values():
                catalog["sprites"][entry["id"]] = entry
            image.close()
            if file_number % 100 == 0:
                print(
                    f"atlas {bundle}: {file_number:,}/{len(grouped[bundle]):,} files"
                )

        page_record = page.save()
        if page_record:
            pages.append(page_record)
        catalog["bundles"][bundle] = {
            "pages": pages,
            "sprites": sorted(bundle_sprites),
            "unique_frames": len(dedupe),
        }
        print(
            f"built {bundle}: {len(bundle_sprites):,} sprites, "
            f"{len(dedupe):,} unique frames, {len(pages):,} pages"
        )

    json_dump(output / "atlas.json", catalog)
    provenance = {
        "format_version": 1,
        "repository": GOON_REPOSITORY,
        "commit": GOON_COMMIT,
        "license": "CC-BY-NC-SA-3.0-US",
        "generator": "tools/assets.py",
        "sprite_count": len(catalog["sprites"]),
        "frame_direction_cells": total_cells,
        "catalog_sha256": sha256_file(output / "atlas.json"),
    }
    json_dump(output / "provenance.json", provenance)
    print(
        f"graphics complete: {len(catalog['sprites']):,} sprites, "
        f"{total_cells:,} frame-direction cells"
    )


def audio_paths() -> list[Path]:
    base = UPSTREAM / "sound"
    if not base.exists():
        return []
    return sorted(
        (path for path in base.rglob("*")
         if path.is_file() and path.suffix.lower() in AUDIO_EXTENSIONS),
        key=lambda path: path.relative_to(UPSTREAM).as_posix(),
    )


def probe_audio(path: Path) -> dict[str, Any]:
    result = run([
        "ffprobe",
        "-v",
        "error",
        "-show_entries",
        "format=duration:stream=codec_name,sample_rate,channels",
        "-of",
        "json",
        str(path),
    ], capture=True, quiet=True)
    data = json.loads(result.stdout)
    streams = data.get("streams") or []
    if not streams:
        raise ValueError(f"{path}: no audio stream")
    stream = streams[0]
    return {
        "codec": stream.get("codec_name"),
        "sample_rate": int(stream.get("sample_rate") or 0),
        "channels": int(stream.get("channels") or 0),
        "duration_seconds": round(float(data["format"]["duration"]), 6),
    }


def audio_bus(relative: str) -> str:
    parts = Path(relative).parts
    category = parts[1] if len(parts) > 1 else "misc"
    return {
        "ambience": "ambience",
        "radio_station": "music",
        "voice": "speech",
        "vox": "speech",
        "machines": "machinery",
    }.get(category, "sfx")


def ogg_crc_table() -> list[int]:
    table: list[int] = []
    for value in range(256):
        remainder = value << 24
        for _ in range(8):
            remainder = (
                ((remainder << 1) ^ 0x04C11DB7)
                if remainder & 0x80000000
                else remainder << 1
            ) & 0xFFFFFFFF
        table.append(remainder)
    return table


OGG_CRC_TABLE = ogg_crc_table()


def canonicalize_ogg(path: Path, serial: int) -> None:
    """Replace randomized Ogg stream serials and recompute page CRCs."""
    data = bytearray(path.read_bytes())
    offset = 0
    pages = 0
    while offset < len(data):
        if data[offset:offset + 4] != b"OggS" or offset + 27 > len(data):
            raise ValueError(f"{path}: invalid Ogg page at byte {offset}")
        segment_count = data[offset + 26]
        header_end = offset + 27 + segment_count
        if header_end > len(data):
            raise ValueError(f"{path}: truncated Ogg segment table")
        body_length = sum(data[offset + 27:header_end])
        page_end = header_end + body_length
        if page_end > len(data):
            raise ValueError(f"{path}: truncated Ogg page body")
        struct.pack_into("<I", data, offset + 14, serial & 0xFFFFFFFF)
        data[offset + 22:offset + 26] = b"\0\0\0\0"
        checksum = 0
        for byte in data[offset:page_end]:
            checksum = (
                ((checksum << 8) & 0xFFFFFFFF)
                ^ OGG_CRC_TABLE[((checksum >> 24) & 0xFF) ^ byte]
            )
        struct.pack_into("<I", data, offset + 22, checksum)
        offset = page_end
        pages += 1
    if offset != len(data) or pages == 0:
        raise ValueError(f"{path}: invalid Ogg page layout")
    path.write_bytes(data)


def build_audio(_: argparse.Namespace) -> None:
    paths = audio_paths()
    if not paths:
        raise SystemExit("run fetch-goon first")
    source_output = SOURCE / "audio"
    runtime_output = RUNTIME / "audio"
    safe_clean(source_output)
    safe_clean(runtime_output)

    entries: dict[str, Any] = {}
    hashes: dict[str, str] = {}
    categories: Counter[str] = Counter()
    total_duration = 0.0

    for number, source_path in enumerate(paths, 1):
        relative = source_path.relative_to(UPSTREAM).as_posix()
        source_destination = source_output / relative
        source_destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source_path, source_destination)

        identifier = audio_id(relative)
        if identifier in entries:
            raise ValueError(f"duplicate generated audio ID: {identifier}")
        runtime_relative = Path(relative)
        conversion: dict[str, Any] | None = None
        if source_path.suffix.lower() == ".ogg":
            runtime_destination = runtime_output / runtime_relative
            runtime_destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source_path, runtime_destination)
        else:
            runtime_relative = runtime_relative.with_suffix(".ogg")
            runtime_destination = runtime_output / runtime_relative
            runtime_destination.parent.mkdir(parents=True, exist_ok=True)
            command = [
                "ffmpeg",
                "-v",
                "error",
                "-y",
                "-i",
                str(source_path),
                "-map_metadata",
                "-1",
                "-ar",
                "48000",
                "-ac",
                "2",
                "-c:a",
                "libvorbis",
                "-q:a",
                "5",
                str(runtime_destination),
            ]
            run(command)
            source_digest = sha256_file(source_path)
            canonical_serial = int(source_digest[:8], 16)
            canonicalize_ogg(runtime_destination, canonical_serial)
            conversion = {
                "tool": "ffmpeg+libopenmpt",
                "recipe": [
                    "-v",
                    "error",
                    "-y",
                    "-i",
                    "{source}",
                    "-map_metadata",
                    "-1",
                    "-ar",
                    "48000",
                    "-ac",
                    "2",
                    "-c:a",
                    "libvorbis",
                    "-q:a",
                    "5",
                    "{output}",
                ],
                "canonical_ogg_serial": canonical_serial,
                "canonicalization": "fixed-stream-serial-and-page-crc",
            }

        probe = probe_audio(runtime_destination)
        total_duration += probe["duration_seconds"]
        source_digest = sha256_file(source_path)
        runtime_digest = sha256_file(runtime_destination)
        hashes.setdefault(runtime_digest, identifier)
        category = Path(relative).parts[1]
        categories[category] += 1
        bus = audio_bus(relative)
        positional = probe["channels"] == 1 and bus not in {"music", "ui"}
        stream = probe["duration_seconds"] > 10 or bus in {"music", "ambience"}
        entries[identifier] = {
            "id": identifier,
            "source_path": relative,
            "source_commit": GOON_COMMIT,
            "source_sha256": source_digest,
            "runtime_path": runtime_relative.as_posix(),
            "runtime_sha256": runtime_digest,
            **probe,
            "source_type": "stream" if stream else "static",
            "bus": bus,
            "positional": positional,
            "loop": bus == "ambience",
            "loop_start_samples": None,
            "loop_end_samples": None,
            "gain_db": 0,
            "loudness_status": "pending-review",
            "priority": 100 if bus in {"speech", "ui"} else 50,
            "max_instances": 4,
            "cooldown_ms": 0,
            "caption_key": None,
            "license": "CC-BY-NC-SA-3.0-US",
            "rights_basis": "goon-root-license",
            "conversion": conversion,
            "content_duplicate_of": (
                hashes[runtime_digest]
                if hashes[runtime_digest] != identifier
                else None
            ),
        }
        if number % 250 == 0:
            print(f"audio {number:,}/{len(paths):,}")

    catalog = {
        "format_version": 1,
        "pack_id": PACK_ID,
        "source_commit": GOON_COMMIT,
        "voice_limit": 64,
        "decoded_cache_mib": 96,
        "buses": [
            "master",
            "music",
            "ambience",
            "speech",
            "ui",
            "alarms",
            "machinery",
            "sfx",
        ],
        "entries": entries,
        "summary": {
            "files": len(entries),
            "duration_seconds": round(total_duration, 3),
            "categories": dict(sorted(categories.items())),
        },
    }
    json_dump(runtime_output / "audio.json", catalog)
    json_dump(runtime_output / "provenance.json", {
        "format_version": 1,
        "repository": GOON_REPOSITORY,
        "commit": GOON_COMMIT,
        "license": "CC-BY-NC-SA-3.0-US",
        "rights_policy": "trust-goon-root-license",
        "generator": "tools/assets.py",
        "files": len(entries),
        "catalog_sha256": sha256_file(runtime_output / "audio.json"),
    })
    print(
        f"audio complete: {len(entries):,} files, "
        f"{total_duration / 3600:.2f} hours"
    )


def build_foundation_media(_: argparse.Namespace) -> None:
    """Extract the small, startup-safe media view used by the foundation app.

    The exhaustive catalogs remain the canonical provenance indexes. This
    postprocess only selects records from them, so it cannot change pixels,
    audio bytes, IDs, or compiler packing behavior.
    """
    atlas_path = RUNTIME / "graphics" / "atlas.json"
    audio_path = RUNTIME / "audio" / "audio.json"
    if not atlas_path.exists() or not audio_path.exists():
        raise SystemExit("run build-graphics and build-audio first")

    atlas = json.loads(atlas_path.read_text(encoding="utf-8"))
    selected_sprites: dict[str, Any] = {}
    referenced_pages: set[tuple[str, int]] = set()
    for alias, identifier in sorted(FOUNDATION_SPRITES.items()):
        entry = atlas["sprites"].get(identifier)
        if entry is None:
            raise SystemExit(f"foundation sprite is missing: {identifier}")
        selected_sprites[alias] = entry
        bundle = entry["bundle"]
        for frames in entry["directions"].values():
            for frame in frames:
                page_number = int(frame["page"])
                pages = atlas["bundles"][bundle]["pages"]
                if page_number < 0 or page_number >= len(pages):
                    raise SystemExit(
                        f"invalid page {page_number} for foundation sprite "
                        f"{identifier}"
                    )
                referenced_pages.add((bundle, page_number))

    pages: list[dict[str, Any]] = []
    for bundle, page_number in sorted(referenced_pages):
        source_record = atlas["bundles"][bundle]["pages"][page_number]
        runtime_path = f"{bundle}/{source_record['file']}"
        page_path = atlas_path.parent / runtime_path
        if (
            not page_path.exists()
            or sha256_file(page_path) != source_record["sha256"]
        ):
            raise SystemExit(f"invalid foundation atlas page: {page_path}")
        pages.append({
            **source_record,
            "bundle": bundle,
            "page": page_number,
            "runtime_path": runtime_path,
        })

    graphics_output = {
        "format_version": 1,
        "kind": "foundation-graphics-selection",
        "pack_id": atlas["pack_id"],
        "source_commit": atlas["source_commit"],
        "full_catalog_sha256": sha256_file(atlas_path),
        "pages": pages,
        "sprites": selected_sprites,
    }
    graphics_path = atlas_path.parent / "foundation.json"
    json_dump(graphics_path, graphics_output)
    build_dm_appearances(_)

    audio = json.loads(audio_path.read_text(encoding="utf-8"))
    selected_audio: dict[str, Any] = {}
    for alias, identifier in sorted(FOUNDATION_AUDIO.items()):
        entry = audio["entries"].get(identifier)
        if entry is None:
            raise SystemExit(f"foundation audio is missing: {identifier}")
        runtime_path = audio_path.parent / entry["runtime_path"]
        if (
            not runtime_path.exists()
            or sha256_file(runtime_path) != entry["runtime_sha256"]
        ):
            raise SystemExit(f"invalid foundation audio file: {runtime_path}")
        selected_audio[alias] = entry

    audio_output = {
        "format_version": 1,
        "kind": "foundation-audio-selection",
        "pack_id": audio["pack_id"],
        "source_commit": audio["source_commit"],
        "full_catalog_sha256": sha256_file(audio_path),
        "voice_limit": min(32, int(audio["voice_limit"])),
        "buses": audio["buses"],
        "entries": selected_audio,
    }
    foundation_audio_path = audio_path.parent / "foundation.json"
    json_dump(foundation_audio_path, audio_output)
    print(
        "foundation media complete: "
        f"{len(selected_sprites)} sprites, {len(pages)} atlas pages, "
        f"{len(selected_audio)} audio entries"
    )


def verify_graphics(_: argparse.Namespace) -> None:
    """Compare every compiled frame-direction cell with its source pixels."""
    atlas_path = RUNTIME / "graphics" / "atlas.json"
    if not atlas_path.exists():
        raise SystemExit("run build-graphics first")
    atlas = json.loads(atlas_path.read_text(encoding="utf-8"))
    by_source: dict[str, dict[int, dict[str, Any]]] = defaultdict(dict)
    for identifier, entry in atlas["sprites"].items():
        source_path = entry["source_path"]
        state_index = int(entry["source_state_index"])
        if state_index in by_source[source_path]:
            raise SystemExit(
                f"duplicate state index {state_index} for {source_path}"
            )
        by_source[source_path][state_index] = entry
        if entry["id"] != identifier:
            raise SystemExit(f"sprite key/id mismatch: {identifier}")

    page_cache: dict[tuple[str, int], Image.Image] = {}
    page_age: dict[tuple[str, int], int] = {}
    age = 0

    def atlas_page(bundle: str, page_number: int) -> Image.Image:
        nonlocal age
        age += 1
        key = (bundle, page_number)
        if key in page_cache:
            page_age[key] = age
            return page_cache[key]
        if len(page_cache) >= 6:
            oldest = min(page_age, key=page_age.__getitem__)
            page_cache.pop(oldest).close()
            page_age.pop(oldest)
        record = atlas["bundles"][bundle]["pages"][page_number]
        path = atlas_path.parent / bundle / record["file"]
        image = Image.open(path).convert("RGBA")
        page_cache[key] = image
        page_age[key] = age
        return image

    verified_cells = 0
    verified_files = 0
    for source_relative in sorted(by_source):
        source_path = UPSTREAM / source_relative
        if not source_path.exists():
            raise SystemExit(f"missing graphics source: {source_relative}")
        if source_path.suffix.lower() == ".dmi":
            source_image, metadata = read_dmi(source_path)
        else:
            source_image = Image.open(source_path).convert("RGBA")
            metadata = DmiMetadata(
                width=source_image.width,
                height=source_image.height,
                version="png",
                states=[DmiState(name="", dirs=1, frames=1)],
            )
        entries = by_source[source_relative]
        if len(entries) != len(metadata.states):
            raise SystemExit(
                f"state count mismatch for {source_relative}: "
                f"{len(entries)} catalog / {len(metadata.states)} source"
            )
        state_indexes = {id(state): index for index, state in enumerate(
            metadata.states,
            1,
        )}
        source_digest = sha256_file(source_path)
        for state_index, state in enumerate(metadata.states, 1):
            entry = entries.get(state_index)
            if not entry:
                raise SystemExit(
                    f"missing state {state_index} for {source_relative}"
                )
            expected = (
                state.name,
                state.dirs,
                state.frames,
                state.normalized_delay(),
                state.loop,
                state.rewind,
                state.movement,
            )
            actual = (
                entry["source_state"],
                entry["dirs"],
                entry["frames"],
                entry["delay_ds"],
                entry["loop"],
                entry["rewind"],
                entry["movement"],
            )
            if actual != expected or entry["source_sha256"] != source_digest:
                raise SystemExit(
                    f"state metadata mismatch: {source_relative} "
                    f"state {state_index}"
                )

        for state, frame_index, _, direction, frame in iter_dmi_frames(
            source_image,
            metadata,
        ):
            state_index = state_indexes[id(state)]
            entry = entries[state_index]
            location = entry["directions"][direction][frame_index]
            page = atlas_page(entry["bundle"], int(location["page"]))
            compiled = page.crop((
                int(location["x"]),
                int(location["y"]),
                int(location["x"]) + int(location["w"]),
                int(location["y"]) + int(location["h"]),
            ))
            if compiled.tobytes() != frame.tobytes():
                raise SystemExit(
                    f"pixel mismatch: {source_relative} state {state_index} "
                    f"direction {direction} frame {frame_index + 1}"
                )
            compiled.close()
            frame.close()
            verified_cells += 1
        source_image.close()
        verified_files += 1
        if verified_files % 100 == 0:
            print(
                f"verify graphics {verified_files:,}/{len(by_source):,} files"
            )
    for image in page_cache.values():
        image.close()
    expected_cells = sum(
        int(entry["dirs"]) * int(entry["frames"])
        for entry in atlas["sprites"].values()
    )
    if verified_cells != expected_cells:
        raise SystemExit(
            f"verified {verified_cells:,} cells; catalog claims "
            f"{expected_cells:,}"
        )
    print(
        f"graphics pixels ok: {verified_files:,} files, "
        f"{verified_cells:,} frame-direction cells"
    )


def verify_audio(_: argparse.Namespace) -> None:
    """Verify every runtime Ogg and prove copied sources stayed byte-identical."""
    audio_path = RUNTIME / "audio" / "audio.json"
    if not audio_path.exists():
        raise SystemExit("run build-audio first")
    catalog = json.loads(audio_path.read_text(encoding="utf-8"))
    copied = 0
    converted = 0
    total_duration = 0.0
    for number, (identifier, entry) in enumerate(
        sorted(catalog["entries"].items()),
        1,
    ):
        source_path = UPSTREAM / entry["source_path"]
        source_master = SOURCE / "audio" / entry["source_path"]
        runtime_path = audio_path.parent / entry["runtime_path"]
        if (
            not source_path.exists()
            or not source_master.exists()
            or not runtime_path.exists()
        ):
            raise SystemExit(f"missing audio files for {identifier}")
        if sha256_file(source_path) != entry["source_sha256"]:
            raise SystemExit(f"source audio hash mismatch: {identifier}")
        if sha256_file(source_master) != entry["source_sha256"]:
            raise SystemExit(f"forked audio master changed: {identifier}")
        if sha256_file(runtime_path) != entry["runtime_sha256"]:
            raise SystemExit(f"runtime audio hash mismatch: {identifier}")
        with runtime_path.open("rb") as handle:
            if handle.read(4) != b"OggS":
                raise SystemExit(f"runtime audio is not Ogg: {identifier}")
        if source_path.suffix.lower() == ".ogg":
            if entry["source_sha256"] != entry["runtime_sha256"]:
                raise SystemExit(f"copied Ogg changed bytes: {identifier}")
            if entry["conversion"] is not None:
                raise SystemExit(f"copied Ogg has conversion metadata: {identifier}")
            copied += 1
        else:
            if entry["conversion"] is None:
                raise SystemExit(f"tracker lacks conversion metadata: {identifier}")
            probe = probe_audio(runtime_path)
            if (
                probe["codec"] != entry["codec"]
                or probe["sample_rate"] != entry["sample_rate"]
                or probe["channels"] != entry["channels"]
                or abs(
                    probe["duration_seconds"] - entry["duration_seconds"]
                ) > 0.001
            ):
                raise SystemExit(f"converted audio probe mismatch: {identifier}")
            converted += 1
        total_duration += float(entry["duration_seconds"])
        if number % 500 == 0:
            print(f"verify audio {number:,}/{len(catalog['entries']):,}")
    expected_duration = float(catalog["summary"]["duration_seconds"])
    if abs(total_duration - expected_duration) > 0.01:
        raise SystemExit("audio duration summary mismatch")
    print(
        f"audio bytes ok: {copied:,} unchanged Ogg, "
        f"{converted:,} tracker conversions, "
        f"{total_duration / 3600:.2f} hours"
    )


def _path_matches(path: str, root: str, match: str) -> bool:
    if match == "exact":
        return path == root
    if match == "subtree":
        return path == root or path.startswith(root + "/")
    raise ValueError(f"unknown DM appearance match mode: {match}")


def _git_dm_sources() -> list[tuple[str, str]]:
    """Read only DM files containing appearance defaults from the pinned tree."""

    expression = (
        r"(^|[[:space:]])"
        r"(icon|icon_state|dir|pixel_x|pixel_y|layer|parent_type)"
        r"[[:space:]]*="
    )
    result = subprocess.run(
        [
            "git",
            "-C",
            str(CACHE),
            "grep",
            "-Il",
            "-E",
            expression,
            GOON_COMMIT,
            "--",
            "code",
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    prefix = GOON_COMMIT + ":"
    paths = sorted(
        line.removeprefix(prefix)
        for line in result.stdout.splitlines()
        if line.endswith(".dm")
    )
    process = subprocess.Popen(
        ["git", "-C", str(CACHE), "cat-file", "--batch"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    assert process.stdin is not None
    assert process.stdout is not None
    sources: list[tuple[str, str]] = []
    try:
        for path in paths:
            process.stdin.write(f"{GOON_COMMIT}:{path}\n".encode("utf-8"))
            process.stdin.flush()
            header = process.stdout.readline().decode("ascii").split()
            if len(header) != 3 or header[1] != "blob":
                raise ValueError(f"cannot read pinned DM source: {path}")
            size = int(header[2])
            data = process.stdout.read(size)
            if len(data) != size or process.stdout.read(1) != b"\n":
                raise ValueError(f"truncated pinned DM source: {path}")
            sources.append((path, data.decode("utf-8", "replace")))
    finally:
        process.stdin.close()
        process.wait(timeout=10)
        process.stdout.close()
        if process.stderr is not None:
            process.stderr.close()
    return sources


def _dm_indent(line: str) -> int:
    prefix = line[: len(line) - len(line.lstrip(" \t"))]
    return prefix.count("\t") + (len(prefix.replace("\t", "")) // 4)


def _dm_define_floors_calls(
    lines: list[tuple[int, int, str]],
) -> Iterable[tuple[int, str, str]]:
    """Yield bounded ``DEFINE_FLOORS(path, vars)`` invocations.

    Goon uses this macro to mirror data-only floor declarations across four
    turf roots.  This is intentionally not a general DM preprocessor: only the
    exact macro, a literal relative path, and its balanced argument text are
    accepted.
    """

    for line_index, (line_number, _, code) in enumerate(lines):
        if not re.match(r"^DEFINE_FLOORS\s*\(", code):
            continue
        chunks: list[str] = []
        depth = 0
        quote: str | None = None
        escaped = False
        complete = False
        for _, _, continuation in lines[line_index:]:
            chunks.append(continuation)
            for character in continuation:
                if escaped:
                    escaped = False
                    continue
                if character == "\\" and quote is not None:
                    escaped = True
                    continue
                if quote is not None:
                    if character == quote:
                        quote = None
                    continue
                if character in {'"', "'"}:
                    quote = character
                elif character == "(":
                    depth += 1
                elif character == ")":
                    depth -= 1
                    if depth == 0:
                        complete = True
                        break
            if complete:
                break
        if not complete:
            continue
        invocation = " ".join(chunks).replace("\\", "")
        match = re.fullmatch(
            r"DEFINE_FLOORS\s*\(\s*([A-Za-z0-9_/]+)\s*,(.*)\)\s*",
            invocation,
        )
        if match:
            yield line_number, match.group(1).strip("/"), match.group(2)


def _dm_macro_appearance_values(body: str) -> dict[str, str | int]:
    """Parse only literal initial-appearance assignments from macro vars."""

    result: dict[str, str | int] = {}
    for statement in body.split(";"):
        match = re.fullmatch(
            r"\s*(icon|icon_state|dir|pixel_x|pixel_y|layer|parent_type)"
            r"\s*=\s*(.*?)\s*",
            statement,
        )
        if not match:
            continue
        name, raw_value = match.groups()
        value: str | int | None = None
        if name == "icon":
            matched_value = re.fullmatch(
                r"'((?:assets/)?icons/[^']+\.dmi)'",
                raw_value,
            )
            value = matched_value.group(1) if matched_value else None
        elif name == "icon_state":
            matched_value = re.fullmatch(r'"([^"]*)"', raw_value)
            value = matched_value.group(1) if matched_value else None
        elif name == "parent_type":
            matched_value = re.fullmatch(r"(/[-A-Za-z0-9_/]+)", raw_value)
            value = (
                matched_value.group(1).rstrip("/")
                if matched_value
                else None
            )
        elif name == "dir":
            value = (
                raw_value
                if re.fullmatch(
                    r"(?:NORTH|SOUTH|EAST|WEST|"
                    r"NORTHEAST|NORTHWEST|SOUTHEAST|SOUTHWEST|"
                    r"[1245689]|10)",
                    raw_value,
                )
                else None
            )
        elif re.fullmatch(r"[+-]?\d+(?:\.\d+)?", raw_value):
            value = raw_value
        if value is not None:
            result[name] = value
    return result


def _dm_static_appearance_index() -> dict[str, dict[str, dict[str, Any]]]:
    """Index literal initial appearance values without executing upstream DM."""

    assignment = re.compile(
        r"(icon|icon_state|dir|pixel_x|pixel_y|layer|parent_type)"
        r"\s*=\s*(.*?)\s*$"
    )
    absolute_type = re.compile(r"(/[-A-Za-z0-9_/]+)\s*$")
    relative_type = re.compile(r"([A-Za-z_][A-Za-z0-9_/]*)\s*$")
    ignored_relative = {
        "do",
        "else",
        "for",
        "if",
        "proc",
        "set",
        "spawn",
        "switch",
        "var",
        "verb",
        "while",
    }
    values: dict[str, dict[str, dict[str, Any]]] = defaultdict(dict)

    for source_file, text in _git_dm_sources():
        lines: list[tuple[int, int, str]] = []
        block_comment = False
        for line_number, raw_line in enumerate(text.splitlines(), 1):
            line = raw_line
            if block_comment:
                end = line.find("*/")
                if end < 0:
                    continue
                line = line[end + 2 :]
                block_comment = False
            while "/*" in line:
                start = line.find("/*")
                end = line.find("*/", start + 2)
                if end < 0:
                    line = line[:start]
                    block_comment = True
                    break
                line = line[:start] + line[end + 2 :]
            line = line.split("//", 1)[0].rstrip()
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            lines.append((line_number, _dm_indent(line), line.strip()))

        for line_number, subtype, body in _dm_define_floors_calls(lines):
            macro_values = _dm_macro_appearance_values(body)
            for root in (
                "/turf/simulated/floor",
                "/turf/unsimulated/floor",
                "/turf/simulated/floor/airless",
                "/turf/unsimulated/floor/airless",
            ):
                path = root + "/" + subtype
                for name, value in macro_values.items():
                    values[path][name] = {
                        "value": value,
                        "file": source_file,
                        "line": line_number,
                    }

        stack: list[tuple[int, str, str | None]] = []
        for line_index, (line_number, indent, code) in enumerate(lines):
            while stack and stack[-1][0] >= indent:
                stack.pop()
            next_indent = (
                lines[line_index + 1][1]
                if line_index + 1 < len(lines)
                else -1
            )
            opens_block = next_indent > indent

            absolute = absolute_type.fullmatch(code)
            if absolute and "(" not in code:
                path = absolute.group(1).rstrip("/")
                if not any(
                    segment in {"proc", "var", "verb"}
                    for segment in path.strip("/").split("/")
                ):
                    stack.append((indent, "type", path))
                    continue

            context = stack[-1] if stack else None
            if context and context[1] == "type" and indent == context[0] + 1:
                matched_assignment = assignment.fullmatch(code)
                if matched_assignment:
                    name, raw_value = matched_assignment.groups()
                    value: str | int | None = None
                    if name == "icon":
                        match_value = re.fullmatch(
                            r"'((?:assets/)?icons/[^']+\.dmi)'",
                            raw_value,
                        )
                        value = match_value.group(1) if match_value else None
                    elif name == "icon_state":
                        match_value = re.fullmatch(r'"([^"]*)"', raw_value)
                        value = match_value.group(1) if match_value else None
                    elif name == "parent_type":
                        match_value = re.fullmatch(
                            r"(/[-A-Za-z0-9_/]+)",
                            raw_value,
                        )
                        value = (
                            match_value.group(1).rstrip("/")
                            if match_value
                            else None
                        )
                    elif name == "dir":
                        value = (
                            raw_value
                            if re.fullmatch(
                                r"(?:NORTH|SOUTH|EAST|WEST|"
                                r"NORTHEAST|NORTHWEST|SOUTHEAST|SOUTHWEST|"
                                r"[1245689]|10)",
                                raw_value,
                            )
                            else None
                        )
                    elif re.fullmatch(r"[+-]?\d+(?:\.\d+)?", raw_value):
                        value = raw_value
                    if value is not None:
                        assert context[2] is not None
                        values[context[2]][name] = {
                            "value": value,
                            "file": source_file,
                            "line": line_number,
                        }
                    if opens_block:
                        stack.append((indent, "block", None))
                    continue

                relative = relative_type.fullmatch(code)
                if (
                    opens_block
                    and relative
                    and relative.group(1).lower() not in ignored_relative
                ):
                    assert context[2] is not None
                    subtype = relative.group(1).strip("/")
                    stack.append(
                        (
                            indent,
                            "type",
                            context[2] + "/" + subtype,
                        )
                    )
                    continue

            if opens_block:
                stack.append((indent, "block", None))
    return {
        path: dict(sorted(properties.items()))
        for path, properties in sorted(values.items())
    }


def _dm_resolve_static(
    index: dict[str, dict[str, dict[str, Any]]],
    path: str,
    property_name: str,
) -> dict[str, Any] | None:
    visited: set[str] = set()
    current = path
    while current and current not in visited:
        visited.add(current)
        properties = index.get(current, {})
        if property_name in properties:
            return properties[property_name]
        parent = properties.get("parent_type")
        if parent is not None:
            current = str(parent["value"])
        elif "/" in current[1:]:
            current = current.rsplit("/", 1)[0]
        else:
            current = ""
    return None


def _dm_direction(value: str) -> str | None:
    return {
        "1": "north",
        "2": "south",
        "4": "east",
        "5": "northeast",
        "6": "southeast",
        "8": "west",
        "9": "northwest",
        "10": "southwest",
        "NORTH": "north",
        "SOUTH": "south",
        "EAST": "east",
        "WEST": "west",
        "NORTHEAST": "northeast",
        "NORTHWEST": "northwest",
        "SOUTHEAST": "southeast",
        "SOUTHWEST": "southwest",
    }.get(value)


def _appearance_map_data(
    profile: dict[str, Any],
) -> tuple[Any, dict[str, Any], list[dict[str, int | str]]]:
    try:
        from tools import map_import
    except ModuleNotFoundError:
        import map_import  # type: ignore[no-redef]

    source_map = profile["source_map"]
    map_path = UPSTREAM / source_map["path"]
    map_bytes = map_path.read_bytes()
    parsed = map_import.parse_map(map_bytes, source_map["path"])
    crop_data = source_map["crop"]
    crop = (
        int(crop_data["min_x"]),
        int(crop_data["min_y"]),
        int(crop_data["max_x"]),
        int(crop_data["max_y"]),
    )
    z_level = int(crop_data["z"])
    cells, overlaps = map_import._cells(parsed)
    if overlaps:
        raise ValueError("appearance source map contains overlapping writes")
    selected = {
        coordinate: key
        for coordinate, key in cells.items()
        if coordinate[2] == z_level
        and crop[0] <= coordinate[0] <= crop[2]
        and crop[1] <= coordinate[1] <= crop[3]
    }
    appearances = map_import.collect_appearances(parsed, selected, crop)
    map_record = {
        "path": source_map["path"],
        "git_blob": git_blob_oid(map_path),
        "sha256": hashlib.sha256(map_bytes).hexdigest(),
        "crop": {
            "z": z_level,
            "min_x": crop[0],
            "min_y": crop[1],
            "max_x": crop[2],
            "max_y": crop[3],
        },
    }
    return parsed, map_record, appearances


def _compact_dm_appearance_sprites(
    atlas_path: Path,
    atlas: dict[str, Any],
    selected_sprites: dict[str, dict[str, Any]],
) -> tuple[dict[str, dict[str, Any]], list[dict[str, Any]], dict[str, Any]]:
    """Repack selected full-catalog frames into a small native atlas.

    The exhaustive atlas remains the canonical provenance catalog.  Each
    selected frame is cropped from its verified runtime page, packed without
    scaling or color conversion, and then referenced by rewritten copies of
    the original sprite records.
    """

    safe_clean(DM_APPEARANCE_ATLAS)
    source_rectangles: set[tuple[str, int, int, int, int, int]] = set()
    source_pages: set[tuple[str, int]] = set()
    frame_references = 0
    for identifier in sorted(selected_sprites):
        entry = selected_sprites[identifier]
        bundle = str(entry["bundle"])
        if bundle == DM_APPEARANCE_BUNDLE:
            raise SystemExit(
                f"full catalog unexpectedly uses compact bundle: {identifier}"
            )
        for direction in sorted(entry["directions"]):
            for frame in entry["directions"][direction]:
                rectangle = (
                    bundle,
                    int(frame["page"]),
                    int(frame["x"]),
                    int(frame["y"]),
                    int(frame["w"]),
                    int(frame["h"]),
                )
                source_rectangles.add(rectangle)
                source_pages.add((bundle, int(frame["page"])))
                frame_references += 1

    compact_page = AtlasPage(
        DM_APPEARANCE_BUNDLE,
        0,
        DM_APPEARANCE_ATLAS,
    )
    compact_page_records: list[dict[str, Any]] = []
    locations_by_source: dict[
        tuple[str, int, int, int, int, int],
        dict[str, int],
    ] = {}
    locations_by_digest: dict[tuple[int, int, str], dict[str, int]] = {}
    source_image: Image.Image | None = None
    current_source_page: tuple[str, int] | None = None

    try:
        for rectangle in sorted(source_rectangles):
            bundle, page_number, x, y, width, height = rectangle
            page_key = (bundle, page_number)
            if page_key != current_source_page:
                if source_image is not None:
                    source_image.close()
                pages = atlas["bundles"].get(bundle, {}).get("pages", [])
                if page_number < 0 or page_number >= len(pages):
                    raise SystemExit(
                        f"invalid source page {bundle}:{page_number}"
                    )
                source_record = pages[page_number]
                source_path = (
                    atlas_path.parent / bundle / source_record["file"]
                )
                if (
                    not source_path.exists()
                    or sha256_file(source_path) != source_record["sha256"]
                ):
                    raise SystemExit(
                        f"invalid DM appearance source page: {source_path}"
                    )
                source_image = Image.open(source_path).convert("RGBA")
                if source_image.size != (
                    int(source_record["width"]),
                    int(source_record["height"]),
                ):
                    raise SystemExit(
                        f"DM appearance source page size mismatch: "
                        f"{source_path}"
                    )
                current_source_page = page_key
            assert source_image is not None
            if (
                width <= 0
                or height <= 0
                or x < 0
                or y < 0
                or x + width > source_image.width
                or y + height > source_image.height
            ):
                raise SystemExit(
                    "DM appearance source frame is outside its page: "
                    f"{rectangle}"
                )

            source_frame = source_image.crop(
                (x, y, x + width, y + height)
            )
            pixel_digest = hashlib.sha256(source_frame.tobytes()).hexdigest()
            digest_key = (width, height, pixel_digest)
            location = locations_by_digest.get(digest_key)
            if location is None:
                placed = compact_page.place(source_frame)
                if placed is None:
                    saved = compact_page.save()
                    assert saved is not None
                    compact_page_records.append({
                        "bundle": DM_APPEARANCE_BUNDLE,
                        "page": compact_page.number,
                        "runtime_path": (
                            f"{DM_APPEARANCE_BUNDLE}/{saved['file']}"
                        ),
                        "width": saved["width"],
                        "height": saved["height"],
                        "sha256": saved["sha256"],
                    })
                    compact_page = AtlasPage(
                        DM_APPEARANCE_BUNDLE,
                        compact_page.number + 1,
                        DM_APPEARANCE_ATLAS,
                    )
                    placed = compact_page.place(source_frame)
                    assert placed is not None
                location = {
                    "page": compact_page.number,
                    "x": placed[0],
                    "y": placed[1],
                    "w": width,
                    "h": height,
                }
                locations_by_digest[digest_key] = location
            locations_by_source[rectangle] = location
            source_frame.close()
    finally:
        if source_image is not None:
            source_image.close()

    saved = compact_page.save()
    if saved is not None:
        compact_page_records.append({
            "bundle": DM_APPEARANCE_BUNDLE,
            "page": compact_page.number,
            "runtime_path": f"{DM_APPEARANCE_BUNDLE}/{saved['file']}",
            "width": saved["width"],
            "height": saved["height"],
            "sha256": saved["sha256"],
        })

    compact_sprites: dict[str, dict[str, Any]] = {}
    for identifier in sorted(selected_sprites):
        source_entry = selected_sprites[identifier]
        source_bundle = str(source_entry["bundle"])
        entry = json.loads(json.dumps(source_entry))
        entry["bundle"] = DM_APPEARANCE_BUNDLE
        for direction in sorted(entry["directions"]):
            source_frames = source_entry["directions"][direction]
            compact_frames = entry["directions"][direction]
            for source_frame, compact_frame in zip(
                source_frames,
                compact_frames,
                strict=True,
            ):
                rectangle = (
                    source_bundle,
                    int(source_frame["page"]),
                    int(source_frame["x"]),
                    int(source_frame["y"]),
                    int(source_frame["w"]),
                    int(source_frame["h"]),
                )
                compact_frame.update(locations_by_source[rectangle])
        compact_sprites[identifier] = entry

    summary = {
        "bundle": DM_APPEARANCE_BUNDLE,
        "page_size": PAGE_SIZE,
        "gutter": GUTTER,
        "source_pages": len(source_pages),
        "source_rectangles": len(source_rectangles),
        "frame_references": frame_references,
        "unique_frames": len(locations_by_digest),
    }
    return compact_sprites, compact_page_records, summary


def build_dm_appearances(_: argparse.Namespace) -> None:
    """Compile Atlas-referenced DM defaults into a startup-safe selection."""

    atlas_path = RUNTIME / "graphics" / "atlas.json"
    if not atlas_path.exists():
        raise SystemExit("run build-graphics first")
    if not DM_APPEARANCE_PROFILE.exists():
        raise SystemExit(f"missing {DM_APPEARANCE_PROFILE.relative_to(ROOT)}")
    profile = json.loads(DM_APPEARANCE_PROFILE.read_text(encoding="utf-8"))
    if (
        profile.get("format_version") != 1
        or profile.get("kind") != "goon-dm-appearance-profile"
        or profile.get("source_commit") != GOON_COMMIT
    ):
        raise SystemExit("invalid or stale DM appearance profile")

    atlas = json.loads(atlas_path.read_text(encoding="utf-8"))
    by_icon_state: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    by_icon: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for entry in atlas["sprites"].values():
        key = (entry["source_path"], entry["source_state"])
        by_icon_state[key].append(entry)
        by_icon[entry["source_path"]].append(entry)
    for entries in by_icon_state.values():
        entries.sort(
            key=lambda entry: (
                entry["source_state_occurrence"],
                entry["id"],
            )
        )
    for entries in by_icon.values():
        entries.sort(
            key=lambda entry: (
                entry["source_state"],
                entry["source_state_occurrence"],
                entry["id"],
            )
        )

    _, map_record, appearances = _appearance_map_data(profile)
    static_index = _dm_static_appearance_index()
    unique_paths = sorted(
        {(str(row["role"]), str(row["source_path"])) for row in appearances}
    )
    rules_by_key: dict[tuple[str, str], dict[str, Any]] = {}
    unresolved_reason: dict[tuple[str, str], str] = {}

    for source_rule in profile["explicit_rules"]:
        rule = json.loads(json.dumps(source_rule))
        rule.setdefault("match", "exact")
        for part in rule["parts"]:
            entries = by_icon_state.get(
                (part["source_icon"], part["source_state"]),
                [],
            )
            if not entries:
                raise SystemExit(
                    "explicit DM appearance sprite is missing: "
                    f"{part['source_icon']}:{part['source_state']}"
                )
            part["sprite_id"] = entries[0]["id"]
        rules_by_key[(rule["role"], rule["type_path"])] = rule

    connected_families = sorted(
        profile["connected_state_families"],
        key=lambda row: (-len(row["type_path"]), row["type_path"]),
    )
    dynamic_families = sorted(
        profile["dynamic_state_families"],
        key=lambda row: (-len(row["type_path"]), row["type_path"]),
    )

    for role, source_path in unique_paths:
        key = (role, source_path)
        if key in rules_by_key:
            continue
        icon = _dm_resolve_static(static_index, source_path, "icon")
        state = _dm_resolve_static(static_index, source_path, "icon_state")
        if icon is None or state is None:
            unresolved_reason[key] = "static DM icon/icon_state was not resolved"
            continue
        icon_value = str(icon["value"])
        state_value = str(state["value"])
        entries = by_icon_state.get((icon_value, state_value), [])
        if not entries:
            unresolved_reason[key] = (
                f"compiled atlas has no {icon_value}:{state_value}"
            )
            continue
        part: dict[str, Any] = {
            "sprite_id": entries[0]["id"],
            "source_icon": icon_value,
            "source_state": state_value,
            "direction_policy": "map",
        }
        direction = _dm_resolve_static(static_index, source_path, "dir")
        if direction is not None:
            fixed_direction = _dm_direction(str(direction["value"]))
            if fixed_direction:
                part["direction_policy"] = "fixed"
                part["fixed_direction"] = fixed_direction
        for offset_name in ("pixel_x", "pixel_y"):
            offset = _dm_resolve_static(
                static_index,
                source_path,
                offset_name,
            )
            if offset and re.fullmatch(r"[+-]?\d+", str(offset["value"])):
                part[offset_name] = int(str(offset["value"]))

        selectors = [
            row
            for row in [*connected_families, *dynamic_families]
            if _path_matches(
                source_path,
                row["type_path"],
                row["match"],
            )
        ]
        if selectors:
            patterns = sorted({str(row["state_regex"]) for row in selectors})
            part["include_state_regex"] = "|".join(
                f"(?:{pattern})" for pattern in patterns
            )
        connected = next(
            (
                row
                for row in connected_families
                if _path_matches(
                    source_path,
                    row["type_path"],
                    row["match"],
                )
            ),
            None,
        )
        if connected:
            fidelity = connected["fidelity"]
        elif "/random" in source_path:
            fidelity = "runtime-random-deferred"
        elif any(
            _path_matches(source_path, row["type_path"], row["match"])
            for row in dynamic_families
        ):
            fidelity = "runtime-state-deferred"
        else:
            fidelity = "exact-static"
        rules_by_key[key] = {
            "type_path": source_path,
            "match": "exact",
            "role": role,
            "parts": [part],
            "source": {
                "file": state["file"],
                "line": state["line"],
            },
            "fidelity": fidelity,
        }

    rules = sorted(
        rules_by_key.values(),
        key=lambda rule: (rule["role"], rule["type_path"], rule["match"]),
    )
    exact_rules = {
        (rule["role"], rule["type_path"]): rule
        for rule in rules
        if rule["match"] == "exact"
    }
    subtree_rules = sorted(
        (rule for rule in rules if rule["match"] == "subtree"),
        key=lambda rule: (
            -len(rule["type_path"]),
            rule["role"],
            rule["type_path"],
        ),
    )

    def find_rule(role: str, source_path: str) -> dict[str, Any] | None:
        exact = exact_rules.get((role, source_path))
        if exact:
            return exact
        return next(
            (
                rule
                for rule in subtree_rules
                if rule["role"] == role
                and _path_matches(source_path, rule["type_path"], "subtree")
            ),
            None,
        )

    selected_sprites: dict[str, dict[str, Any]] = {}

    def select_entry(entry: dict[str, Any]) -> None:
        selected_sprites[entry["id"]] = entry

    for rule in rules:
        for part in rule["parts"]:
            select_entry(atlas["sprites"][part["sprite_id"]])
            pattern = part.get("include_state_regex")
            if pattern:
                compiled_pattern = re.compile(pattern)
                for entry in by_icon[part["source_icon"]]:
                    if (
                        entry["source_state_occurrence"] == 1
                        and compiled_pattern.search(entry["source_state"])
                    ):
                        select_entry(entry)

    mapped_counts: Counter[tuple[str, str]] = Counter()
    fallback_counts: Counter[tuple[str, str, str]] = Counter()
    for appearance in appearances:
        role = str(appearance["role"])
        source_path = str(appearance["source_path"])
        rule = find_rule(role, source_path)
        if rule is None:
            fallback_counts[
                (
                    role,
                    source_path,
                    unresolved_reason.get(
                        (role, source_path),
                        "no reviewed appearance rule",
                    ),
                )
            ] += 1
            continue
        state = appearance.get(
            "resolved_icon_state",
            appearance.get("icon_state_override"),
        )
        failed = ""
        if state is not None:
            for part in rule["parts"]:
                icon_override = appearance.get("icon_override")
                icon = str(icon_override or part["source_icon"])
                entries = by_icon_state.get((icon, str(state)), [])
                if not entries:
                    failed = f"compiled atlas has no {icon}:{state}"
                    break
                select_entry(entries[0])
        if failed:
            fallback_counts[(role, source_path, failed)] += 1
        else:
            mapped_counts[(role, source_path)] += 1

    compact_sprites, pages, compact_atlas = (
        _compact_dm_appearance_sprites(
            atlas_path,
            atlas,
            selected_sprites,
        )
    )

    unresolved = [
        {
            "role": role,
            "source_path": source_path,
            "instances": instances,
            "reason": reason,
        }
        for (role, source_path, reason), instances in sorted(
            fallback_counts.items(),
            key=lambda item: (
                -item[1],
                item[0][0],
                item[0][1],
                item[0][2],
            ),
        )
    ]
    output = {
        "format_version": 1,
        "kind": "goon-dm-appearance-selection",
        "pack_id": atlas["pack_id"],
        "source_commit": atlas["source_commit"],
        "source_map": map_record,
        "profile_sha256": sha256_file(DM_APPEARANCE_PROFILE),
        "full_catalog_sha256": sha256_file(atlas_path),
        "compact_atlas": compact_atlas,
        "pages": pages,
        "sprites": compact_sprites,
        "rules": rules,
        "coverage": {
            "appearance_instances": len(appearances),
            "mapped_instances": sum(mapped_counts.values()),
            "mapped_source_paths": len(mapped_counts),
            "fallback_instances": sum(fallback_counts.values()),
            "fallback_source_paths": len(
                {(role, path) for role, path, _ in fallback_counts}
            ),
            "unresolved": unresolved,
        },
    }
    json_dump(DM_APPEARANCE_RUNTIME, output)
    print(
        "DM appearances complete: "
        f"{len(rules):,} rules, {len(selected_sprites):,} sprites, "
        f"{len(pages):,} compact pages "
        f"(from {compact_atlas['source_pages']:,} source pages), "
        f"{output['coverage']['mapped_instances']:,}/"
        f"{len(appearances):,} instances mapped"
    )


def _audit_dm_appearance_compact_atlas(
    atlas_path: Path,
    atlas: dict[str, Any],
    appearances: dict[str, Any],
) -> None:
    """Validate compact packing and compare every selected source frame."""

    compact = appearances.get("compact_atlas", {})
    expected_compact_fields = {
        "bundle",
        "page_size",
        "gutter",
        "source_pages",
        "source_rectangles",
        "frame_references",
        "unique_frames",
    }
    if (
        set(compact) != expected_compact_fields
        or compact.get("bundle") != DM_APPEARANCE_BUNDLE
        or compact.get("page_size") != PAGE_SIZE
        or compact.get("gutter") != GUTTER
    ):
        raise SystemExit("invalid DM appearance compact atlas metadata")

    declared_pages: dict[tuple[str, int], dict[str, Any]] = {}
    expected_paths: set[Path] = set()
    for expected_number, page in enumerate(appearances.get("pages", [])):
        if (
            set(page)
            != {
                "bundle",
                "page",
                "runtime_path",
                "width",
                "height",
                "sha256",
            }
            or page["bundle"] != DM_APPEARANCE_BUNDLE
            or int(page["page"]) != expected_number
            or page["runtime_path"]
            != f"{DM_APPEARANCE_BUNDLE}/atlas-{expected_number:03d}.png"
            or int(page["width"]) != PAGE_SIZE
            or int(page["height"]) != PAGE_SIZE
        ):
            raise SystemExit("DM appearance selection references sparse pages")
        page_path = atlas_path.parent / page["runtime_path"]
        if (
            not page_path.exists()
            or sha256_file(page_path) != page["sha256"]
        ):
            raise SystemExit(
                f"invalid DM appearance compact page: {page_path}"
            )
        with Image.open(page_path) as image:
            if image.mode != "RGBA" or image.size != (PAGE_SIZE, PAGE_SIZE):
                raise SystemExit(
                    f"invalid DM appearance compact page format: {page_path}"
                )
        key = (str(page["bundle"]), int(page["page"]))
        if key in declared_pages:
            raise SystemExit("duplicate DM appearance compact page")
        declared_pages[key] = page
        expected_paths.add(page_path.resolve())

    actual_paths = {
        path.resolve()
        for path in DM_APPEARANCE_ATLAS.glob("atlas-*.png")
        if path.is_file()
    }
    if actual_paths != expected_paths:
        raise SystemExit("DM appearance compact page set is stale")

    source_pages: set[tuple[str, int]] = set()
    source_rectangles: set[tuple[str, int, int, int, int, int]] = set()
    compact_locations: set[tuple[int, int, int, int, int]] = set()
    comparisons: set[
        tuple[
            str,
            int,
            int,
            int,
            int,
            int,
            int,
            int,
            int,
        ]
    ] = set()
    frame_references = 0

    for identifier, entry in sorted(
        appearances.get("sprites", {}).items()
    ):
        source_entry = atlas["sprites"].get(identifier)
        if source_entry is None:
            raise SystemExit(f"unknown DM appearance sprite: {identifier}")
        if entry.get("bundle") != DM_APPEARANCE_BUNDLE:
            raise SystemExit(
                f"DM appearance sprite references sparse bundle: {identifier}"
            )
        if set(entry) != set(source_entry):
            raise SystemExit(
                f"DM appearance sprite schema mismatch: {identifier}"
            )
        for field, value in source_entry.items():
            if field not in {"bundle", "directions"} and entry[field] != value:
                raise SystemExit(
                    f"DM appearance sprite provenance mismatch: "
                    f"{identifier}:{field}"
                )
        if set(entry["directions"]) != set(source_entry["directions"]):
            raise SystemExit(
                f"DM appearance direction mismatch: {identifier}"
            )

        source_bundle = str(source_entry["bundle"])
        for direction in sorted(source_entry["directions"]):
            source_frames = source_entry["directions"][direction]
            compact_frames = entry["directions"][direction]
            if len(source_frames) != len(compact_frames):
                raise SystemExit(
                    f"DM appearance frame count mismatch: "
                    f"{identifier}:{direction}"
                )
            for source_frame, compact_frame in zip(
                source_frames,
                compact_frames,
                strict=True,
            ):
                if set(source_frame) != set(compact_frame):
                    raise SystemExit(
                        f"DM appearance frame schema mismatch: "
                        f"{identifier}:{direction}"
                    )
                for field, value in source_frame.items():
                    if (
                        field not in {"page", "x", "y"}
                        and compact_frame[field] != value
                    ):
                        raise SystemExit(
                            f"DM appearance frame metadata mismatch: "
                            f"{identifier}:{direction}:{field}"
                        )
                compact_page = int(compact_frame["page"])
                compact_x = int(compact_frame["x"])
                compact_y = int(compact_frame["y"])
                width = int(compact_frame["w"])
                height = int(compact_frame["h"])
                if (
                    (DM_APPEARANCE_BUNDLE, compact_page)
                    not in declared_pages
                    or compact_x < GUTTER
                    or compact_y < GUTTER
                    or compact_x + width + GUTTER > PAGE_SIZE
                    or compact_y + height + GUTTER > PAGE_SIZE
                ):
                    raise SystemExit(
                        f"DM appearance frame is outside compact pages: "
                        f"{identifier}:{direction}"
                    )

                source_page = int(source_frame["page"])
                source_x = int(source_frame["x"])
                source_y = int(source_frame["y"])
                source_pages.add((source_bundle, source_page))
                source_rectangles.add(
                    (
                        source_bundle,
                        source_page,
                        source_x,
                        source_y,
                        width,
                        height,
                    )
                )
                compact_locations.add(
                    (
                        compact_page,
                        compact_x,
                        compact_y,
                        width,
                        height,
                    )
                )
                comparisons.add(
                    (
                        source_bundle,
                        source_page,
                        source_x,
                        source_y,
                        width,
                        height,
                        compact_page,
                        compact_x,
                        compact_y,
                    )
                )
                frame_references += 1

    if compact != {
        "bundle": DM_APPEARANCE_BUNDLE,
        "page_size": PAGE_SIZE,
        "gutter": GUTTER,
        "source_pages": len(source_pages),
        "source_rectangles": len(source_rectangles),
        "frame_references": frame_references,
        "unique_frames": len(compact_locations),
    }:
        raise SystemExit("DM appearance compact atlas totals are stale")

    compact_images = {
        int(page["page"]): Image.open(
            atlas_path.parent / page["runtime_path"]
        ).convert("RGBA")
        for page in appearances["pages"]
    }
    source_image: Image.Image | None = None
    current_source_page: tuple[str, int] | None = None
    try:
        for comparison in sorted(comparisons):
            (
                source_bundle,
                source_page,
                source_x,
                source_y,
                width,
                height,
                compact_page,
                compact_x,
                compact_y,
            ) = comparison
            page_key = (source_bundle, source_page)
            if page_key != current_source_page:
                if source_image is not None:
                    source_image.close()
                source_record = (
                    atlas["bundles"][source_bundle]["pages"][source_page]
                )
                source_image = Image.open(
                    atlas_path.parent
                    / source_bundle
                    / source_record["file"]
                ).convert("RGBA")
                current_source_page = page_key
            assert source_image is not None
            source_pixels = source_image.crop(
                (
                    source_x,
                    source_y,
                    source_x + width,
                    source_y + height,
                )
            )
            compact_pixels = compact_images[compact_page].crop(
                (
                    compact_x,
                    compact_y,
                    compact_x + width,
                    compact_y + height,
                )
            )
            try:
                if source_pixels.tobytes() != compact_pixels.tobytes():
                    raise SystemExit(
                        "DM appearance compact frame pixels differ from "
                        f"source: {comparison}"
                    )
            finally:
                source_pixels.close()
                compact_pixels.close()
    finally:
        if source_image is not None:
            source_image.close()
        for image in compact_images.values():
            image.close()


def audit(_: argparse.Namespace) -> None:
    upstream_inventory = UPSTREAM / "upstream-files.json"
    if not upstream_inventory.exists():
        raise SystemExit("missing upstream inventory; run fetch-goon")
    inventory = json.loads(upstream_inventory.read_text(encoding="utf-8"))
    for row in inventory["files"]:
        path = UPSTREAM / row["path"]
        if not path.exists():
            raise SystemExit(f"upstream file is missing: {row['path']}")
        if path.stat().st_size != row["size"] or git_blob_oid(path) != row["git_blob_oid"]:
            raise SystemExit(f"upstream blob mismatch: {row['path']}")
    print(f"upstream inventory ok: {len(inventory['files']):,} files")

    graphics_source_path = SOURCE / "graphics" / "graphics-source.json"
    if graphics_source_path.exists():
        graphics_source = json.loads(
            graphics_source_path.read_text(encoding="utf-8")
        )
        if graphics_source["errors"]:
            raise SystemExit("graphics source inventory contains import errors")
        for row in graphics_source["files"]:
            relative = Path(row["path"])
            upstream_path = UPSTREAM / relative
            if sha256_file(upstream_path) != row["sha256"]:
                raise SystemExit(f"graphics source hash mismatch: {relative}")
            if relative.suffix.lower() == ".dmi":
                fork_path = (
                    SOURCE
                    / "graphics"
                    / relative.with_suffix(".dmi.png")
                )
                metadata_path = (
                    SOURCE
                    / "graphics"
                    / relative.with_suffix(".dmi.toml")
                )
                if (
                    not fork_path.exists()
                    or not metadata_path.exists()
                    or sha256_file(fork_path) != row["sha256"]
                ):
                    raise SystemExit(f"invalid editable DMI fork: {relative}")
            else:
                fork_path = SOURCE / "graphics" / relative
                if not fork_path.exists() or sha256_file(fork_path) != row["sha256"]:
                    raise SystemExit(f"invalid graphics fork: {relative}")
        print(
            "graphics source fork ok: "
            f"{len(graphics_source['files']):,} files"
        )

    atlas_path = RUNTIME / "graphics" / "atlas.json"
    if atlas_path.exists():
        atlas = json.loads(atlas_path.read_text(encoding="utf-8"))
        for bundle, record in atlas["bundles"].items():
            for page in record["pages"]:
                path = atlas_path.parent / bundle / page["file"]
                if not path.exists() or sha256_file(path) != page["sha256"]:
                    raise SystemExit(f"invalid atlas page: {path}")
        print(f"graphics catalog ok: {len(atlas['sprites']):,} sprites")
        foundation_path = atlas_path.parent / "foundation.json"
        if foundation_path.exists():
            foundation = json.loads(foundation_path.read_text(encoding="utf-8"))
            if foundation["full_catalog_sha256"] != sha256_file(atlas_path):
                raise SystemExit("foundation graphics selection is stale")
            if set(foundation["sprites"]) != set(FOUNDATION_SPRITES):
                raise SystemExit("foundation graphics alias set is stale")
            for alias, identifier in sorted(FOUNDATION_SPRITES.items()):
                entry = foundation["sprites"][alias]
                if entry["id"] != identifier:
                    raise SystemExit(
                        f"foundation graphics alias mismatch: {alias}"
                    )
                if (
                    entry.get("cell_width") != FOUNDATION_CELL_SIZE
                    or entry.get("cell_height") != FOUNDATION_CELL_SIZE
                    or any(
                        frame.get("w") != FOUNDATION_CELL_SIZE
                        or frame.get("h") != FOUNDATION_CELL_SIZE
                        for frames in entry.get("directions", {}).values()
                        for frame in frames
                    )
                ):
                    raise SystemExit(
                        f"foundation sprite is not "
                        f"{FOUNDATION_CELL_SIZE}x{FOUNDATION_CELL_SIZE}: "
                        f"{alias}"
                    )
            for page in foundation["pages"]:
                path = atlas_path.parent / page["runtime_path"]
                if not path.exists() or sha256_file(path) != page["sha256"]:
                    raise SystemExit(f"invalid foundation atlas page: {path}")
            print(
                "foundation graphics ok: "
                f"{len(foundation['sprites']):,} sprites, "
                f"{len(foundation['pages']):,} pages"
            )
        if DM_APPEARANCE_RUNTIME.exists():
            appearances = json.loads(
                DM_APPEARANCE_RUNTIME.read_text(encoding="utf-8")
            )
            if (
                appearances.get("kind") != "goon-dm-appearance-selection"
                or appearances.get("source_commit") != GOON_COMMIT
                or appearances.get("full_catalog_sha256")
                != sha256_file(atlas_path)
                or appearances.get("profile_sha256")
                != sha256_file(DM_APPEARANCE_PROFILE)
            ):
                raise SystemExit("DM appearance selection is stale")
            selected_ids = set(appearances.get("sprites", {}))
            for rule in appearances.get("rules", []):
                for part in rule.get("parts", []):
                    if part.get("sprite_id") not in selected_ids:
                        raise SystemExit(
                            "DM appearance rule references an unselected sprite"
                        )
            _audit_dm_appearance_compact_atlas(
                atlas_path,
                atlas,
                appearances,
            )
            coverage = appearances.get("coverage", {})
            if coverage.get("appearance_instances") != (
                coverage.get("mapped_instances", 0)
                + coverage.get("fallback_instances", 0)
            ):
                raise SystemExit("invalid DM appearance coverage totals")

            profile = json.loads(
                DM_APPEARANCE_PROFILE.read_text(encoding="utf-8")
            )
            _, _, map_appearances = _appearance_map_data(profile)
            appearance_counts = Counter(
                (
                    str(row["role"]),
                    str(row["source_path"]),
                )
                for row in map_appearances
            )
            rules_by_key = {
                (str(rule["role"]), str(rule["type_path"])): rule
                for rule in appearances["rules"]
                if rule.get("match") == "exact"
            }
            macro_floor_expectations = {
                "/turf/simulated/floor/twotone/black": (
                    34,
                    "twotone_black",
                ),
                "/turf/simulated/floor/twotone/darkblue": (
                    18,
                    "twotone_dblue",
                ),
            }
            for path, (instances, source_state) in (
                macro_floor_expectations.items()
            ):
                rule = rules_by_key.get(("turf", path))
                if (
                    appearance_counts[("turf", path)] != instances
                    or rule is None
                    or len(rule.get("parts", [])) != 1
                    or rule["parts"][0].get("source_state") != source_state
                ):
                    raise SystemExit(
                        f"invalid DEFINE_FLOORS appearance mapping: {path}"
                    )
            print(
                "DM appearances ok: "
                f"{len(appearances['rules']):,} rules, "
                f"{len(appearances['sprites']):,} sprites, "
                f"{len(appearances['pages']):,} compact pages"
            )

    audio_path = RUNTIME / "audio" / "audio.json"
    if audio_path.exists():
        audio = json.loads(audio_path.read_text(encoding="utf-8"))
        for identifier, entry in audio["entries"].items():
            path = audio_path.parent / entry["runtime_path"]
            if not path.exists() or sha256_file(path) != entry["runtime_sha256"]:
                raise SystemExit(f"invalid audio entry: {identifier}")
        print(f"audio catalog ok: {len(audio['entries']):,} files")
        foundation_path = audio_path.parent / "foundation.json"
        if foundation_path.exists():
            foundation = json.loads(foundation_path.read_text(encoding="utf-8"))
            if foundation["full_catalog_sha256"] != sha256_file(audio_path):
                raise SystemExit("foundation audio selection is stale")
            print(
                f"foundation audio ok: {len(foundation['entries']):,} sounds"
            )


def all_assets(args: argparse.Namespace) -> None:
    fetch_goon(args)
    import_graphics_source(args)
    build_graphics(args)
    build_audio(args)
    build_foundation_media(args)
    audit(args)


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    subparsers = result.add_subparsers(dest="command", required=True)
    commands = {
        "fetch-goon": fetch_goon,
        "import-graphics-source": import_graphics_source,
        "build-graphics": build_graphics,
        "build-audio": build_audio,
        "build-dm-appearances": build_dm_appearances,
        "build-foundation-media": build_foundation_media,
        "verify-graphics": verify_graphics,
        "verify-audio": verify_audio,
        "audit": audit,
        "all": all_assets,
    }
    for name, callback in commands.items():
        child = subparsers.add_parser(name)
        child.set_defaults(callback=callback)
    return result


def main() -> None:
    args = parser().parse_args()
    args.callback(args)


if __name__ == "__main__":
    main()
