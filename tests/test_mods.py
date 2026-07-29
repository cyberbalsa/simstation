"""Strict lighting-content validation fixtures."""

from __future__ import annotations

import json
import unittest

from tools import mods


def manifest() -> dict:
    return {
        "id": "org.example.lights",
        "content": ["content/*.json"],
        "scenario_maps": [],
        "replaces": [],
    }


def profile() -> dict:
    return {
        "id": "org.example.lights:light-profile/warm",
        "kind": "light-profile",
        "schema": 1,
        "name_key": "org.example.lights.profile.warm",
        "color_srgb8": [255, 220, 190],
        "radius_256": 768,
        "intensity_ppm": 1_000_000,
        "height_256": 614,
        "falloff": "smoothstep",
        "occlusion": "tile-transmission",
        "flicker": {"mode": "none"},
        "priority": 100,
        "bloom_ppm": 50_000,
        "bloom_radius_256": 256,
    }


def validate(definitions: list[dict]) -> dict:
    document = json.dumps({"schema": 1, "definitions": definitions}).encode()
    return mods.validate_content(
        manifest(),
        {"content/lighting.json": document},
    )


class LightingModValidationTests(unittest.TestCase):
    def test_settings_schema_one_defaults_work_budget(self) -> None:
        settings = {
            "id": "org.simstation.core:lighting-settings/station",
            "kind": "lighting-settings",
            "schema": 1,
            "station_ambient_srgb8": [0, 0, 0],
            "space_ambient_srgb8": [255, 255, 255],
            "max_emitters": 128,
            "max_radius_256": 768,
            "shader": True,
            "linear_filter": True,
        }
        mods.validate_lighting_settings(settings, "content/lights.json", 0)
        settings["max_work_units"] = 64_000_001
        with self.assertRaisesRegex(mods.ModError, "max_work_units"):
            mods.validate_lighting_settings(
                settings,
                "content/lights.json",
                0,
            )

    def test_profile_and_provider_binding_validate(self) -> None:
        binding = {
            "id": "org.example.lights:light-binding/warm-fixtures",
            "kind": "light-binding",
            "schema": 1,
            "profile_id": "org.example.lights:light-profile/warm",
            "selector": {
                "kind": "provider",
                "provider_id": (
                    "org.simstation.core:light-provider/light-feature-v1"
                ),
            },
            "activation": {
                "mode": "normal",
                "power_channel": "lighting",
            },
            "offset_x_256": 0,
            "offset_y_256": 0,
            "level_ppm": 1_000_000,
        }
        report = validate([profile(), binding])
        self.assertEqual(report["definition_count"], 2)

    def test_profile_rejects_floats_and_unknown_shader_fields(self) -> None:
        invalid = profile()
        invalid["intensity_ppm"] = 1.25
        with self.assertRaisesRegex(mods.ModError, "intensity_ppm"):
            validate([invalid])

        invalid = profile()
        invalid["shader"] = "unsafe.glsl"
        with self.assertRaisesRegex(mods.ModError, "unknown light-profile"):
            validate([invalid])

    def test_binding_rejects_unregistered_provider(self) -> None:
        invalid = {
            "id": "org.example.lights:light-binding/unsafe",
            "kind": "light-binding",
            "schema": 1,
            "profile_id": "org.example.lights:light-profile/warm",
            "selector": {
                "kind": "provider",
                "provider_id": "org.example.lights:light-provider/unbounded",
            },
            "activation": {
                "mode": "always",
                "power_channel": "none",
            },
            "offset_x_256": 0,
            "offset_y_256": 0,
            "level_ppm": 1_000_000,
        }
        with self.assertRaisesRegex(mods.ModError, "provider"):
            validate([profile(), invalid])

    def test_source_path_rejects_non_string_scenario_ids_cleanly(self) -> None:
        invalid = {
            "id": "org.example.lights:light-binding/path",
            "kind": "light-binding",
            "schema": 1,
            "profile_id": "org.example.lights:light-profile/warm",
            "selector": {
                "kind": "source-path",
                "path_root": "/obj/machinery/light",
                "scenario_ids": [["not-a-string"]],
            },
            "activation": {
                "mode": "always",
                "power_channel": "none",
            },
            "offset_x_256": 0,
            "offset_y_256": 0,
            "level_ppm": 1_000_000,
        }
        with self.assertRaisesRegex(mods.ModError, "scenario IDs"):
            validate([profile(), invalid])


if __name__ == "__main__":
    unittest.main()
