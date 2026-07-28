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

    def test_compiler_and_validator_preserve_colocated_machine_fixtures(self) -> None:
        parsed = map_import.parse_map(
            (
                b'"a" = ('
                b'/obj/cable,'
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
