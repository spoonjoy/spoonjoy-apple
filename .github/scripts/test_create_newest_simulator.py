"""Tests for create-newest-simulator.py: python3 -I .github/scripts/test_create_newest_simulator.py"""
import importlib.util
import pathlib
import unittest

spec = importlib.util.spec_from_file_location("picker", pathlib.Path(__file__).with_name("create-newest-simulator.py"))
picker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(picker)


def runtime(version, *names):
    return {"platform": "iOS", "isAvailable": True, "version": version, "identifier": f"iOS-{version}",
            "supportedDeviceTypes": [{"name": n, "identifier": n, "productFamily": "iPad" if "iPad" in n else "iPhone"} for n in names]}


LISTING = {"runtimes": [runtime("27.0", "iPhone 17 Pro", "iPad Pro"), runtime("27.1", "iPhone Duo"),
                        runtime("27.2", "iPhone 18 Pro")]}


class Pick(unittest.TestCase):
    def test_newest_runtime_without_a_limit(self):
        self.assertEqual(picker.pick("iPhone", LISTING), ("iOS-27.2", "iPhone 18 Pro"))

    def test_never_a_runtime_newer_than_the_selected_xcode(self):
        # The runner image carries iOS 27.2, newer than Xcode 27.1's SDK; it hung booting twice (#218).
        self.assertEqual(picker.pick("iPhone", LISTING, sdk="27.1"), ("iOS-27.0", "iPhone 17 Pro"))
        self.assertEqual(picker.pick("iPhone Duo", LISTING, sdk="27.1"), ("iOS-27.1", "iPhone Duo"))
        self.assertEqual(picker.pick("iPad", LISTING, sdk="27.1"), ("iOS-27.0", "iPad Pro"))

    def test_no_runtime_at_or_below_the_sdk(self):
        with self.assertRaises(SystemExit):
            picker.pick("iPhone", LISTING, sdk="26.4")


if __name__ == "__main__":
    unittest.main()
