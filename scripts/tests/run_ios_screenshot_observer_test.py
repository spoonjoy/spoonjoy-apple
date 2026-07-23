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
    def test_attests_full_initial_and_deep_scroll_visual_audits(self):
        evidence = {"auditTypes": sorted(MODULE.REQUIRED_AUDIT_TYPES)}

        MODULE.attest_audit_types(evidence, "initial")
        MODULE.attest_audit_types(evidence, "deepScroll")

    def test_rejects_deep_scroll_without_text_clipping_audit(self):
        evidence = {
            "auditTypes": sorted(MODULE.REQUIRED_AUDIT_TYPES - {"textClipped"})
        }

        with self.assertRaisesRegex(SystemExit, "deepScroll accessibility audit"):
            MODULE.attest_audit_types(evidence, "deepScroll")

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

    def test_records_xxx_large_from_the_app_proof(self):
        with tempfile.TemporaryDirectory() as directory:
            proof = self.write_proof(Path(directory), "xxxLarge")
            evidence = {}

            MODULE.attest_observed_dynamic_type(
                evidence,
                proof,
                "extra-extra-extra-large",
            )

            self.assertEqual(
                evidence["observedContentSizeCategory"],
                "extra-extra-extra-large",
            )
            self.assertEqual(evidence["observedDynamicTypeSize"], "xxxLarge")

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
    def host_process_observation(self, process_identifier: int = 4312) -> dict:
        return {
            "schema": "iosHostProcessObservationV1",
            "applicationBundleIdentifier": "app.spoonjoy",
            "applicationProcessIdentifier": process_identifier,
            "launchctlLabel": "UIKitApplication:app.spoonjoy[fixture]",
            "sampleCount": 8,
        }

    def pixel_accessibility_binding(
        self,
        capture_id: str,
        screenshot_sha256: str,
        capture_phase: str = "initial",
    ) -> dict:
        deep = capture_phase == "deepScroll"
        return {
            "schema": "iosPixelAccessibilityBindingV1",
            "captureID": capture_id,
            "capturePhase": capture_phase,
            "pixelSource": "mainScreen",
            "screenshotSHA256": screenshot_sha256,
            "accessibilitySnapshotBeforeSHA256": "a" * 64,
            "accessibilitySnapshotAfterSHA256": "a" * 64,
            "windowFrame": {"x": 0, "y": 0, "width": 390, "height": 844},
            "selectedScrollHierarchyIdentifier": "spoonjoy.page-scroll" if deep else None,
            "selectedScrollHierarchySnapshotBeforeSHA256": "b" * 64 if deep else None,
            "selectedScrollHierarchySnapshotAfterSHA256": "b" * 64 if deep else None,
        }

    def capture_identity(
        self,
        capture_id: str = "4bd46f3c-5d3d-4c9f-9dd2-16dd476f4355",
        screenshot_sha256: str = "c" * 64,
        capture_phase: str = "initial",
    ) -> dict:
        return {
            "captureID": capture_id,
            "capturePhase": capture_phase,
            "screenshotSHA256": screenshot_sha256,
        }

    def test_pixel_accessibility_binding_rejects_every_missing_or_extra_schema_field(self):
        identity = self.capture_identity()
        binding = self.pixel_accessibility_binding(
            identity["captureID"], identity["screenshotSHA256"]
        )

        for field in tuple(binding):
            malformed = dict(binding)
            malformed.pop(field)
            with self.subTest(missing=field):
                with self.assertRaisesRegex(SystemExit, "missing or malformed"):
                    MODULE.attest_pixel_accessibility_binding(
                        {"pixelAccessibilityBinding": malformed}, identity, "initial"
                    )

        with self.assertRaisesRegex(SystemExit, "missing or malformed"):
            MODULE.attest_pixel_accessibility_binding(
                {"pixelAccessibilityBinding": {**binding, "unexpected": True}},
                identity,
                "initial",
            )

    def test_pixel_accessibility_binding_rejects_malformed_initial_and_deep_hierarchy_fields(self):
        initial_identity = self.capture_identity()
        initial_binding = self.pixel_accessibility_binding(
            initial_identity["captureID"], initial_identity["screenshotSHA256"]
        )
        for field in (
            "selectedScrollHierarchyIdentifier",
            "selectedScrollHierarchySnapshotBeforeSHA256",
            "selectedScrollHierarchySnapshotAfterSHA256",
        ):
            malformed = dict(initial_binding)
            malformed[field] = "forged"
            with self.subTest(initial_field=field):
                with self.assertRaisesRegex(SystemExit, "must not claim"):
                    MODULE.attest_pixel_accessibility_binding(
                        {"pixelAccessibilityBinding": malformed},
                        initial_identity,
                        "initial",
                    )

        deep_identity = self.capture_identity(capture_phase="deepScroll")
        deep_binding = self.pixel_accessibility_binding(
            deep_identity["captureID"],
            deep_identity["screenshotSHA256"],
            capture_phase="deepScroll",
        )
        for field in (
            "selectedScrollHierarchyIdentifier",
            "selectedScrollHierarchySnapshotBeforeSHA256",
            "selectedScrollHierarchySnapshotAfterSHA256",
        ):
            malformed = dict(deep_binding)
            malformed[field] = None
            with self.subTest(deep_field=field):
                with self.assertRaisesRegex(SystemExit, "selected hierarchy"):
                    MODULE.attest_pixel_accessibility_binding(
                        {"pixelAccessibilityBinding": malformed},
                        deep_identity,
                        "deepScroll",
                    )

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

    def test_attests_capture_identity_to_exact_foreground_process_and_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            screenshot = Path(directory) / "observed.png"
            screenshot.write_bytes(b"exact-png-bytes")
            digest = hashlib.sha256(screenshot.read_bytes()).hexdigest()
            evidence = {
                "screenshotSHA256": digest,
                "captureIdentity": {
                    "schema": "iosObservedCaptureV1",
                    "captureID": "4bd46f3c-5d3d-4c9f-9dd2-16dd476f4355",
                    "captureRunNonce": "7238f644-ff7a-4c1a-a9aa-60dd478c1c1d",
                    "capturePhase": "initial",
                    "applicationBundleIdentifier": "app.spoonjoy",
                    "applicationProcessIdentifier": 4312,
                    "foregroundBeforeCapture": True,
                    "foregroundAfterCapture": True,
                    "screenshotSHA256": digest,
                },
            }
            evidence["pixelAccessibilityBinding"] = self.pixel_accessibility_binding(
                evidence["captureIdentity"]["captureID"], digest
            )

            identity = MODULE.attest_capture_identity(
                evidence,
                screenshot,
                expected_run_nonce="7238f644-ff7a-4c1a-a9aa-60dd478c1c1d",
                expected_phase="initial",
                host_process_observation=self.host_process_observation(),
            )

            self.assertEqual(identity["applicationProcessIdentifier"], 4312)

    def test_rejects_coherently_substituted_capture_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            screenshot = Path(directory) / "observed.png"
            screenshot.write_bytes(b"exact-png-bytes")
            digest = hashlib.sha256(screenshot.read_bytes()).hexdigest()
            base_identity = {
                "schema": "iosObservedCaptureV1",
                "captureID": "4bd46f3c-5d3d-4c9f-9dd2-16dd476f4355",
                "captureRunNonce": "7238f644-ff7a-4c1a-a9aa-60dd478c1c1d",
                "capturePhase": "initial",
                "applicationBundleIdentifier": "app.spoonjoy",
                "applicationProcessIdentifier": 4312,
                "foregroundBeforeCapture": True,
                "foregroundAfterCapture": True,
                "screenshotSHA256": digest,
            }
            substitutions = [
                {**base_identity, "captureID": "not-a-uuid"},
                {**base_identity, "captureRunNonce": "dd9e30cb-630f-4b4d-99b4-9ed82b80a7f2"},
                {**base_identity, "capturePhase": "deepScroll"},
                {**base_identity, "applicationBundleIdentifier": "com.apple.springboard"},
                {**base_identity, "applicationProcessIdentifier": 0},
                {**base_identity, "foregroundBeforeCapture": False},
                {**base_identity, "foregroundAfterCapture": False},
                {**base_identity, "screenshotSHA256": "0" * 64},
            ]

            for identity in substitutions:
                with self.subTest(identity=identity):
                    with self.assertRaises(SystemExit):
                        MODULE.attest_capture_identity(
                            {
                                "screenshotSHA256": digest,
                                "captureIdentity": identity,
                                "pixelAccessibilityBinding": self.pixel_accessibility_binding(
                                    identity["captureID"], identity["screenshotSHA256"]
                                ),
                            },
                            screenshot,
                            expected_run_nonce=base_identity["captureRunNonce"],
                            expected_phase="initial",
                            host_process_observation=self.host_process_observation(),
                        )

    def test_publishes_only_attested_bytes_atomically(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "attachment.png"
            destination = root / "sealed" / "ios-mobile.png"
            source.write_bytes(b"exact-png-bytes")
            digest = hashlib.sha256(source.read_bytes()).hexdigest()
            evidence = {
                "screenshotSHA256": digest,
                "captureIdentity": {
                    "schema": "iosObservedCaptureV1",
                    "captureID": "4bd46f3c-5d3d-4c9f-9dd2-16dd476f4355",
                    "captureRunNonce": "7238f644-ff7a-4c1a-a9aa-60dd478c1c1d",
                    "capturePhase": "initial",
                    "applicationBundleIdentifier": "app.spoonjoy",
                    "applicationProcessIdentifier": 4312,
                    "foregroundBeforeCapture": True,
                    "foregroundAfterCapture": True,
                    "screenshotSHA256": digest,
                },
            }
            evidence["pixelAccessibilityBinding"] = self.pixel_accessibility_binding(
                evidence["captureIdentity"]["captureID"], digest
            )

            MODULE.publish_attested_screenshot(
                evidence,
                source,
                destination,
                expected_run_nonce="7238f644-ff7a-4c1a-a9aa-60dd478c1c1d",
                expected_phase="initial",
                host_process_observation=self.host_process_observation(),
            )

            self.assertEqual(destination.read_bytes(), source.read_bytes())
            self.assertEqual(list(destination.parent.glob(".*.tmp-*")), [])


class TargetProcessObservationTests(unittest.TestCase):
    def test_parses_only_the_exact_spoonjoy_uikit_application_label(self):
        output = "\n".join(
            [
                "4311\t0\tUIKitApplication:app.spoonjoy.preview[fixture]",
                "4312\t0\tUIKitApplication:app.spoonjoy[fixture]",
                "4313\t0\tUIKitApplication:app.spoonjoy.widget[fixture]",
            ]
        )

        self.assertEqual(
            MODULE.parse_exact_simulator_application_processes(output, "app.spoonjoy"),
            {(4312, "UIKitApplication:app.spoonjoy[fixture]")},
        )

    def test_rejects_ambiguous_exact_spoonjoy_processes(self):
        output = "\n".join(
            [
                "4312\t0\tUIKitApplication:app.spoonjoy[first]",
                "4314\t0\tUIKitApplication:app.spoonjoy[second]",
            ]
        )

        with self.assertRaisesRegex(SystemExit, "multiple exact app.spoonjoy"):
            MODULE.require_single_host_process_observation(
                MODULE.parse_exact_simulator_application_processes(output, "app.spoonjoy")
            )

    def test_rejects_coherently_substituted_positive_self_attested_pid(self):
        host_observation = {
            "schema": "iosHostProcessObservationV1",
            "applicationBundleIdentifier": "app.spoonjoy",
            "applicationProcessIdentifier": 4312,
            "launchctlLabel": "UIKitApplication:app.spoonjoy[fixture]",
            "sampleCount": 8,
        }

        with self.assertRaisesRegex(SystemExit, "host-observed target process"):
            MODULE.attest_host_process_binding(
                {
                    "applicationBundleIdentifier": "app.spoonjoy",
                    "applicationProcessIdentifier": 9999,
                },
                host_observation,
                "initial",
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
