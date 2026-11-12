#!/usr/bin/env python3
"""Run: python3 -I .github/scripts/test_pick_matching_xcode.py"""
import importlib.util
import pathlib
import unittest

spec = importlib.util.spec_from_file_location("picker", pathlib.Path(__file__).with_name("pick-matching-xcode.py"))
picker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(picker)


def runtime(version, *devices, available=True):
    return {
        "platform": "iOS", "isAvailable": available, "version": version,
        "identifier": f"com.apple.CoreSimulator.SimRuntime.iOS-{version.replace('.', '-')}",
        "supportedDeviceTypes": [
            {"name": name, "identifier": f"type.{name.replace(' ', '-')}", "productFamily": "iPad" if name.startswith("iPad") else "iPhone"}
            for name in devices
        ],
    }


class PickTest(unittest.TestCase):
    def test_xcode_27_1_beside_runtime_27_2_picks_the_proven_pair_that_matches(self):
        # Journeys run 43054178295: Xcode 27.1 selected, iOS 27.2 booted, so the bundle could not load.
        listing = {"runtimes": [runtime("27.1", "iPhone Duo"), runtime("27.2", "iPhone 18 Pro", "iPhone Duo")]}
        xcodes = [("/Applications/Xcode_27.1.app", "27.1"), ("/Applications/Xcode_27.2.0.app", "27.2")]
        self.assertEqual(picker.pick(xcodes, listing), ("/Applications/Xcode_27.1.app", "com.apple.CoreSimulator.SimRuntime.iOS-27-1", "type.iPhone-Duo"))

    def test_a_matching_pair_that_is_not_proven_is_never_picked(self):
        # No passing Siri journey has run on 27.2 yet, so a 27.2 pair is not picked until one does.
        listing = {"runtimes": [runtime("27.2", "iPhone 18 Pro")]}
        with self.assertRaises(SystemExit) as raised:
            picker.pick([("/Applications/Xcode_27.2.0.app", "27.2")], listing)
        self.assertIn("proven: 27.1, 27.0", str(raised.exception))

    def test_the_newest_proven_pair_wins(self):
        listing = {"runtimes": [runtime("27.0", "iPhone 17 Pro"), runtime("27.1", "iPhone Duo")]}
        xcodes = [("/Applications/Xcode_27.0.app", "27.0"), ("/Applications/Xcode_27.1.app", "27.1")]
        self.assertEqual(picker.pick(xcodes, listing)[0], "/Applications/Xcode_27.1.app")

    def test_the_duo_is_picked_over_a_plain_iphone(self):
        # The journey holds the Duo open (posture "flat"), and every passing run used it (run 43207409010), so a runner
        # image that adds a plain iPhone must not switch the device under it.
        listing = {"runtimes": [runtime("27.1", "iPhone 18 Pro", "iPhone Duo", "iPhone 18")]}
        self.assertEqual(picker.pick([("/Applications/Xcode_27.1.app", "27.1")], listing)[2], "type.iPhone-Duo")

    def test_a_runtime_without_the_duo_does_not_count(self):
        listing = {"runtimes": [runtime("27.1", "iPhone 18 Pro")]}
        with self.assertRaises(SystemExit) as raised:
            picker.pick([("/Applications/Xcode_27.1.app", "27.1")], listing)
        self.assertIn("iPhone Duo", str(raised.exception))

    def test_an_unavailable_or_ipad_only_runtime_does_not_count(self):
        listing = {"runtimes": [runtime("27.1", "iPhone 18 Pro", available=False), runtime("27.0", "iPad Pro")]}
        xcodes = [("/Applications/Xcode_27.1.app", "27.1"), ("/Applications/Xcode_27.0.app", "27.0")]
        with self.assertRaises(SystemExit) as raised:
            picker.pick(xcodes, listing)
        self.assertIn("Xcode_27.1.app (SDK 27.1)", str(raised.exception))
        self.assertIn("iOS runtimes: 27.0", str(raised.exception))


if __name__ == "__main__":
    unittest.main()
