"""Tests for export-store-scenes.py: python3 -I .github/scripts/test_export_store_scenes.py"""
import importlib.util
import pathlib
import unittest

spec = importlib.util.spec_from_file_location("export", pathlib.Path(__file__).with_name("export-store-scenes.py"))
export = importlib.util.module_from_spec(spec)
spec.loader.exec_module(export)


def attachment(name, file):
    return {"suggestedHumanReadableName": name, "exportedFileName": file}


class ScenesIn(unittest.TestCase):
    def test_reads_scene_names_with_or_without_the_generated_suffix(self):
        manifest = [{"attachments": [attachment("scene-kitchen_0_8B1F0E1C-1D3A-4B5C-9E2F-0A1B2C3D4E5F.png", "a.png"),
                                     attachment("scene-cook-mode-dark.png", "b.png"),
                                     attachment("Screenshot of failure", "c.png")]}]
        self.assertEqual(export.scenes_in(manifest), ({"kitchen": "a.png", "cook-mode-dark": "b.png"}, []))

    def test_a_scene_taken_twice_is_reported(self):
        manifest = [{"attachments": [attachment("scene-kitchen", "a.png")]}, {"attachments": [attachment("scene-kitchen", "b.png")]}]
        self.assertEqual(export.scenes_in(manifest)[1], ["kitchen"])


if __name__ == "__main__":
    unittest.main()
