#!/usr/bin/env python3
"""Fixture tests for the read-only DMM/TGM analyzer."""

from __future__ import annotations

from collections import Counter
import copy
import hashlib
import json
from pathlib import Path
import unittest

from tools import map_import, mods as mod_tools

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests" / "fixtures" / "maps"
VISUAL_ROOM_FIXTURE = ROOT / "tests" / "fixtures" / "visual-room.json"
FOUNDATION_GRAPHICS = (
    ROOT / "assets" / "runtime" / "goon" / "graphics" / "foundation.json"
)
LFS_POINTER_PREFIX = b"version https://git-lfs.github.com/spec/v1"
EXPECTED_STATIC_ROOM_ALIASES = {
    "catwalk",
    "chair",
    "crate",
    "decal",
    "disposal",
    "door_closed",
    "door_open",
    "floor",
    "grille",
    "lattice",
    "light",
    "pipe",
    "plating",
    "reinforced_floor",
    "reinforced_wall",
    "sign",
    "storage",
    "table",
    "wall",
    "window",
}


def _decoded_scenario_cells(scenario: dict) -> dict[tuple[int, int], dict]:
    native_map = scenario["map"]
    width = native_map["width"]
    height = native_map["height"]
    palette = native_map["palette"]
    cells = [
        palette[native_map["default_palette"] - 1]
        for _ in range(width * height)
    ]
    for start, length, palette_index in native_map["runs"]:
        cells[start - 1 : start - 1 + length] = [
            palette[palette_index - 1]
        ] * length
    return {
        (x, y): cells[(y - 1) * width + x - 1]
        for y in range(1, height + 1)
        for x in range(1, width + 1)
    }


def _classification_tokens(record: dict) -> set[str]:
    """Read classification fields without coupling tests to provenance layout."""

    result: set[str] = set()

    def visit(key: str, value: object) -> None:
        normalized_key = key.lower().replace("_", "-")
        classification_key = (
            "class" in normalized_key
            or normalized_key.endswith("-kind")
            or normalized_key in {
                "features",
                "native-features",
                "source-features",
            }
        )
        if classification_key and isinstance(value, str):
            result.add(value.lower().replace("_", "-"))
        elif classification_key and isinstance(value, list):
            for child in value:
                if isinstance(child, str):
                    result.add(child.lower().replace("_", "-"))
                elif isinstance(child, dict):
                    for child_key, child_value in child.items():
                        visit(str(child_key), child_value)
        elif isinstance(value, dict):
            for child_key, child_value in value.items():
                visit(str(child_key), child_value)

    for record_key, record_value in record.items():
        visit(str(record_key), record_value)
    return result


class MapImportTests(unittest.TestCase):
    def parse_fixture(self, name: str) -> map_import.ParsedMap:
        path = FIXTURES / name
        return map_import.parse_map(
            path.read_bytes(),
            path.relative_to(ROOT).as_posix(),
        )

    def test_visual_room_pins_native_alias_states_and_directions(self) -> None:
        fixture = json.loads(VISUAL_ROOM_FIXTURE.read_text(encoding="utf-8"))
        foundation = json.loads(FOUNDATION_GRAPHICS.read_text(encoding="utf-8"))
        expected_aliases = fixture["aliases"]

        self.assertEqual(fixture["schema_version"], 1)
        self.assertEqual(foundation["format_version"], 1)
        self.assertEqual(
            foundation["kind"],
            "foundation-graphics-selection",
        )
        self.assertEqual(foundation["source_commit"], fixture["source_commit"])
        self.assertEqual(
            len(foundation["sprites"]),
            fixture["catalog"]["sprite_aliases"],
        )
        self.assertEqual(
            len(foundation["pages"]),
            fixture["catalog"]["referenced_pages"],
        )
        self.assertEqual(set(expected_aliases), EXPECTED_STATIC_ROOM_ALIASES)
        self.assertEqual(
            set(fixture["room"]["expected_drawn_aliases"]) - {"cable"},
            EXPECTED_STATIC_ROOM_ALIASES,
        )

        sprite_ids: set[str] = set()
        for alias in sorted(expected_aliases):
            with self.subTest(alias=alias):
                expected = expected_aliases[alias]
                entry = foundation["sprites"][alias]
                self.assertEqual(entry["id"], expected["id"])
                self.assertNotIn(entry["id"], sprite_ids)
                sprite_ids.add(entry["id"])
                self.assertEqual(entry["source_path"], expected["source_path"])
                self.assertEqual(
                    entry["source_state"],
                    expected["source_state"],
                )
                self.assertEqual(
                    entry["source_state_occurrence"],
                    expected["source_state_occurrence"],
                )
                self.assertEqual(
                    entry["cell_width"],
                    fixture["catalog"]["cell_size"],
                )
                self.assertEqual(
                    entry["cell_height"],
                    fixture["catalog"]["cell_size"],
                )
                self.assertEqual(
                    entry["dirs"],
                    len(expected["directions"]),
                )
                self.assertEqual(
                    set(entry["directions"]),
                    set(expected["directions"]),
                )
                self.assertEqual(
                    len(expected["directions"]),
                    len(set(expected["directions"])),
                )
                self.assertRegex(expected["pixel_sha256"], r"^[0-9a-f]{64}$")
                for direction in expected["directions"]:
                    frames = entry["directions"][direction]
                    self.assertEqual(len(frames), entry["frames"])
                    for frame in frames:
                        self.assertEqual(frame["w"], entry["cell_width"])
                        self.assertEqual(frame["h"], entry["cell_height"])

    def test_hydrated_visual_room_pixels_match_upstream_dmis(self) -> None:
        try:
            from PIL import Image
            from tools import assets as asset_tools
        except ImportError as error:
            self.skipTest(f"Pillow is required for hydrated pixel checks: {error}")

        fixture = json.loads(VISUAL_ROOM_FIXTURE.read_text(encoding="utf-8"))
        foundation = json.loads(FOUNDATION_GRAPHICS.read_text(encoding="utf-8"))
        page_records = {
            (page["bundle"], page["page"]): page
            for page in foundation["pages"]
        }
        upstream_root = ROOT / "assets" / "upstream" / "goon"
        runtime_root = ROOT / "assets" / "runtime" / "goon" / "graphics"

        required_paths: set[Path] = set()
        for alias, expected in fixture["aliases"].items():
            entry = foundation["sprites"][alias]
            required_paths.add(upstream_root / expected["source_path"])
            for direction in expected["directions"]:
                for frame in entry["directions"][direction]:
                    page = page_records[(entry["bundle"], frame["page"])]
                    required_paths.add(runtime_root / page["runtime_path"])

        for path in sorted(required_paths):
            self.assertTrue(path.is_file(), f"missing visual source: {path}")
        lfs_pointers = [
            path
            for path in sorted(required_paths)
            if path.read_bytes().startswith(LFS_POINTER_PREFIX)
        ]
        if lfs_pointers:
            self.skipTest(
                "visual pixel payloads are Git LFS pointers; hydrate assets "
                "before running pixel-level regression checks"
            )

        source_cache: dict[Path, tuple[Image.Image, object]] = {}
        page_cache: dict[tuple[str, int], Image.Image] = {}
        try:
            for alias in sorted(fixture["aliases"]):
                with self.subTest(alias=alias):
                    expected = fixture["aliases"][alias]
                    entry = foundation["sprites"][alias]
                    source_path = upstream_root / expected["source_path"]
                    if source_path not in source_cache:
                        source_cache[source_path] = asset_tools.read_dmi(
                            source_path
                        )
                    source_image, metadata = source_cache[source_path]
                    self.assertEqual(
                        hashlib.sha256(source_path.read_bytes()).hexdigest(),
                        entry["source_sha256"],
                    )
                    self.assertEqual(metadata.width, entry["cell_width"])
                    self.assertEqual(metadata.height, entry["cell_height"])

                    occurrence = 0
                    source_state = None
                    source_state_index = None
                    source_cell_offset = 0
                    for state_index, state in enumerate(metadata.states, 1):
                        if state.name == expected["source_state"]:
                            occurrence += 1
                            if occurrence == expected["source_state_occurrence"]:
                                source_state = state
                                source_state_index = state_index
                                break
                        source_cell_offset += state.dirs * state.frames
                    self.assertIsNotNone(source_state)
                    assert source_state is not None
                    self.assertEqual(
                        source_state_index,
                        entry["source_state_index"],
                    )
                    self.assertEqual(source_state.dirs, entry["dirs"])
                    self.assertEqual(source_state.frames, entry["frames"])
                    self.assertEqual(
                        asset_tools.DIRECTIONS[: source_state.dirs],
                        expected["directions"],
                    )

                    columns = source_image.width // metadata.width
                    for direction_index, direction in enumerate(
                        expected["directions"]
                    ):
                        source_cell = source_cell_offset + direction_index
                        source_left = (source_cell % columns) * metadata.width
                        source_top = (source_cell // columns) * metadata.height
                        source_frame = source_image.crop(
                            (
                                source_left,
                                source_top,
                                source_left + metadata.width,
                                source_top + metadata.height,
                            )
                        )
                        frame = entry["directions"][direction][0]
                        page_key = (entry["bundle"], frame["page"])
                        if page_key not in page_cache:
                            page = page_records[page_key]
                            with Image.open(
                                runtime_root / page["runtime_path"]
                            ) as packed:
                                page_cache[page_key] = packed.convert("RGBA")
                        atlas_frame = page_cache[page_key].crop(
                            (
                                frame["x"],
                                frame["y"],
                                frame["x"] + frame["w"],
                                frame["y"] + frame["h"],
                            )
                        )
                        try:
                            self.assertEqual(
                                atlas_frame.tobytes(),
                                source_frame.tobytes(),
                                f"{alias}/{direction} differs from its DMI cell",
                            )
                            if direction == "south":
                                self.assertEqual(
                                    hashlib.sha256(
                                        atlas_frame.tobytes()
                                    ).hexdigest(),
                                    expected["pixel_sha256"],
                                )
                        finally:
                            source_frame.close()
                            atlas_frame.close()
        finally:
            for source_image, _ in source_cache.values():
                source_image.close()
            for page_image in page_cache.values():
                page_image.close()

    def test_tgm_dictionary_coordinates_and_overrides(self) -> None:
        parsed = self.parse_fixture("tgm_minimal.dmm")

        self.assertEqual(parsed.format, "tgm")
        self.assertEqual(parsed.key_width, 2)
        self.assertEqual(len(parsed.entries), 3)
        self.assertEqual(len(parsed.blocks), 2)
        self.assertEqual(parsed.blocks[0].origin, (10, 20, 1))
        self.assertEqual(parsed.blocks[0].rows, (("aa",), ("bb",)))
        cells, overlaps = map_import._cells(parsed)
        self.assertEqual(overlaps, 0)
        self.assertEqual(cells[(10, 21, 1)], "aa")
        self.assertEqual(cells[(10, 20, 1)], "bb")
        door = parsed.entries["aa"].atoms[0]
        self.assertEqual(door.path, "/obj/machinery/door")
        self.assertEqual(door.variables, ("dir", "id", "links"))
        self.assertEqual(
            dict(door.literal_overrides),
            {"dir": 4, "id": "engineering"},
        )

    def test_literal_overrides_preserve_only_safe_data_primitives(self) -> None:
        parsed = map_import.parse_map(
            (
                b'"a" = ('
                b'/obj/machinery/power/smes{'
                b'charge = 1e6; '
                b'chargelevel = 15000; '
                b'output = 10000; '
                b'on = TRUE; '
                b'label = "engineering"; '
                b'precise = 9007199254740991e0; '
                b'huge = 1e999; '
                b'fraction = 1.5; '
                b'expression = 2 + 2; '
                b'type_value = /obj/item/cell; '
                b'nested = list("value" = 1)'
                b'},'
                b'/turf/simulated/floor,'
                b'/area/station/engineering'
                b')\n'
                b'(1,1,1) = {"a"}\n'
            ),
            "literal-overrides.dmm",
        )
        smes = parsed.entries["a"].atoms[0]

        self.assertEqual(
            dict(smes.literal_overrides),
            {
                "charge": 1_000_000,
                "chargelevel": 15_000,
                "label": "engineering",
                "on": True,
                "output": 10_000,
                "precise": 9_007_199_254_740_991,
            },
        )
        self.assertEqual(
            smes.variables,
            (
                "charge",
                "chargelevel",
                "expression",
                "fraction",
                "huge",
                "label",
                "nested",
                "on",
                "output",
                "precise",
                "type_value",
            ),
        )

    def test_tgm_summary_and_relationships(self) -> None:
        parsed = self.parse_fixture("tgm_minimal.dmm")
        summary = map_import.summarize_map(parsed)
        analysis = map_import.analyze_map(parsed, top=10)

        self.assertEqual(summary["mapped_cells"], 4)
        self.assertEqual(
            summary["bounds"],
            [
                {
                    "z": 1,
                    "min_x": 10,
                    "min_y": 20,
                    "max_x": 11,
                    "max_y": 21,
                    "width": 2,
                    "height": 2,
                    "mapped_cells": 4,
                }
            ],
        )
        self.assertEqual(summary["selection_signals"]["station_area_cells"], 3)
        self.assertEqual(summary["selection_signals"]["machinery_instances"], 2)
        self.assertEqual(summary["selection_signals"]["object_instances"], 3)
        self.assertTrue(summary["validation"]["ok"])
        self.assertEqual(
            analysis["station_departments"],
            [
                {"name": "engineering", "cells": 2},
                {"name": "medical", "cells": 1},
            ],
        )
        self.assertEqual(analysis["area_adjacencies"]["total"], 3)

    def test_conventional_dmm_rows_and_z_levels(self) -> None:
        parsed = self.parse_fixture("dmm_minimal.dmm")
        summary = map_import.summarize_map(parsed)

        self.assertEqual(parsed.format, "dmm")
        self.assertEqual(parsed.blocks[0].rows, (("A", "B"), ("B", "A")))
        self.assertEqual(summary["mapped_cells"], 5)
        self.assertEqual(summary["z_levels"], [1, 2])
        self.assertEqual(summary["selection_signals"]["station_area_cells"], 3)
        self.assertTrue(summary["validation"]["ok"])

    def test_unknown_grid_key_is_reported_deterministically(self) -> None:
        parsed = map_import.parse_map(
            b'"a" = (/turf/space,/area/space)\n(1,1,1) = {"b"}\n',
            "unknown.dmm",
        )
        first = map_import.summarize_map(parsed)
        second = map_import.summarize_map(parsed)

        self.assertFalse(first["validation"]["ok"])
        self.assertEqual(
            first["validation"]["issues"]["unknown_grid_keys"],
            ["b"],
        )
        self.assertEqual(
            json.dumps(first, sort_keys=True),
            json.dumps(second, sort_keys=True),
        )

    def test_rejects_inconsistent_key_widths(self) -> None:
        with self.assertRaisesRegex(map_import.MapError, "one non-zero width"):
            map_import.parse_map(
                (
                    b'"a" = (/turf/space,/area/space)\n'
                    b'"bb" = (/turf/space,/area/space)\n'
                    b'(1,1,1) = {"a"}\n'
                ),
                "bad-width.dmm",
            )

    def test_rejects_ragged_coordinate_block(self) -> None:
        with self.assertRaisesRegex(map_import.MapError, "ragged grid block"):
            map_import.parse_map(
                (b'"a" = (/turf/space,/area/space)\n' b'(1,1,1) = {"\\naa\\na\\n"}\n'),
                "ragged.dmm",
            )

    def test_native_scenario_compilation_is_bounded_and_flips_y(self) -> None:
        parsed = self.parse_fixture("tgm_minimal.dmm")
        document = map_import.compile_scenario(
            parsed,
            {
                "commit": "1" * 40,
                "path": "maps/test.dmm",
                "git_blob": "2" * 40,
                "sha256": "3" * 64,
            },
            scenario_id="org.example.test:scenario/native-map",
            name="Native Map",
            crop=(1, 10, 16, 25),
        )
        scenario = document["definitions"][0]
        self.assertEqual(scenario["map"]["width"], 16)
        self.assertEqual(scenario["map"]["height"], 16)
        self.assertEqual(
            [area["department"] for area in scenario["areas"]],
            ["engineering", "medical"],
        )
        self.assertEqual(
            scenario["provenance"]["crop"]["native_y_axis"],
            "down; source Y flipped",
        )

        palette = scenario["map"]["palette"]
        cells = [palette[scenario["map"]["default_palette"] - 1]] * (16 * 16)
        for start, length, palette_index in scenario["map"]["runs"]:
            cells[start - 1 : start - 1 + length] = [
                palette[palette_index - 1]
            ] * length
        # Source (10, 21) becomes native (10, 5) and contains an engineering
        # door; source (10, 20) becomes native (10, 6), proving the Y flip.
        upper = cells[(5 - 1) * 16 + 10 - 1]
        lower = cells[(6 - 1) * 16 + 10 - 1]
        self.assertEqual(upper["structure"], "door_closed")
        self.assertEqual(upper["access"], "engineering")
        self.assertEqual(lower["tile"], "floor")
        self.assertEqual(lower["structure"], "empty")

    def test_native_import_preserves_representative_turf_and_object_classes(
        self,
    ) -> None:
        entries = {
            "a": ("/turf/simulated/floor", None),
            "b": ("/turf/simulated/floor/plating", None),
            "c": ("/turf/simulated/wall/auto/supernorn", None),
            "d": (
                "/turf/simulated/wall/auto/reinforced/supernorn",
                None,
            ),
            "e": (
                "/turf/simulated/floor",
                "/obj/mapping_helper/wingrille_spawn/auto/reinforced",
            ),
            "f": ("/turf/simulated/floor", "/obj/mesh/grille/steel"),
            "g": ("/turf/simulated/floor", "/obj/table/reinforced"),
            "h": ("/turf/simulated/floor", "/obj/stool/chair"),
            "i": ("/turf/simulated/floor", "/obj/machinery/light"),
            "j": ("/turf/simulated/floor", "/obj/storage/closet"),
            "k": ("/turf/simulated/floor", "/obj/storage/crate"),
            "l": (
                "/turf/simulated/floor",
                "/obj/machinery/door/airlock/pyro/security",
            ),
            "m": ("/turf/simulated/floor", "/obj/window/reinforced"),
        }
        dictionary = []
        for key, (turf, object_path) in entries.items():
            atoms = ([object_path] if object_path else []) + [
                turf,
                "/area/station/engineering",
            ]
            dictionary.append(
                f'"{key}" = ({",".join(atoms)})\n'.encode()
            )
        parsed = map_import.parse_map(
            b"".join(dictionary)
            + b'(1,1,1) = {"abcdefghijklm"}\n',
            "representative-native-classes.dmm",
        )
        document = map_import.compile_scenario(
            parsed,
            {
                "commit": "1" * 40,
                "path": "maps/representative-native-classes.dmm",
                "git_blob": "2" * 40,
                "sha256": "3" * 64,
            },
            scenario_id="org.example.test:scenario/native-classes",
            name="Native Classes",
            crop=(1, 1, 16, 16),
        )
        scenario = document["definitions"][0]
        cells = _decoded_scenario_cells(scenario)

        expected = {
            1: {"floor"},
            2: {"plating"},
            3: {"wall"},
            4: {"reinforced-wall"},
            5: {"grille", "window"},
            6: {"grille"},
            7: {"table"},
            8: {"chair"},
            9: {"light"},
            10: {"storage"},
            11: {"crate"},
            13: {"window"},
        }
        for x, wanted in expected.items():
            tokens = _classification_tokens(cells[(x, 16)])
            if "reinforced-wall" in wanted:
                self.assertTrue(
                    {"reinforced", "reinforced-wall", "rwall"} & tokens,
                    f"cell {x} did not preserve reinforced-wall: {tokens}",
                )
            elif "wall" in wanted:
                self.assertTrue(
                    {"standard", "wall"} & tokens,
                    f"cell {x} did not preserve wall: {tokens}",
                )
            else:
                self.assertTrue(
                    wanted <= tokens,
                    f"cell {x} lost native classes {wanted}: {tokens}",
                )

        for x in (*range(5, 12), 13):
            features = cells[(x, 16)].get(
                "features",
                cells[(x, 16)].get("native_features", []),
            )
            self.assertIsInstance(features, list)
            self.assertEqual(
                features,
                sorted(set(features)),
                f"cell {x} features must be sorted and unique",
            )

        for x, (turf, object_path) in enumerate(entries.values(), start=1):
            cell = cells[(x, 16)]
            source_turfs = cell.get("source_turfs", [])
            source_objects = cell.get("source_objects", [])
            self.assertEqual(source_turfs, sorted(set(source_turfs)))
            self.assertEqual(source_objects, sorted(set(source_objects)))
            self.assertIn(turf, source_turfs)
            if object_path:
                self.assertIn(object_path, source_objects)

        airlock = cells[(12, 16)]
        self.assertEqual(airlock["structure"], "door_closed")
        self.assertIn(
            "/obj/machinery/door/airlock/pyro/security",
            airlock.get("source_objects", []),
        )

    def test_native_object_classification_respects_dm_type_boundaries(self) -> None:
        entries = {
            "a": "/obj/machinery/door/unpowered/wood",
            "b": "/obj/machinery/door_control",
            "c": "/obj/window_blinds/cog2",
            "d": "/obj/grille/legacy",
            "e": "/obj/mesh/grille/steel",
            "f": "/obj/mapping_helper/wingrille_spawn/auto/reinforced",
        }
        dictionary = [
            (
                f'"{key}" = ({object_path},/turf/simulated/floor,'
                "/area/station/engineering)\n"
            ).encode()
            for key, object_path in entries.items()
        ]
        parsed = map_import.parse_map(
            b"".join(dictionary) + b'(1,1,1) = {"abcdef"}\n',
            "native-type-boundaries.dmm",
        )
        scenario = map_import.compile_scenario(
            parsed,
            {
                "commit": "1" * 40,
                "path": "maps/native-type-boundaries.dmm",
                "git_blob": "2" * 40,
                "sha256": "3" * 64,
            },
            scenario_id="org.example.test:scenario/native-boundaries",
            name="Native Boundaries",
            crop=(1, 1, 16, 16),
        )["definitions"][0]
        cells = _decoded_scenario_cells(scenario)

        self.assertEqual(cells[(1, 16)]["structure"], "door_closed")
        self.assertEqual(cells[(2, 16)]["structure"], "empty")
        self.assertEqual(cells[(3, 16)]["structure"], "empty")
        self.assertNotIn("window", cells[(3, 16)].get("features", []))
        for x in (4, 5):
            self.assertEqual(cells[(x, 16)]["structure"], "empty")
            self.assertEqual(cells[(x, 16)]["features"], ["grille"])
        self.assertEqual(cells[(6, 16)]["structure"], "wall")
        self.assertEqual(cells[(6, 16)]["features"], ["grille", "window"])

    def test_scenario_validator_enforces_native_palette_metadata(self) -> None:
        parsed = map_import.parse_map(
            (
                b'"a" = ('
                b'/obj/table,'
                b'/turf/simulated/floor,'
                b'/area/station/engineering'
                b')\n'
                b'(1,1,1) = {"a"}\n'
            ),
            "native-palette-validation.dmm",
        )
        scenario = map_import.compile_scenario(
            parsed,
            {
                "commit": "1" * 40,
                "path": "maps/native-palette-validation.dmm",
                "git_blob": "2" * 40,
                "sha256": "3" * 64,
            },
            scenario_id="org.example.test:scenario/native-palette",
            name="Native Palette",
            crop=(1, 1, 16, 16),
        )["definitions"][0]
        mod_tools.validate_scenario(scenario, "scenario.json", 0)
        table_cell = next(
            cell
            for cell in scenario["map"]["palette"]
            if cell.get("features") == ["table"]
        )

        invalid = copy.deepcopy(scenario)
        invalid["map"]["palette"][
            scenario["map"]["palette"].index(table_cell)
        ]["features"] = ["table", "grille"]
        with self.assertRaisesRegex(mod_tools.ModError, "sorted and unique"):
            mod_tools.validate_scenario(invalid, "scenario.json", 0)

        invalid = copy.deepcopy(scenario)
        invalid_cell = invalid["map"]["palette"][
            scenario["map"]["palette"].index(table_cell)
        ]
        invalid_cell["source_turfs"] *= 2
        with self.assertRaisesRegex(mod_tools.ModError, "source_turfs"):
            mod_tools.validate_scenario(invalid, "scenario.json", 0)

        invalid = copy.deepcopy(scenario)
        invalid["map"]["palette"][
            scenario["map"]["palette"].index(table_cell)
        ]["turf_kind"] = "space"
        with self.assertRaisesRegex(mod_tools.ModError, "agree with tile"):
            mod_tools.validate_scenario(invalid, "scenario.json", 0)

        invalid = copy.deepcopy(scenario)
        invalid["map"]["palette"][
            scenario["map"]["palette"].index(table_cell)
        ]["wall_kind"] = "standard"
        with self.assertRaisesRegex(mod_tools.ModError, "requires a wall"):
            mod_tools.validate_scenario(invalid, "scenario.json", 0)

        invalid = copy.deepcopy(scenario)
        invalid["map"]["palette"][
            scenario["map"]["palette"].index(table_cell)
        ]["features"] = ["window"]
        with self.assertRaisesRegex(mod_tools.ModError, "requires a boundary"):
            mod_tools.validate_scenario(invalid, "scenario.json", 0)

        invalid = copy.deepcopy(scenario)
        invalid["map"]["palette"][
            scenario["map"]["palette"].index(table_cell)
        ]["features"] = ["crate"]
        with self.assertRaisesRegex(mod_tools.ModError, "requires storage"):
            mod_tools.validate_scenario(invalid, "scenario.json", 0)

        invalid = copy.deepcopy(scenario)
        duplicate = copy.deepcopy(table_cell)
        duplicate["key"] = "same-runtime-semantics"
        duplicate.pop("turf_kind", None)
        invalid["map"]["palette"].append(duplicate)
        with self.assertRaisesRegex(mod_tools.ModError, "duplicate semantic"):
            mod_tools.validate_scenario(invalid, "scenario.json", 0)

        invalid = copy.deepcopy(scenario)
        invalid["spawns"] = [
            {
                "id": (
                    "org.example.test:scenario-spawn/native-palette/"
                    "assistant-x001-y016"
                ),
                "x": 1,
                "y": 16,
                "job": "org.simstation.core:job/assistant",
                "department": "engineering",
                "source_path": "/obj/landmark/start/job/assistant",
            }
        ]
        with self.assertRaisesRegex(mod_tools.ModError, "invalid spawn anchor"):
            mod_tools.validate_scenario(invalid, "scenario.json", 0)

    def test_committed_atlas_scenario_reproduces_from_forked_source(self) -> None:
        source_path = ROOT / "assets" / "upstream" / "goon" / "maps" / "atlas.dmm"
        scenario_path = (
            ROOT
            / "mods"
            / "org.simstation.core"
            / "scenarios"
            / "goon-atlas.json"
        )
        source_bytes = source_path.read_bytes()
        committed = json.loads(scenario_path.read_text(encoding="utf-8"))
        scenario = committed["definitions"][0]
        source = scenario["provenance"]["sources"][0]
        crop = scenario["provenance"]["crop"]

        compiled = map_import.compile_scenario(
            map_import.parse_map(source_bytes, source["path"]),
            {
                "commit": source["commit"],
                "path": source["path"],
                "git_blob": source["git_blob"],
                "sha256": hashlib.sha256(source_bytes).hexdigest(),
            },
            scenario_id=scenario["id"],
            name=scenario["name"],
            crop=(
                crop["min_x"],
                crop["min_y"],
                crop["max_x"],
                crop["max_y"],
            ),
            z_level=crop["z"],
            power_supply_w=scenario["power_supply_w"],
        )

        self.assertEqual(compiled, committed)
        fixtures = scenario["fixtures"]
        self.assertEqual(len(scenario["areas"]), 92)
        self.assertEqual(len(fixtures), 134)
        self.assertEqual(
            Counter(fixture["kind"] for fixture in fixtures),
            Counter(
                {
                    "apc": 81,
                    "barcode_computer": 1,
                    "battery": 6,
                    "cargo_pad": 5,
                    "circulator": 2,
                    "fabricator": 20,
                    "generator": 1,
                    "nanofab": 2,
                    "portable_scrubber": 3,
                    "reclaimer": 7,
                    "supply_console": 2,
                    "vent": 3,
                    "vent_pump": 1,
                }
            ),
        )

        smes = [fixture for fixture in fixtures if fixture["kind"] == "battery"]
        self.assertEqual(len(smes), 6)
        self.assertTrue(
            all(
                fixture["source_overrides"]["chargelevel"] == 15_000
                and fixture["source_overrides"]["output"] == 10_000
                for fixture in smes
            )
        )
        self.assertEqual(
            sum(
                fixture["source_overrides"].get("charge") == 1_000_000
                for fixture in smes
            ),
            2,
        )

        fixtures_by_position: dict[tuple[int, int], list[dict]] = {}
        for fixture in fixtures:
            fixtures_by_position.setdefault(
                (fixture["x"], fixture["y"]),
                [],
            ).append(fixture)
        layered = [
            records for records in fixtures_by_position.values() if len(records) > 1
        ]
        self.assertEqual(len(layered), 5)
        self.assertIn(
            {"apc", "battery"},
            [{record["kind"] for record in records} for records in layered],
        )
        self.assertIn(
            {"apc", "fabricator"},
            [{record["kind"] for record in records} for records in layered],
        )
        self.assertEqual(
            scenario["provenance"]["omissions"]["fixture_collision_omissions"],
            [],
        )
        self.assertEqual(
            scenario["provenance"]["omissions"]["placement_omissions"],
            [],
        )
        palette = scenario["map"]["palette"]
        self.assertEqual(len(palette), 1596)
        self.assertLessEqual(len(palette), 2048)
        self.assertEqual(len(scenario["map"]["runs"]), 4443)
        cells = _decoded_scenario_cells(scenario)
        self.assertEqual(
            Counter(cell.get("turf_kind", "<wall>") for cell in cells.values()),
            Counter(
                {
                    "space": 32100,
                    "plating": 1060,
                    "floor": 2365,
                    "<wall>": 1073,
                    "reinforced_floor": 266,
                }
            ),
        )
        feature_cells = Counter(
            feature
            for cell in cells.values()
            for feature in cell.get("features", [])
        )
        self.assertEqual(
            feature_cells,
            Counter(
                {
                    "catwalk": 318,
                    "chair": 72,
                    "crate": 26,
                    "decal": 334,
                    "disposal": 464,
                    "grille": 385,
                    "lattice": 289,
                    "light": 353,
                    "pipe": 124,
                    "sign": 35,
                    "storage": 100,
                    "table": 155,
                    "window": 378,
                }
            ),
        )

    def test_compiler_and_validator_preserve_colocated_machine_fixtures(self) -> None:
        parsed = map_import.parse_map(
            (
                b'"a" = ('
                b'/obj/cable,'
                b'/obj/table,'
                b'/obj/machinery/power/apc,'
                b'/obj/machinery/power/smes{'
                b'charge = 1e6; chargelevel = 15000; output = 10000'
                b'},'
                b'/turf/simulated/floor,'
                b'/area/station/engineering'
                b')\n'
                b'(1,1,1) = {"a"}\n'
            ),
            "layered-machines.dmm",
        )
        document = map_import.compile_scenario(
            parsed,
            {
                "commit": "1" * 40,
                "path": "maps/layered-machines.dmm",
                "git_blob": "2" * 40,
                "sha256": "3" * 64,
            },
            scenario_id="org.example.test:scenario/layered-machines",
            name="Layered Machines",
            crop=(1, 1, 16, 16),
        )
        scenario = document["definitions"][0]

        self.assertEqual(
            [(fixture["kind"], fixture["x"], fixture["y"]) for fixture in scenario["fixtures"]],
            [("apc", 1, 16), ("battery", 1, 16)],
        )
        self.assertEqual(
            scenario["fixtures"][1]["source_overrides"],
            {
                "charge": 1_000_000,
                "chargelevel": 15_000,
                "output": 10_000,
            },
        )
        self.assertEqual(
            _decoded_scenario_cells(scenario)[(1, 16)]["features"],
            ["table"],
        )
        mod_tools.validate_scenario(scenario, "scenario.json", 0)

    def test_scenario_validator_rejects_unsafe_machine_metadata(self) -> None:
        parsed = map_import.parse_map(
            (
                b'"a" = ('
                b'/obj/machinery/power/smes,'
                b'/turf/simulated/floor,'
                b'/area/station/engineering'
                b')\n'
                b'(1,1,1) = {"a"}\n'
            ),
            "machine-metadata.dmm",
        )
        document = map_import.compile_scenario(
            parsed,
            {
                "commit": "1" * 40,
                "path": "maps/machine-metadata.dmm",
                "git_blob": "2" * 40,
                "sha256": "3" * 64,
            },
            scenario_id="org.example.test:scenario/machine-metadata",
            name="Machine Metadata",
            crop=(1, 1, 16, 16),
        )
        scenario = document["definitions"][0]

        invalid = copy.deepcopy(scenario)
        invalid["fixtures"][0]["source_overrides"] = {"charge": 1.5}
        with self.assertRaisesRegex(mod_tools.ModError, "unsafe fixture source override"):
            mod_tools.validate_scenario(invalid, "scenario.json", 0)

        invalid = copy.deepcopy(scenario)
        invalid["fixtures"][0]["definition_id"] = (
            "org.simstation.core:item/not-a-machine"
        )
        with self.assertRaisesRegex(mod_tools.ModError, "invalid fixture metadata"):
            mod_tools.validate_scenario(invalid, "scenario.json", 0)

    def test_shipped_machine_contracts_validate_strict_schema(self) -> None:
        machine_path = (
            ROOT
            / "mods"
            / "org.simstation.core"
            / "content"
            / "machines.json"
        )
        document = json.loads(machine_path.read_text(encoding="utf-8"))
        definitions = document["definitions"]
        self.assertEqual(len(definitions), 13)
        for index, definition in enumerate(definitions):
            mod_tools.validate_machine(definition, "content/machines.json", index)

        invalid = copy.deepcopy(definitions[0])
        invalid["state_defaults"]["unsafe_fraction"] = 1.5
        with self.assertRaisesRegex(
            mod_tools.ModError,
            "machine state must use JSON integer primitives",
        ):
            mod_tools.validate_machine(invalid, "content/machines.json", 0)

        invalid = copy.deepcopy(definitions[0])
        invalid["tags"] = list(reversed(invalid["tags"]))
        with self.assertRaisesRegex(mod_tools.ModError, "sorted and unique"):
            mod_tools.validate_machine(invalid, "content/machines.json", 0)

        invalid = copy.deepcopy(definitions[0])
        invalid["wires"][1]["index"] = invalid["wires"][0]["index"]
        with self.assertRaisesRegex(mod_tools.ModError, "invalid wire record"):
            mod_tools.validate_machine(invalid, "content/machines.json", 0)

    def test_shipped_structure_contracts_validate_strict_schema(self) -> None:
        structure_path = (
            ROOT
            / "mods"
            / "org.simstation.core"
            / "content"
            / "structures.json"
        )
        document = json.loads(structure_path.read_text(encoding="utf-8"))
        definitions = document["definitions"]
        self.assertGreaterEqual(len(definitions), 3)
        for index, definition in enumerate(definitions):
            mod_tools.validate_structure(
                definition,
                "content/structures.json",
                index,
            )

        invalid = copy.deepcopy(definitions[0])
        invalid["actions"][0]["source_symbol"] = ""
        with self.assertRaisesRegex(
            mod_tools.ModError,
            "invalid structure action",
        ):
            mod_tools.validate_structure(
                invalid,
                "content/structures.json",
                0,
            )

    def test_scenario_validator_rejects_foreign_nested_identity(self) -> None:
        parsed = self.parse_fixture("tgm_minimal.dmm")
        document = map_import.compile_scenario(
            parsed,
            {
                "commit": "1" * 40,
                "path": "maps/test.dmm",
                "git_blob": "2" * 40,
                "sha256": "3" * 64,
            },
            scenario_id="org.example.test:scenario/native-map",
            name="Native Map",
            crop=(1, 10, 16, 25),
        )
        scenario = document["definitions"][0]
        scenario["areas"][0]["key"] = (
            "org.example.other:scenario-area/native-map/engineering"
        )

        with self.assertRaisesRegex(
            mod_tools.ModError,
            "must belong to scenario",
        ):
            mod_tools.validate_scenario(scenario, "scenario.json", 0)


if __name__ == "__main__":
    unittest.main()
