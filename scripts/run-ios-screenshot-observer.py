#!/usr/bin/env python3

import argparse
import hashlib
import json
import os
import plistlib
import re
import signal
import shutil
import subprocess
import sys
import time
import uuid
from pathlib import Path

REQUIRED_AUDIT_TYPES = {
    "contrast",
    "dynamicType",
    "textClipped",
    "hitRegion",
    "trait",
}


def fail(message: str) -> None:
    raise SystemExit(f"iOS screenshot observer error: {message}")


def parse_environment(values: list[str]) -> dict[str, str]:
    environment: dict[str, str] = {}
    for value in values:
        key, separator, item = value.partition("=")
        if not separator or not key.startswith("SPOONJOY_"):
            fail(f"invalid observed app environment entry: {value!r}")
        environment[key] = item
    return environment


def load_test_configuration(path: Path) -> tuple[dict, dict]:
    with path.open("rb") as handle:
        payload = plistlib.load(handle)
    candidates = [
        configuration
        for configuration in payload.values()
        if isinstance(configuration, dict)
        and "SpoonjoyUITests" in str(configuration.get("TestBundlePath", ""))
    ]
    if len(candidates) != 1:
        fail(f"expected one SpoonjoyUITests configuration in {path}, found {len(candidates)}")
    return payload, candidates[0]


def configure_xctestrun(
    source: Path,
    destination: Path,
    app: Path,
    runner: Path,
    environment: dict[str, str],
) -> None:
    payload, configuration = load_test_configuration(source)
    test_bundle = runner / "PlugIns" / "SpoonjoyUITests.xctest"
    test_host = runner / "SpoonjoyUITests-Runner"
    for required in (app, runner, test_bundle, test_host):
        if not required.exists():
            fail(f"sealed observer product is missing: {required}")

    configuration["EnvironmentVariables"] = {
        **configuration.get("EnvironmentVariables", {}),
        **environment,
    }
    configuration["UITargetAppPath"] = str(app)
    configuration["TestBundlePath"] = str(test_bundle)
    configuration["TestHostPath"] = str(test_host)
    configuration["DependentProductPaths"] = [str(app), str(runner), str(test_bundle)]
    configuration["IsAppHostedTestBundle"] = True

    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("wb") as handle:
        plistlib.dump(payload, handle, sort_keys=True)


def run(command: list[str], log: Path, timeout: int, allow_failure: bool = False) -> int:
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open("ab") as output:
        output.write(("running: " + " ".join(command) + "\n").encode())
        process = subprocess.Popen(
            command,
            stdout=output,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
        try:
            return_code = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGTERM)
                process.wait(timeout=1)
            except (ProcessLookupError, PermissionError, subprocess.TimeoutExpired):
                pass
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except (ProcessLookupError, PermissionError):
                pass
            if process.poll() is None:
                process.wait()
            fail(f"command timed out after {timeout} seconds; see {log}")
    if return_code != 0 and not allow_failure:
        fail(f"command exited {return_code}; see {log}")
    return return_code


def parse_exact_simulator_application_processes(
    output: str,
    bundle_identifier: str,
) -> set[tuple[int, str]]:
    exact_label = re.compile(
        rf"\AUIKitApplication:{re.escape(bundle_identifier)}(?:\[[^\]\r\n]+\])*\Z"
    )
    matches: set[tuple[int, str]] = set()
    for line in output.splitlines():
        fields = line.split("\t")
        if len(fields) < 3:
            continue
        pid_text, label = fields[0].strip(), fields[-1].strip()
        if not exact_label.fullmatch(label) or not pid_text.isdecimal():
            continue
        pid = int(pid_text)
        if pid > 0:
            matches.add((pid, label))
    return matches


def require_single_host_process_observation(
    observations: set[tuple[int, str]],
) -> tuple[int, str]:
    process_identifiers = {pid for pid, _ in observations}
    if not process_identifiers:
        fail("no exact app.spoonjoy target process was independently observed")
    if len(process_identifiers) != 1:
        fail("multiple exact app.spoonjoy target processes were independently observed")
    process_identifier = next(iter(process_identifiers))
    labels = sorted(label for pid, label in observations if pid == process_identifier)
    if len(set(labels)) != 1:
        fail("the exact app.spoonjoy launchctl label changed during capture")
    return process_identifier, labels[0]


def run_test_with_target_process_observation(
    command: list[str],
    log: Path,
    timeout: int,
    *,
    destination_udid: str,
    simulator_arch: str,
) -> tuple[int, dict]:
    log.parent.mkdir(parents=True, exist_ok=True)
    observations: set[tuple[int, str]] = set()
    sample_count = 0
    deadline = time.monotonic() + timeout
    with log.open("ab") as output:
        output.write(("running: " + " ".join(command) + "\n").encode())
        output.write(
            (
                "observing: xcrun simctl spawn -a "
                f"{simulator_arch} {destination_udid} launchctl list\n"
            ).encode()
        )
        process = subprocess.Popen(
            command,
            stdout=output,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
        try:
            while process.poll() is None:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise subprocess.TimeoutExpired(command, timeout)
                try:
                    probe = subprocess.run(
                        [
                            "xcrun",
                            "simctl",
                            "spawn",
                            "-a",
                            simulator_arch,
                            destination_udid,
                            "launchctl",
                            "list",
                        ],
                        capture_output=True,
                        text=True,
                        timeout=min(2.0, remaining),
                        check=False,
                    )
                except subprocess.TimeoutExpired:
                    probe = None
                if probe is not None and probe.returncode == 0:
                    exact = parse_exact_simulator_application_processes(
                        probe.stdout,
                        "app.spoonjoy",
                    )
                    if exact:
                        sample_count += 1
                        observations.update(exact)
                time.sleep(0.05)
            return_code = process.wait()
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGTERM)
                process.wait(timeout=1)
            except (ProcessLookupError, PermissionError, subprocess.TimeoutExpired):
                pass
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except (ProcessLookupError, PermissionError):
                pass
            if process.poll() is None:
                process.wait()
            fail(f"command timed out after {timeout} seconds; see {log}")

    process_identifier, launchctl_label = require_single_host_process_observation(
        observations
    )
    if sample_count < 2:
        fail("exact app.spoonjoy target process was not independently observed twice")
    return return_code, {
        "schema": "iosHostProcessObservationV1",
        "applicationBundleIdentifier": "app.spoonjoy",
        "applicationProcessIdentifier": process_identifier,
        "launchctlLabel": launchctl_label,
        "sampleCount": sample_count,
    }


def attest_host_process_binding(
    identity: dict,
    host_observation: dict,
    capture_phase: str,
) -> None:
    expected_fields = {
        "schema",
        "applicationBundleIdentifier",
        "applicationProcessIdentifier",
        "launchctlLabel",
        "sampleCount",
    }
    if not isinstance(host_observation, dict) or set(host_observation) != expected_fields:
        fail("host-observed target process evidence is missing or malformed")
    if host_observation.get("schema") != "iosHostProcessObservationV1":
        fail("host-observed target process schema mismatch")
    if host_observation.get("applicationBundleIdentifier") != "app.spoonjoy":
        fail("host-observed target process bundle mismatch")
    label = host_observation.get("launchctlLabel")
    if not isinstance(label, str) or not re.fullmatch(
        r"UIKitApplication:app\.spoonjoy(?:\[[^\]\r\n]+\])*",
        label,
    ):
        fail("host-observed target process launchctl label mismatch")
    process_identifier = host_observation.get("applicationProcessIdentifier")
    if isinstance(process_identifier, bool) or not isinstance(process_identifier, int) or process_identifier <= 0:
        fail("host-observed target process identity is invalid")
    sample_count = host_observation.get("sampleCount")
    if isinstance(sample_count, bool) or not isinstance(sample_count, int) or sample_count < 2:
        fail("host-observed target process needs at least two independent samples")
    if identity.get("applicationBundleIdentifier") != host_observation["applicationBundleIdentifier"]:
        fail(f"{capture_phase} capture does not match the host-observed target process bundle")
    if identity.get("applicationProcessIdentifier") != process_identifier:
        fail(f"{capture_phase} capture does not match the host-observed target process")


def attest_pixel_accessibility_binding(
    evidence: dict,
    identity: dict,
    capture_phase: str,
) -> None:
    binding = evidence.get("pixelAccessibilityBinding")
    expected_fields = {
        "schema",
        "captureID",
        "capturePhase",
        "pixelSource",
        "screenshotSHA256",
        "accessibilitySnapshotBeforeSHA256",
        "accessibilitySnapshotAfterSHA256",
        "windowFrame",
        "selectedScrollHierarchyIdentifier",
        "selectedScrollHierarchySnapshotBeforeSHA256",
        "selectedScrollHierarchySnapshotAfterSHA256",
    }
    if not isinstance(binding, dict) or set(binding) != expected_fields:
        fail(f"{capture_phase} pixel/accessibility binding is missing or malformed")
    if binding.get("schema") != "iosPixelAccessibilityBindingV1":
        fail(f"{capture_phase} pixel/accessibility binding schema mismatch")
    if binding.get("captureID") != identity.get("captureID"):
        fail(f"{capture_phase} pixel/accessibility binding capture ID mismatch")
    if binding.get("capturePhase") != capture_phase:
        fail(f"{capture_phase} pixel/accessibility binding phase mismatch")
    if binding.get("pixelSource") != "mainScreen":
        fail(f"{capture_phase} pixel/accessibility binding source mismatch")
    if binding.get("screenshotSHA256") != identity.get("screenshotSHA256"):
        fail(f"{capture_phase} pixel/accessibility binding screenshot mismatch")
    before_digest = binding.get("accessibilitySnapshotBeforeSHA256")
    after_digest = binding.get("accessibilitySnapshotAfterSHA256")
    if (
        not isinstance(before_digest, str)
        or not re.fullmatch(r"[0-9a-f]{64}", before_digest)
        or before_digest != after_digest
    ):
        fail(f"{capture_phase} accessibility tree was not stable across pixel capture")
    frame = binding.get("windowFrame")
    if not isinstance(frame, dict) or set(frame) != {"x", "y", "width", "height"}:
        fail(f"{capture_phase} pixel/accessibility binding window frame is malformed")
    values = list(frame.values())
    if (
        any(isinstance(value, bool) or not isinstance(value, (int, float)) for value in values)
        or not all(float(value) == float(value) and abs(float(value)) != float("inf") for value in values)
        or frame["width"] <= 0
        or frame["height"] <= 0
    ):
        fail(f"{capture_phase} pixel/accessibility binding window frame is invalid")
    hierarchy_identifier = binding.get("selectedScrollHierarchyIdentifier")
    hierarchy_before = binding.get("selectedScrollHierarchySnapshotBeforeSHA256")
    hierarchy_after = binding.get("selectedScrollHierarchySnapshotAfterSHA256")
    if capture_phase == "initial":
        if hierarchy_identifier is not None or hierarchy_before is not None or hierarchy_after is not None:
            fail("initial capture must not claim a selected scroll hierarchy")
    elif (
        hierarchy_identifier != "spoonjoy.page-scroll"
        or not isinstance(hierarchy_before, str)
        or not re.fullmatch(r"[0-9a-f]{64}", hierarchy_before)
        or hierarchy_before != hierarchy_after
    ):
        fail("deepScroll selected hierarchy was not stable across pixel capture")


def observed_evidence_files(root: Path, platform: str, route: str) -> list[Path]:
    matches: list[Path] = []
    for candidate in root.rglob("*"):
        if not candidate.is_file():
            continue
        try:
            payload = json.loads(candidate.read_text())
        except (UnicodeDecodeError, json.JSONDecodeError, OSError):
            continue
        if not isinstance(payload, dict):
            continue
        if (
            payload.get("platform") == platform
            and payload.get("route") == route
            and isinstance(payload.get("elements"), list)
            and isinstance(payload.get("auditIssues"), list)
            and isinstance(payload.get("geometryFindings"), list)
        ):
            matches.append(candidate)
    return matches


def screenshot_attachment_files(root: Path, suggested_name_prefix: str) -> list[Path]:
    manifest_path = root / "manifest.json"
    try:
        manifest = json.loads(manifest_path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        fail(f"invalid attachment manifest: {error}")
    matches: list[Path] = []
    for test in manifest if isinstance(manifest, list) else []:
        for attachment in test.get("attachments", []) if isinstance(test, dict) else []:
            if str(attachment.get("suggestedHumanReadableName", "")).startswith(
                suggested_name_prefix
            ):
                matches.append(root / str(attachment.get("exportedFileName", "")))
    return [match for match in matches if match.is_file()]


def observed_screenshot_files(root: Path) -> list[Path]:
    return screenshot_attachment_files(root, "observed-accessibility-screenshot_")


def deep_scroll_screenshot_files(root: Path) -> list[Path]:
    return screenshot_attachment_files(root, "deep-scroll-screenshot_")


def deep_scroll_waypoint_screenshot_files(root: Path, index: int) -> list[Path]:
    return screenshot_attachment_files(root, f"deep-scroll-waypoint-{index}-screenshot_")


def publish_waypoint_screenshots(
    deep_scroll: dict,
    attachments: Path,
    output: Path,
    *,
    canonical_app_proof_path: Path,
    expected_run_nonce: str,
    expected_route: str,
    expected_platform: str,
    host_process_observation: dict,
) -> None:
    waypoints = deep_scroll.get("waypoints")
    swipe_count = deep_scroll.get("swipeCount")
    if not isinstance(swipe_count, int) or swipe_count < 0:
        fail("deep-scroll waypoint export requires a nonnegative swipeCount")
    if not isinstance(waypoints, list) or len(waypoints) != swipe_count:
        fail("deep-scroll waypoint export count does not match swipeCount")

    output.parent.mkdir(parents=True, exist_ok=True)
    for index, waypoint in enumerate(waypoints, start=1):
        if not isinstance(waypoint, dict) or waypoint.get("index") != index:
            fail(f"deep-scroll waypoint {index} evidence is malformed")
        file_name = waypoint.get("screenshotArtifactPath")
        expected_name = f"{output.stem}.deep-scroll-waypoint-{index}.png"
        if file_name != expected_name or Path(str(file_name)).name != file_name:
            fail(f"deep-scroll waypoint {index} screenshot artifact path is not canonical")
        sources = deep_scroll_waypoint_screenshot_files(attachments, index)
        if len(sources) != 1:
            fail(f"expected one deep-scroll waypoint {index} screenshot, found {len(sources)}")
        source = sources[0]
        phase = f"deepScrollWaypoint-{index}"
        if waypoint.get("capturePhase") != phase:
            fail(f"deep-scroll waypoint {index} capture phase mismatch")
        attest_audit_types(waypoint, phase)
        waypoint_proof_path = readiness_proof_path(
            canonical_app_proof_path,
            waypoint.get("readinessHandshake"),
        )
        attest_screenshot_readiness(
            waypoint,
            waypoint_proof_path,
            expected_run_nonce=expected_run_nonce,
            expected_route=expected_route,
            expected_platform=expected_platform,
        )
        attest_capture_identity(
            waypoint,
            source,
            expected_run_nonce=expected_run_nonce,
            expected_phase=phase,
            host_process_observation=host_process_observation,
        )
        attest_exported_screenshot(waypoint, source, "screenshotSHA256")
        expected_bytes = waypoint.get("screenshotBytes")
        if not isinstance(expected_bytes, int) or expected_bytes <= 0 or source.stat().st_size != expected_bytes:
            fail(f"deep-scroll waypoint {index} screenshot byte count mismatch")
        destination = output.parent / file_name
        if destination.is_symlink():
            fail(f"deep-scroll waypoint {index} destination must not be a symlink")
        temporary = destination.with_name(f".{destination.name}.{os.getpid()}.tmp")
        shutil.copyfile(source, temporary)
        os.replace(temporary, destination)
        attest_capture_identity(
            waypoint,
            destination,
            expected_run_nonce=expected_run_nonce,
            expected_phase=phase,
            host_process_observation=host_process_observation,
        )


def attest_exported_screenshot(evidence: dict, screenshot_path: Path, field: str) -> None:
    expected_sha256 = evidence.get(field)
    if not isinstance(expected_sha256, str) or not re.fullmatch(r"[0-9a-f]{64}", expected_sha256):
        fail(f"observed screenshot evidence is missing {field}")
    try:
        actual_sha256 = hashlib.sha256(screenshot_path.read_bytes()).hexdigest()
    except OSError:
        fail(f"observed screenshot attachment is unreadable: {screenshot_path}")
    if actual_sha256 != expected_sha256:
        fail(f"observed screenshot attachment SHA-256 mismatch for {field}")


def attest_audit_types(evidence: dict, phase: str) -> None:
    audit_types = evidence.get("auditTypes")
    if not isinstance(audit_types, list) or set(audit_types) != REQUIRED_AUDIT_TYPES:
        fail(
            f"{phase} accessibility audit must include contrast, dynamicType, "
            "textClipped, hitRegion, and trait"
        )


def attest_capture_identity(
    evidence: dict,
    screenshot_path: Path,
    *,
    expected_run_nonce: str,
    expected_phase: str,
    host_process_observation=None,
) -> dict:
    identity = evidence.get("captureIdentity")
    expected_fields = {
        "schema",
        "captureID",
        "captureRunNonce",
        "capturePhase",
        "applicationBundleIdentifier",
        "applicationProcessIdentifier",
        "foregroundBeforeCapture",
        "foregroundAfterCapture",
        "screenshotSHA256",
    }
    if not isinstance(identity, dict) or set(identity) != expected_fields:
        fail("observed screenshot capture identity is missing or malformed")
    capture_id = identity.get("captureID")
    try:
        canonical_capture_id = str(uuid.UUID(capture_id))
    except (AttributeError, TypeError, ValueError):
        fail("observed screenshot capture ID is not a UUID")
    if capture_id != canonical_capture_id:
        fail("observed screenshot capture ID is not canonical")
    if identity.get("schema") != "iosObservedCaptureV1":
        fail("observed screenshot capture identity schema mismatch")
    if identity.get("captureRunNonce") != expected_run_nonce:
        fail("observed screenshot capture run nonce mismatch")
    if identity.get("capturePhase") != expected_phase:
        fail("observed screenshot capture phase mismatch")
    if identity.get("applicationBundleIdentifier") != "app.spoonjoy":
        fail("observed screenshot application bundle mismatch")
    process_identifier = identity.get("applicationProcessIdentifier")
    if isinstance(process_identifier, bool) or not isinstance(process_identifier, int) or process_identifier <= 0:
        fail("observed screenshot application process identity is invalid")
    if identity.get("foregroundBeforeCapture") is not True:
        fail("Spoonjoy was not foreground before the observed screenshot capture")
    if identity.get("foregroundAfterCapture") is not True:
        fail("Spoonjoy was not foreground after the observed screenshot capture")
    expected_digest = identity.get("screenshotSHA256")
    if evidence.get("screenshotSHA256") != expected_digest:
        fail("observed screenshot evidence and capture identity SHA-256 mismatch")
    attest_exported_screenshot(identity, screenshot_path, "screenshotSHA256")
    attest_pixel_accessibility_binding(evidence, identity, expected_phase)
    if host_process_observation is None:
        fail("observed screenshot capture is missing independent host process evidence")
    attest_host_process_binding(identity, host_process_observation, expected_phase)
    return identity


def publish_attested_screenshot(
    evidence: dict,
    source: Path,
    destination: Path,
    *,
    expected_run_nonce: str,
    expected_phase: str,
    host_process_observation: dict,
) -> None:
    attest_capture_identity(
        evidence,
        source,
        expected_run_nonce=expected_run_nonce,
        expected_phase=expected_phase,
        host_process_observation=host_process_observation,
    )
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_name(f".{destination.name}.tmp-{uuid.uuid4()}")
    try:
        shutil.copyfile(source, temporary)
        attest_capture_identity(
            evidence,
            temporary,
            expected_run_nonce=expected_run_nonce,
            expected_phase=expected_phase,
            host_process_observation=host_process_observation,
        )
        os.replace(temporary, destination)
        attest_capture_identity(
            evidence,
            destination,
            expected_run_nonce=expected_run_nonce,
            expected_phase=expected_phase,
            host_process_observation=host_process_observation,
        )
    finally:
        temporary.unlink(missing_ok=True)


def attest_observed_dynamic_type(
    evidence: dict,
    app_proof_path: Path,
    requested_content_size: str,
) -> None:
    expected_dynamic_type = {
        "large": "large",
        "extra-extra-extra-large": "xxxLarge",
        "accessibility-extra-extra-extra-large": "accessibility5",
    }.get(requested_content_size)
    if expected_dynamic_type is None:
        fail(f"unsupported requested Dynamic Type category: {requested_content_size!r}")
    try:
        app_proof = json.loads(app_proof_path.read_text())
        observed_dynamic_type = app_proof["observedDynamicTypeSize"]
    except (OSError, json.JSONDecodeError, KeyError, TypeError):
        fail(f"actual Dynamic Type proof is missing or invalid: {app_proof_path}")
    if not isinstance(observed_dynamic_type, str) or not observed_dynamic_type:
        fail(f"actual Dynamic Type proof is missing or invalid: {app_proof_path}")
    visual_readiness = app_proof.get("visualReadiness")
    if (
        not isinstance(visual_readiness, dict)
        or visual_readiness.get("pendingMediaCount") != 0
        or visual_readiness.get("failedMediaCount") != 0
        or visual_readiness.get("blockingIndicatorCount") != 0
        or visual_readiness.get("isSettled") is not True
    ):
        fail(f"actual visual readiness proof is unsettled or failed: {app_proof_path}")
    if observed_dynamic_type != expected_dynamic_type:
        fail(
            "Dynamic Type mismatch: "
            f"requested {requested_content_size}, app observed {observed_dynamic_type}"
        )
    evidence["observedContentSizeCategory"] = requested_content_size
    evidence["observedDynamicTypeSize"] = observed_dynamic_type


def attest_screenshot_readiness(
    evidence: dict,
    app_proof_path: Path,
    *,
    expected_run_nonce: str,
    expected_route: str,
    expected_platform: str,
) -> None:
    try:
        uuid.UUID(expected_run_nonce)
    except (ValueError, AttributeError):
        fail("screenshot run nonce is missing or invalid")
    try:
        proof_bytes = app_proof_path.read_bytes()
        proof = json.loads(proof_bytes)
    except (OSError, json.JSONDecodeError, TypeError):
        fail(f"screenshot readiness proof is missing or invalid: {app_proof_path}")
    handshake = evidence.get("readinessHandshake")
    if not isinstance(handshake, dict):
        fail("observed screenshot evidence is missing its readiness handshake")

    expected_fields = {
        "captureRunNonce": expected_run_nonce,
        "route": expected_route,
        "source": proof.get("source"),
    }
    for key, expected in expected_fields.items():
        field_name = "run nonce" if key == "captureRunNonce" else key
        if not isinstance(expected, str) or not expected or proof.get(key) != expected:
            fail(f"screenshot readiness proof {field_name} mismatch")
        if handshake.get(key) != expected:
            fail(f"screenshot readiness handshake {field_name} mismatch")
    if proof.get("platform") != expected_platform:
        fail("screenshot readiness proof platform mismatch")
    if proof.get("emittedBy") != "SpoonjoyApp" or proof.get("bundleIdentifier") != "app.spoonjoy":
        fail("screenshot readiness proof app identity mismatch")
    readiness_generation = handshake.get("readinessGeneration")
    if (
        not isinstance(readiness_generation, int)
        or readiness_generation < 0
        or proof.get("readinessGeneration") != readiness_generation
    ):
        fail("screenshot readiness generation mismatch")
    if handshake.get("proofFileName") != app_proof_path.name:
        fail("screenshot readiness proof filename mismatch")

    proof_sha256 = hashlib.sha256(proof_bytes).hexdigest()
    if handshake.get("proofSHA256") != proof_sha256:
        fail("screenshot readiness proof SHA-256 mismatch")


def readiness_proof_path(canonical_path: Path, handshake: dict) -> Path:
    if not isinstance(handshake, dict):
        fail("observed screenshot evidence is missing its readiness handshake")
    generation = handshake.get("readinessGeneration")
    filename = handshake.get("proofFileName")
    if not isinstance(generation, int) or generation < 0:
        fail("screenshot readiness generation is missing or invalid")
    expected_filename = (
        f"{canonical_path.stem}.generation-{generation}"
        f"{canonical_path.suffix or '.json'}"
    )
    if (
        not isinstance(filename, str)
        or not filename
        or Path(filename).name != filename
        or filename != expected_filename
    ):
        fail("screenshot readiness proof filename does not match its generation")
    return canonical_path.with_name(filename)


def deep_readiness_proof_output(path: Path) -> Path:
    return path.with_name(f"{path.stem}-deep-scroll{path.suffix or '.json'}")


def inline_app_proof_path(data_container: Path, configured_path: Path) -> Path:
    return (
        data_container
        / "Library"
        / "Application Support"
        / "Spoonjoy"
        / configured_path.name
    )


def resolve_app_data_container(destination_udid: str, log: Path, timeout: int) -> Path:
    try:
        boot_result = subprocess.run(
            ["xcrun", "simctl", "boot", destination_udid],
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        ready_result = subprocess.run(
            ["xcrun", "simctl", "bootstatus", destination_udid, "-b"],
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        if ready_result.returncode != 0:
            with log.open("ab") as output:
                output.write(b"running: xcrun simctl boot <device>\n")
                if boot_result.stderr:
                    output.write(boot_result.stderr.encode())
                output.write(b"running: xcrun simctl bootstatus <device> -b\n")
                if ready_result.stderr:
                    output.write(ready_result.stderr.encode())
            fail(f"simulator failed to become ready; see {log}")
        result = subprocess.run(
            [
                "xcrun",
                "simctl",
                "get_app_container",
                destination_udid,
                "app.spoonjoy",
                "data",
            ],
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
    except subprocess.TimeoutExpired:
        fail(f"simulator readiness or app data container lookup timed out; see {log}")
    with log.open("ab") as output:
        output.write(b"running: xcrun simctl boot <device>\n")
        if boot_result.stderr:
            output.write(boot_result.stderr.encode())
        output.write(b"running: xcrun simctl bootstatus <device> -b\n")
        if ready_result.stderr:
            output.write(ready_result.stderr.encode())
        output.write(b"running: xcrun simctl get_app_container <device> app.spoonjoy data\n")
        if result.stderr:
            output.write(result.stderr.encode())
    resolved = Path(result.stdout.strip())
    if result.returncode != 0 or not result.stdout.strip() or not resolved.is_dir():
        fail(f"current app data container lookup failed; see {log}")
    return resolved


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--xctestrun", required=True, type=Path)
    parser.add_argument("--app", required=True, type=Path)
    parser.add_argument("--runner", required=True, type=Path)
    parser.add_argument("--destination-udid", required=True)
    parser.add_argument("--platform", required=True, choices=("ios", "ipad"))
    parser.add_argument("--route", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--readiness-proof-output", required=True, type=Path)
    parser.add_argument("--screenshot-output", type=Path)
    parser.add_argument("--deep-scroll-screenshot-output", type=Path)
    parser.add_argument("--work-root", required=True, type=Path)
    parser.add_argument("--log", required=True, type=Path)
    parser.add_argument("--timeout-seconds", type=int, default=300)
    parser.add_argument("--simulator-arch", required=True)
    parser.add_argument("--environment", action="append", default=[])
    parser.add_argument("--environment-json", type=Path)
    arguments = parser.parse_args()

    source_xctestrun = arguments.xctestrun.resolve(strict=True)
    app = arguments.app.resolve(strict=True)
    runner = arguments.runner.resolve(strict=True)
    environment = parse_environment(arguments.environment)
    if arguments.environment_json:
        try:
            file_environment = json.loads(arguments.environment_json.read_text())
        except (OSError, json.JSONDecodeError) as error:
            fail(f"invalid environment JSON: {error}")
        if not isinstance(file_environment, dict):
            fail("environment JSON must contain an object")
        for key, value in file_environment.items():
            if not isinstance(key, str) or not key.startswith("SPOONJOY_") or not isinstance(value, str):
                fail("environment JSON entries must be SPOONJOY_ string pairs")
        environment.update(file_environment)
    if environment.get("SPOONJOY_SCREENSHOT_EXPECTED_ROUTE") != arguments.route:
        fail("observed route does not match the app launch environment")

    work_root = arguments.work_root.resolve()
    if work_root.exists():
        shutil.rmtree(work_root)
    work_root.mkdir(parents=True)
    configured_xctestrun = work_root / "Spoonjoy-observed.xctestrun"
    result_bundle = work_root / "ObservedAccessibility.xcresult"
    attachments = work_root / "attachments"
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    environment["SPOONJOY_OBSERVED_ACCESSIBILITY_EVIDENCE_PATH"] = str(arguments.output.resolve())
    configure_xctestrun(source_xctestrun, configured_xctestrun, app, runner, environment)

    test_status, host_process_observation = run_test_with_target_process_observation(
        [
            "xcodebuild",
            "test-without-building",
            "-xctestrun",
            str(configured_xctestrun),
            "-destination",
            f"platform=iOS Simulator,id={arguments.destination_udid}",
            "-only-testing:SpoonjoyUITests/NativeScreenshotEvidenceTests/testObservedAccessibilityAndGeometry",
            "-resultBundlePath",
            str(result_bundle),
        ],
        arguments.log,
        arguments.timeout_seconds,
        destination_udid=arguments.destination_udid,
        simulator_arch=arguments.simulator_arch,
    )
    run(
        [
            "xcrun",
            "xcresulttool",
            "export",
            "attachments",
            "--path",
            str(result_bundle),
            "--output-path",
            str(attachments),
        ],
        arguments.log,
        60,
    )

    matches = observed_evidence_files(attachments, arguments.platform, arguments.route)
    if len(matches) != 1:
        fail(
            f"expected one {arguments.platform}/{arguments.route} observed evidence attachment, "
            f"found {len(matches)}; see {attachments}"
        )
    evidence = json.loads(matches[0].read_text())
    if "hostProcessObservation" in evidence:
        fail("UI-test evidence must not self-publish host process observation")
    evidence["hostProcessObservation"] = host_process_observation
    app_proof_value = environment.get("SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH")
    requested_content_size = environment.get("SPOONJOY_OBSERVED_CONTENT_SIZE_CATEGORY")
    capture_run_nonce = environment.get("SPOONJOY_SCREENSHOT_RUN_NONCE")
    if not app_proof_value or not requested_content_size or not capture_run_nonce:
        fail("screenshot readiness attestation requires app proof, requested category, and run nonce")
    canonical_app_proof_path = Path(app_proof_value)
    if environment.get("SPOONJOY_SCREENSHOT_INLINE_FIXTURES", "").strip().lower() in {
        "1",
        "true",
        "yes",
    }:
        data_container = resolve_app_data_container(
            arguments.destination_udid,
            arguments.log,
            min(arguments.timeout_seconds, 30),
        )
        canonical_app_proof_path = inline_app_proof_path(
            data_container,
            canonical_app_proof_path,
        )
    app_proof_path = readiness_proof_path(
        canonical_app_proof_path,
        evidence.get("readinessHandshake"),
    )
    attest_screenshot_readiness(
        evidence,
        app_proof_path,
        expected_run_nonce=capture_run_nonce,
        expected_route=arguments.route,
        expected_platform=arguments.platform,
    )
    attest_observed_dynamic_type(evidence, app_proof_path, requested_content_size)
    attest_audit_types(evidence, "initial")
    screenshots = observed_screenshot_files(attachments)
    if len(screenshots) != 1:
        fail(f"expected one initial observed screenshot, found {len(screenshots)}; see {attachments}")
    initial_capture_identity = attest_capture_identity(
        evidence,
        screenshots[0],
        expected_run_nonce=capture_run_nonce,
        expected_phase="initial",
        host_process_observation=host_process_observation,
    )
    deep_scroll = evidence.get("deepScroll")
    deep_screenshots: list[Path] = []
    if isinstance(deep_scroll, dict):
        attest_audit_types(deep_scroll, "deepScroll")
        deep_app_proof_path = readiness_proof_path(
            canonical_app_proof_path,
            deep_scroll.get("readinessHandshake"),
        )
        attest_screenshot_readiness(
            deep_scroll,
            deep_app_proof_path,
            expected_run_nonce=capture_run_nonce,
            expected_route=arguments.route,
            expected_platform=arguments.platform,
        )
        deep_screenshots = deep_scroll_screenshot_files(attachments)
        if len(deep_screenshots) != 1:
            fail(f"expected one deep-scroll screenshot, found {len(deep_screenshots)}; see {attachments}")
        deep_capture_identity = attest_capture_identity(
            deep_scroll,
            deep_screenshots[0],
            expected_run_nonce=capture_run_nonce,
            expected_phase="deepScroll",
            host_process_observation=host_process_observation,
        )
        if (
            deep_capture_identity["applicationProcessIdentifier"]
            != initial_capture_identity["applicationProcessIdentifier"]
        ):
            fail("initial and deep-scroll screenshots came from different app processes")
        if deep_capture_identity["captureID"] == initial_capture_identity["captureID"]:
            fail("initial and deep-scroll screenshots reused one capture ID")
        publish_waypoint_screenshots(
            deep_scroll,
            attachments,
            arguments.output,
            canonical_app_proof_path=canonical_app_proof_path,
            expected_run_nonce=capture_run_nonce,
            expected_route=arguments.route,
            expected_platform=arguments.platform,
            host_process_observation=host_process_observation,
        )
    arguments.readiness_proof_output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(app_proof_path, arguments.readiness_proof_output)
    if isinstance(deep_scroll, dict):
        shutil.copyfile(
            deep_app_proof_path,
            deep_readiness_proof_output(arguments.readiness_proof_output),
        )
    if arguments.screenshot_output:
        publish_attested_screenshot(
            evidence,
            screenshots[0],
            arguments.screenshot_output,
            expected_run_nonce=capture_run_nonce,
            expected_phase="initial",
            host_process_observation=host_process_observation,
        )
    if isinstance(deep_scroll, dict):
        if not arguments.deep_scroll_screenshot_output:
            fail("deep-scroll evidence requires a sealed deep-scroll screenshot output")
        publish_attested_screenshot(
            deep_scroll,
            deep_screenshots[0],
            arguments.deep_scroll_screenshot_output,
            expected_run_nonce=capture_run_nonce,
            expected_phase="deepScroll",
            host_process_observation=host_process_observation,
        )
    elif arguments.deep_scroll_screenshot_output:
        fail("deep-scroll screenshot output was requested without deep-scroll evidence")
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    product_findings = list(evidence.get("auditIssues", [])) + list(evidence.get("geometryFindings", []))
    if isinstance(deep_scroll, dict):
        product_findings.extend(deep_scroll.get("findings", []))
    if test_status != 0 and not product_findings:
        fail(f"test command exited {test_status} without classified product findings; see {arguments.log}")
    outcome = "captured product findings" if product_findings else "ok"
    print(f"iOS observed screenshot evidence {outcome}: {arguments.output}")


if __name__ == "__main__":
    main()
