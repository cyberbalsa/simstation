#!/usr/bin/env python3
"""Fixture tests for pinned Goon DM appearance selection and map records."""

from __future__ import annotations

from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import unittest

from tools import assets, map_import


ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = (
    ROOT / "assets" / "runtime" / "goon" / "graphics" / "dm-appearances.json"
)
PROFILE_PATH = (
    ROOT / "assets" / "source" / "goon" / "dm-appearance-profile.json"
)
SCENARIO_PATH = (
    ROOT
    / "mods"
    / "org.simstation.core"
    / "scenarios"
    / "goon-atlas.json"
)


class DmAppearanceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        cls.profile = json.loads(PROFILE_PATH.read_text(encoding="utf-8"))
        cls.scenario = json.loads(
            SCENARIO_PATH.read_text(encoding="utf-8")
        )["definitions"][0]
        cls.rules = {
            (rule["role"], rule["type_path"]): rule
            for rule in cls.manifest["rules"]
        }

    def part(self, role: str, path: str, index: int = 0) -> dict:
        return self.rules[(role, path)]["parts"][index]

    def test_safe_visual_overrides_are_data_only_and_fixed_point(self) -> None:
        parsed = map_import.parse_map(
            (
                b'"a" = ('
                b"/obj/machinery/door/poddoor/pyro{"
                b"density = 0; "
                b"icon = 'icons/obj/stationobjs.dmi'; "
                b'icon_state = "pdoor0"; '
                b"dir = 4; pixel_x = -2; pixel_y = 3; layer = 2.6"
                b"},"
                b"/turf/space,"
                b"/area/space"
                b")\n"
                b'(1,1,1) = {"a"}\n'
            ),
            "appearance-overrides.dmm",
        )
        door = parsed.entries["a"].atoms[0]
        self.assertEqual(
            dict(door.appearance_overrides),
            {
                "direction": "east",
                "icon_override": "icons/obj/stationobjs.dmi",
                "icon_state_override": "pdoor0",
                "layer_milli": 2600,
                "pixel_x": -2,
                "pixel_y": 3,
            },
        )
        appearances = map_import.collect_appearances(
            parsed,
            {(1, 1, 1): "a"},
            (1, 1, 16, 16),
        )
        self.assertEqual(
            [(row["index"], row["order"]) for row in appearances],
            [(241, 1), (241, 2)],
        )
        self.assertEqual(appearances[0]["direction"], "east")
        self.assertEqual(appearances[1]["resolved_icon_state"], "23")
        self.assertEqual(
            map_import._cell_contract(parsed.entries["a"], {})[1],
            "door_open",
        )

    def test_atlas_appearance_records_are_sorted_and_source_faithful(self) -> None:
        appearances = self.scenario["map"]["appearances"]
        self.assertEqual(len(appearances), 43_813)
        self.assertEqual(
            Counter(row["role"] for row in appearances),
            Counter({"turf": 36_864, "object": 6_949}),
        )
        ordering = [(row["index"], row["order"]) for row in appearances]
        self.assertEqual(ordering, sorted(ordering))
        self.assertEqual(len(ordering), len(set(ordering)))
        self.assertTrue(
            all(
                row["direction"] in set(map_import.BYOND_DIRECTIONS.values())
                for row in appearances
            )
        )

        space = [
            row for row in appearances if row["source_path"] == "/turf/space"
        ]
        self.assertEqual(len(space), 32_100)
        self.assertEqual(
            space[0]["resolved_icon_state"],
            map_import._space_icon_state(61, 252, 1),
        )
        self.assertEqual(
            {int(row["resolved_icon_state"]) for row in space},
            set(range(1, 26)),
        )

        open_poddoors = [
            row
            for row in appearances
            if row.get("icon_state_override") == "pdoor0"
            and row["source_path"].startswith("/obj/machinery/door/poddoor")
        ]
        self.assertEqual(len(open_poddoors), 51)
        self.assertTrue(
            all(
                row["direction"] in set(map_import.BYOND_DIRECTIONS.values())
                for row in open_poddoors
            )
        )

    def test_runtime_selection_is_compact_pinned_and_self_contained(self) -> None:
        manifest = self.manifest
        self.assertEqual(manifest["format_version"], 1)
        self.assertEqual(manifest["kind"], "goon-dm-appearance-selection")
        self.assertEqual(manifest["source_commit"], assets.GOON_COMMIT)
        self.assertEqual(
            manifest["profile_sha256"],
            hashlib.sha256(PROFILE_PATH.read_bytes()).hexdigest(),
        )
        self.assertLess(
            MANIFEST_PATH.stat().st_size,
            (ROOT / "assets/runtime/goon/graphics/atlas.json").stat().st_size
            // 10,
        )
        self.assertEqual(
            manifest["rules"],
            sorted(
                manifest["rules"],
                key=lambda rule: (
                    rule["role"],
                    rule["type_path"],
                    rule["match"],
                ),
            ),
        )
        self.assertEqual(
            manifest["coverage"],
            {
                "appearance_instances": 43_813,
                "fallback_instances": 11,
                "fallback_source_paths": 8,
                "mapped_instances": 43_802,
                "mapped_source_paths": 1_172,
                "unresolved": manifest["coverage"]["unresolved"],
            },
        )
        selected = manifest["sprites"]
        for rule in manifest["rules"]:
            for part in rule["parts"]:
                self.assertIn(part["sprite_id"], selected)
        for page in manifest["pages"]:
            self.assertEqual(
                set(page),
                {
                    "bundle",
                    "page",
                    "runtime_path",
                    "width",
                    "height",
                    "sha256",
                },
            )

    def test_representative_upstream_type_states_are_not_flattened(self) -> None:
        expected = {
            ("turf", "/turf/simulated/floor/black"): (
                "icons/turf/floors.dmi",
                "dark",
            ),
            ("turf", "/turf/simulated/floor/white"): (
                "icons/turf/floors.dmi",
                "white",
            ),
            ("object", "/obj/machinery/door/airlock/pyro/engineering/alt"): (
                "icons/obj/doors/SL_doors.dmi",
                "eng2_closed",
            ),
            ("object", "/obj/machinery/manufacturer/mining"): (
                "icons/obj/manufacturer.dmi",
                "fab-mining",
            ),
            ("object", "/obj/machinery/power/smes"): (
                "icons/obj/power.dmi",
                "smes",
            ),
            ("object", "/obj/stool/chair/office/purple"): (
                "icons/obj/furniture/chairs.dmi",
                "office_chair_purple",
            ),
            ("object", "/obj/storage/closet/fire"): (
                "icons/obj/storage/locker.dmi",
                "fire",
            ),
            ("object", "/obj/table/wood/round/auto"): (
                "icons/obj/furniture/table_wood_round.dmi",
                "0",
            ),
        }
        for key, wanted in expected.items():
            part = self.part(*key)
            self.assertEqual(
                (part["source_icon"], part["source_state"]),
                wanted,
            )

        apc = self.part(
            "object",
            "/obj/machinery/power/apc/autoname_east",
        )
        self.assertEqual(apc["fixed_direction"], "east")
        self.assertEqual(apc["pixel_x"], 20)
        for fixture in self.scenario["fixtures"]:
            self.assertIn(("object", fixture["source_path"]), self.rules)

    def test_connected_families_include_runtime_mask_states(self) -> None:
        selected_pairs = {
            (entry["source_path"], entry["source_state"])
            for entry in self.manifest["sprites"].values()
        }
        for state in ("norn-0", "norn-15", "norn-R-0", "norn-R-15"):
            self.assertIn(
                ("icons/turf/walls/supernorn/smooth.dmi", state),
                selected_pairs,
            )
        for state in ("W-0", "W-15", "R-0", "R-15"):
            self.assertIn(
                ("icons/obj/window_pyro.dmi", state),
                selected_pairs,
            )
        for icon in (
            "icons/obj/furniture/table.dmi",
            "icons/obj/furniture/table_reinforced.dmi",
            "icons/obj/furniture/table_wood.dmi",
        ):
            self.assertIn((icon, "0"), selected_pairs)
            self.assertIn((icon, "15"), selected_pairs)

        helper = self.rules[
            ("object", "/obj/mapping_helper/wingrille_spawn/auto/reinforced")
        ]
        self.assertEqual(
            [
                (
                    part["source_icon"],
                    part["source_state"],
                    part["state_prefix"],
                    part.get("state_suffix"),
                )
                for part in helper["parts"]
            ],
            [
                (
                    "icons/obj/SL_windows_grilles.dmi",
                    "grille1-0",
                    "grille",
                    "-0",
                ),
                ("icons/obj/window_pyro.dmi", "R-0", "R-", None),
            ],
        )

    def test_map_editor_placeholders_have_runtime_catalog_states(self) -> None:
        selected_pairs = {
            (entry["source_path"], entry["source_state"])
            for entry in self.manifest["sprites"].values()
        }

        plating_path = "/turf/simulated/floor/plating/random"
        plating = self.rules[("turf", plating_path)]
        self.assertEqual(plating["fidelity"], "runtime-random-deferred")
        self.assertEqual(
            (
                plating["parts"][0]["source_icon"],
                plating["parts"][0]["source_state"],
            ),
            ("icons/turf/floors.dmi", "plating_random"),
        )
        self.assertIn(("icons/turf/floors.dmi", "plating"), selected_pairs)
        plating_rows = [
            row
            for row in self.scenario["map"]["appearances"]
            if row["source_path"] == plating_path
        ]
        self.assertEqual(len(plating_rows), 341)
        self.assertTrue(
            all(
                "icon_state_override" not in row
                and "resolved_icon_state" not in row
                for row in plating_rows
            )
        )

        catwalk_path = (
            "/turf/simulated/floor/airless/plating/catwalk/auto"
        )
        catwalk = self.rules[("turf", catwalk_path)]
        self.assertEqual(catwalk["fidelity"], "connected-state-deferred")
        self.assertEqual(
            (
                catwalk["parts"][0]["source_icon"],
                catwalk["parts"][0]["source_state"],
            ),
            ("icons/turf/catwalk_support.dmi", "auto"),
        )
        family = next(
            row
            for row in self.profile["connected_state_families"]
            if row["type_path"] == catwalk_path
        )
        for state in ("0", "1", "2", "4", "8", "15"):
            self.assertIsNotNone(re.fullmatch(family["state_regex"], state))
            self.assertIn(
                ("icons/turf/catwalk_support.dmi", state),
                selected_pairs,
            )
        self.assertIsNotNone(re.fullmatch(family["state_regex"], "auto"))
        catwalk_rows = [
            row
            for row in self.scenario["map"]["appearances"]
            if row["source_path"] == catwalk_path
        ]
        self.assertEqual(len(catwalk_rows), 227)
        self.assertTrue(
            all(
                "icon_state_override" not in row
                and "resolved_icon_state" not in row
                for row in catwalk_rows
            )
        )

    def test_wingrille_helpers_use_pinned_sl_grille_family(self) -> None:
        helper_paths = (
            "/obj/mapping_helper/wingrille_spawn/auto",
            "/obj/mapping_helper/wingrille_spawn/auto/crystal",
            "/obj/mapping_helper/wingrille_spawn/auto/reinforced",
            "/obj/mapping_helper/wingrille_spawn/auto/reinforced/crystal",
        )
        profile_rules = {
            row["type_path"]: row
            for row in self.profile["explicit_rules"]
        }
        for path in helper_paths:
            for rule in (profile_rules[path], self.rules[("object", path)]):
                grille = rule["parts"][0]
                self.assertEqual(
                    (
                        grille["source_icon"],
                        grille["source_state"],
                        grille["state_prefix"],
                        grille["state_suffix"],
                    ),
                    (
                        "icons/obj/SL_windows_grilles.dmi",
                        "grille1-0",
                        "grille",
                        "-0",
                    ),
                )
                self.assertNotEqual(
                    grille["source_icon"],
                    "icons/obj/grille.dmi",
                )

        selected_sl_states = {
            entry["source_state"]
            for entry in self.manifest["sprites"].values()
            if entry["source_path"] == "icons/obj/SL_windows_grilles.dmi"
        }
        self.assertTrue(
            {
                "grille1-0",
                "grille3-0",
                "grille4-0",
                "grille6-0",
                "grille8-0",
                "grille10-0",
                "grille12-0",
                "grille14-0",
            }.issubset(selected_sl_states)
        )

    def test_twotone_macro_floors_keep_exact_states_and_counts(self) -> None:
        expected = {
            "/turf/simulated/floor/twotone/black": (
                "twotone_black",
                34,
            ),
            "/turf/simulated/floor/twotone/darkblue": (
                "twotone_dblue",
                18,
            ),
        }
        for path, (state, count) in expected.items():
            part = self.part("turf", path)
            self.assertEqual(
                (part["source_icon"], part["source_state"]),
                ("icons/turf/floors.dmi", state),
            )
            self.assertEqual(
                sum(
                    row["source_path"] == path
                    for row in self.scenario["map"]["appearances"]
                ),
                count,
            )

    def test_door_runtime_families_include_both_end_states(self) -> None:
        selected_pairs = {
            (entry["source_path"], entry["source_state"])
            for entry in self.manifest["sprites"].values()
        }
        families = {
            "/obj/machinery/door/airlock/pyro": (
                "icons/obj/doors/SL_doors.dmi",
                "door_closed",
                "door_open",
            ),
            "/obj/machinery/door/poddoor/pyro": (
                "icons/obj/doors/SL_doors.dmi",
                "pdoor1",
                "pdoor0",
            ),
            "/obj/machinery/door/poddoor/blast/pyro": (
                "icons/obj/doors/SL_doors.dmi",
                "bdoorsingle1",
                "bdoorsingle0",
            ),
            "/obj/machinery/door/unpowered/wood/pyro": (
                "icons/obj/doors/SL_doors.dmi",
                "wood1",
                "wood0",
            ),
            "/obj/machinery/door/unpowered/wood/stall": (
                "icons/obj/doors/door_stall.dmi",
                "door1",
                "door0",
            ),
        }
        for path, (icon, closed, opened) in families.items():
            rule = self.rules[("object", path)]
            self.assertEqual(rule["fidelity"], "runtime-state-deferred")
            self.assertEqual(
                (
                    rule["parts"][0]["source_icon"],
                    rule["parts"][0]["source_state"],
                ),
                (icon, closed),
            )
            self.assertIn((icon, closed), selected_pairs)
            self.assertIn((icon, opened), selected_pairs)

    def test_static_index_tracks_nested_dm_subtypes(self) -> None:
        index = assets._dm_static_appearance_index()
        self.assertEqual(
            assets._dm_resolve_static(
                index,
                "/obj/machinery/power/apc/autoname_east",
                "dir",
            )["value"],
            "EAST",
        )
        self.assertEqual(
            assets._dm_resolve_static(
                index,
                "/obj/stool/chair/office/purple",
                "icon_state",
            )["value"],
            "office_chair_purple",
        )
        self.assertEqual(
            assets._dm_resolve_static(
                index,
                "/turf/simulated/floor/twotone/black",
                "icon_state",
            )["value"],
            "twotone_black",
        )
        self.assertEqual(
            assets._dm_resolve_static(
                index,
                "/turf/simulated/floor/twotone/darkblue",
                "icon_state",
            )["value"],
            "twotone_dblue",
        )


if __name__ == "__main__":
    unittest.main()
