#!/usr/bin/env python3

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "run-ios-screenshot-observer.py"
SPEC = importlib.util.spec_from_file_location("run_ios_screenshot_observer", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class DynamicTypeObservationTests(unittest.TestCase):
    def write_proof(self, root: Path, observed: str) -> Path:
        path = root / "native-accessibility-proof.json"
        path.write_text(json.dumps({"observedDynamicTypeSize": observed}))
        return path

    def test_records_large_from_the_app_proof(self):
        with tempfile.TemporaryDirectory() as directory:
            proof = self.write_proof(Path(directory), "large")
            evidence = {}

            MODULE.attest_observed_dynamic_type(evidence, proof, "large")

            self.assertEqual(evidence["observedContentSizeCategory"], "large")
            self.assertEqual(evidence["observedDynamicTypeSize"], "large")

    def test_records_accessibility5_from_the_app_proof(self):
        with tempfile.TemporaryDirectory() as directory:
            proof = self.write_proof(Path(directory), "accessibility5")
            evidence = {}

            MODULE.attest_observed_dynamic_type(
                evidence,
                proof,
                "accessibility-extra-extra-extra-large",
            )

            self.assertEqual(
                evidence["observedContentSizeCategory"],
                "accessibility-extra-extra-extra-large",
            )
            self.assertEqual(evidence["observedDynamicTypeSize"], "accessibility5")

    def test_rejects_requested_and_observed_mismatch(self):
        with tempfile.TemporaryDirectory() as directory:
            proof = self.write_proof(Path(directory), "large")

            with self.assertRaisesRegex(SystemExit, "Dynamic Type mismatch"):
                MODULE.attest_observed_dynamic_type(
                    {},
                    proof,
                    "accessibility-extra-extra-extra-large",
                )

    def test_rejects_missing_or_invalid_app_proof(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaisesRegex(SystemExit, "actual Dynamic Type proof"):
                MODULE.attest_observed_dynamic_type({}, root / "missing.json", "large")

            invalid = root / "invalid.json"
            invalid.write_text("{}")
            with self.assertRaisesRegex(SystemExit, "actual Dynamic Type proof"):
                MODULE.attest_observed_dynamic_type({}, invalid, "large")


if __name__ == "__main__":
    unittest.main()
