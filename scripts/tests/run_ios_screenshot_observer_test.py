#!/usr/bin/env python3

import importlib.util
import hashlib
import json
import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "run-ios-screenshot-observer.py"
SPEC = importlib.util.spec_from_file_location("run_ios_screenshot_observer", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class DynamicTypeObservationTests(unittest.TestCase):
    def write_proof(self, root: Path, observed: str) -> Path:
        path = root / "native-accessibility-proof.json"
        path.write_text(
            json.dumps(
                {
                    "observedDynamicTypeSize": observed,
                    "visualReadiness": {
                        "pendingMediaCount": 0,
                        "failedMediaCount": 0,
                        "blockingIndicatorCount": 0,
                        "isSettled": True,
                    },
                }
            )
        )
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

    def test_rejects_unsettled_or_failed_media(self):
        with tempfile.TemporaryDirectory() as directory:
            proof = self.write_proof(Path(directory), "large")
            payload = json.loads(proof.read_text())
            payload["visualReadiness"]["failedMediaCount"] = 1
            payload["visualReadiness"]["isSettled"] = False
            proof.write_text(json.dumps(payload))

            with self.assertRaisesRegex(SystemExit, "visual readiness"):
                MODULE.attest_observed_dynamic_type({}, proof, "large")

    def test_inline_proof_path_rebases_into_current_app_container(self):
        container = Path("/simulator/current-app-container")
        configured = Path("/simulator/stale-container/native-accessibility-proof.json")

        self.assertEqual(
            MODULE.inline_app_proof_path(container, configured),
            container
            / "Library"
            / "Application Support"
            / "Spoonjoy"
            / "native-accessibility-proof.json",
        )

    def test_attests_exact_run_nonce_route_platform_source_and_proof_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            proof = Path(directory) / "native-accessibility-proof.generation-12.json"
            payload = {
                "captureRunNonce": "7238f644-ff7a-4c1a-a9aa-60dd478c1c1d",
                "route": "kitchen",
                "platform": "ipad",
                "source": "KitchenView",
                "readinessGeneration": 12,
                "emittedBy": "SpoonjoyApp",
                "bundleIdentifier": "app.spoonjoy",
            }
            proof.write_text(json.dumps(payload, sort_keys=True))
            digest = hashlib.sha256(proof.read_bytes()).hexdigest()
            evidence = {
                "readinessHandshake": {
                    "captureRunNonce": payload["captureRunNonce"],
                    "route": payload["route"],
                    "source": payload["source"],
                    "readinessGeneration": payload["readinessGeneration"],
                    "proofFileName": proof.name,
                    "proofSHA256": digest,
                }
            }

            MODULE.attest_screenshot_readiness(
                evidence,
                proof,
                expected_run_nonce=payload["captureRunNonce"],
                expected_route="kitchen",
                expected_platform="ipad",
            )

    def test_rejects_stale_or_substituted_readiness_proof(self):
        with tempfile.TemporaryDirectory() as directory:
            proof = Path(directory) / "native-accessibility-proof.generation-12.json"
            payload = {
                "captureRunNonce": "7238f644-ff7a-4c1a-a9aa-60dd478c1c1d",
                "route": "kitchen",
                "platform": "ipad",
                "source": "KitchenView",
                "readinessGeneration": 12,
                "emittedBy": "SpoonjoyApp",
                "bundleIdentifier": "app.spoonjoy",
            }
            proof.write_text(json.dumps(payload, sort_keys=True))
            evidence = {
                "readinessHandshake": {
                    "captureRunNonce": payload["captureRunNonce"],
                    "route": payload["route"],
                    "source": payload["source"],
                    "readinessGeneration": payload["readinessGeneration"],
                    "proofFileName": proof.name,
                    "proofSHA256": "0" * 64,
                }
            }

            with self.assertRaisesRegex(SystemExit, "SHA-256"):
                MODULE.attest_screenshot_readiness(
                    evidence,
                    proof,
                    expected_run_nonce=payload["captureRunNonce"],
                    expected_route="kitchen",
                    expected_platform="ipad",
                )

    def test_resolves_only_the_generation_archive_named_by_the_handshake(self):
        canonical = Path("/simulator/container/native-accessibility-proof.json")
        handshake = {
            "readinessGeneration": 12,
            "proofFileName": "native-accessibility-proof.generation-12.json",
        }

        self.assertEqual(
            MODULE.readiness_proof_path(canonical, handshake),
            canonical.with_name(handshake["proofFileName"]),
        )
        for substituted in (
            {**handshake, "proofFileName": "../native-accessibility-proof.generation-12.json"},
            {**handshake, "proofFileName": "native-accessibility-proof.generation-11.json"},
            {**handshake, "readinessGeneration": -1},
        ):
            with self.assertRaises(SystemExit):
                MODULE.readiness_proof_path(canonical, substituted)

    def test_rejects_coherently_substituted_generation(self):
        with tempfile.TemporaryDirectory() as directory:
            proof = Path(directory) / "native-accessibility-proof.generation-13.json"
            payload = {
                "captureRunNonce": "7238f644-ff7a-4c1a-a9aa-60dd478c1c1d",
                "route": "kitchen",
                "platform": "ipad",
                "source": "KitchenView",
                "readinessGeneration": 13,
                "emittedBy": "SpoonjoyApp",
                "bundleIdentifier": "app.spoonjoy",
            }
            proof.write_text(json.dumps(payload, sort_keys=True))
            evidence = {
                "readinessHandshake": {
                    "captureRunNonce": payload["captureRunNonce"],
                    "route": payload["route"],
                    "source": payload["source"],
                    "readinessGeneration": 12,
                    "proofFileName": "native-accessibility-proof.generation-12.json",
                    "proofSHA256": hashlib.sha256(proof.read_bytes()).hexdigest(),
                }
            }

            with self.assertRaisesRegex(SystemExit, "generation"):
                MODULE.attest_screenshot_readiness(
                    evidence,
                    proof,
                    expected_run_nonce=payload["captureRunNonce"],
                    expected_route="kitchen",
                    expected_platform="ipad",
                )

            evidence["readinessHandshake"]["proofSHA256"] = hashlib.sha256(
                proof.read_bytes()
            ).hexdigest()
            with self.assertRaisesRegex(SystemExit, "run nonce"):
                MODULE.attest_screenshot_readiness(
                    evidence,
                    proof,
                    expected_run_nonce="dd9e30cb-630f-4b4d-99b4-9ed82b80a7f2",
                    expected_route="kitchen",
                    expected_platform="ipad",
                )


class ScreenshotAttachmentTests(unittest.TestCase):
    def write_attachments(self, root: Path, names: list[str]) -> None:
        attachments = []
        for index, name in enumerate(names):
            filename = f"attachment-{index}.png"
            (root / filename).write_bytes(b"png")
            attachments.append(
                {
                    "suggestedHumanReadableName": name,
                    "exportedFileName": filename,
                }
            )
        (root / "manifest.json").write_text(
            json.dumps([{"attachments": attachments}])
        )

    def test_distinguishes_opening_and_deep_scroll_screenshots(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.write_attachments(
                root,
                [
                    "observed-accessibility-screenshot_0_A.png",
                    "deep-scroll-screenshot_0_B.png",
                ],
            )

            self.assertEqual(
                [path.name for path in MODULE.observed_screenshot_files(root)],
                ["attachment-0.png"],
            )
            self.assertEqual(
                [path.name for path in MODULE.deep_scroll_screenshot_files(root)],
                ["attachment-1.png"],
            )

    def test_deep_scroll_lookup_does_not_accept_opening_screenshot(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.write_attachments(
                root,
                ["observed-accessibility-screenshot_0_A.png"],
            )

            self.assertEqual(MODULE.deep_scroll_screenshot_files(root), [])

    def test_attests_exact_exported_screenshot_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            screenshot = Path(directory) / "observed.png"
            screenshot.write_bytes(b"exact-png-bytes")
            evidence = {
                "screenshotSHA256": hashlib.sha256(screenshot.read_bytes()).hexdigest()
            }

            MODULE.attest_exported_screenshot(
                evidence,
                screenshot,
                "screenshotSHA256",
            )

    def test_rejects_missing_or_substituted_exported_screenshot_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            screenshot = Path(directory) / "observed.png"
            screenshot.write_bytes(b"exact-png-bytes")
            with self.assertRaisesRegex(SystemExit, "missing screenshotSHA256"):
                MODULE.attest_exported_screenshot({}, screenshot, "screenshotSHA256")

            with self.assertRaisesRegex(SystemExit, "SHA-256 mismatch"):
                MODULE.attest_exported_screenshot(
                    {"screenshotSHA256": "0" * 64},
                    screenshot,
                    "screenshotSHA256",
                )


class SimulatorLifecycleTests(unittest.TestCase):
    @mock.patch.object(MODULE.subprocess, "run")
    def test_resolve_boots_simulator_before_container_lookup(self, run_mock):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            container = root / "app-container"
            container.mkdir()
            run_mock.side_effect = [
                subprocess.CompletedProcess([], 0, "", ""),
                subprocess.CompletedProcess([], 0, "", ""),
                subprocess.CompletedProcess([], 0, f"{container}\n", ""),
            ]

            resolved = MODULE.resolve_app_data_container(
                "simulator-id",
                root / "observer.log",
                30,
            )

            self.assertEqual(resolved, container)
            self.assertEqual(
                [call.args[0][:4] for call in run_mock.call_args_list],
                [
                    ["xcrun", "simctl", "boot", "simulator-id"],
                    ["xcrun", "simctl", "bootstatus", "simulator-id"],
                    ["xcrun", "simctl", "get_app_container", "simulator-id"],
                ],
            )

    @mock.patch.object(MODULE.subprocess, "run")
    def test_resolve_fails_when_simulator_cannot_become_ready(self, run_mock):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            run_mock.side_effect = [
                subprocess.CompletedProcess([], 0, "", "already booted"),
                subprocess.CompletedProcess([], 1, "", "boot failed"),
            ]

            with self.assertRaisesRegex(SystemExit, "failed to become ready"):
                MODULE.resolve_app_data_container(
                    "simulator-id",
                    root / "observer.log",
                    30,
                )


class ProcessGroupTimeoutTests(unittest.TestCase):
    def test_timeout_terminates_descendants(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            child_pid_path = root / "child.pid"
            script = root / "spawn-descendant.py"
            script.write_text(
                "import os, subprocess, sys, time\n"
                "child_code = \"import os, signal, sys, time; signal.signal(signal.SIGTERM, signal.SIG_IGN); "
                "open(sys.argv[1], 'w').write(str(os.getpid())); time.sleep(60)\"\n"
                "child = subprocess.Popen([sys.executable, '-c', child_code, sys.argv[1]])\n"
                "while not os.path.exists(sys.argv[1]): time.sleep(0.01)\n"
                "time.sleep(60)\n"
            )

            with self.assertRaisesRegex(SystemExit, "timed out"):
                MODULE.run(
                    [sys.executable, str(script), str(child_pid_path)],
                    root / "observer.log",
                    timeout=1,
                )

            child_pid = int(child_pid_path.read_text())
            deadline = time.monotonic() + 2
            while time.monotonic() < deadline:
                status = subprocess.run(
                    ["ps", "-p", str(child_pid), "-o", "stat="],
                    capture_output=True,
                    text=True,
                    check=False,
                ).stdout.strip()
                if not status or status.startswith("Z"):
                    break
                time.sleep(0.05)
            else:
                os.kill(child_pid, signal.SIGKILL)
                self.fail("observer timeout left a live descendant process")


if __name__ == "__main__":
    unittest.main()
