#!/usr/bin/env python3
"""Fixture tests for the read-only DMM/TGM analyzer."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import unittest

from tools import map_import, mods as mod_tools

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests" / "fixtures" / "maps"


class MapImportTests(unittest.TestCase):
    def parse_fixture(self, name: str) -> map_import.ParsedMap:
        path = FIXTURES / name
        return map_import.parse_map(
            path.read_bytes(),
            path.relative_to(ROOT).as_posix(),
        )

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
