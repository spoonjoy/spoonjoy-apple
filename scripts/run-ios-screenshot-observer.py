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
import uuid
from pathlib import Path


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


def attest_observed_dynamic_type(
    evidence: dict,
    app_proof_path: Path,
    requested_content_size: str,
) -> None:
    expected_dynamic_type = {
        "large": "large",
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
    configure_xctestrun(source_xctestrun, configured_xctestrun, app, runner, environment)

    test_status = run(
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
        allow_failure=True,
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
    screenshots = observed_screenshot_files(attachments)
    if len(screenshots) != 1:
        fail(f"expected one initial observed screenshot, found {len(screenshots)}; see {attachments}")
    attest_exported_screenshot(evidence, screenshots[0], "screenshotSHA256")
    deep_scroll = evidence.get("deepScroll")
    deep_screenshots: list[Path] = []
    if isinstance(deep_scroll, dict):
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
        attest_exported_screenshot(deep_scroll, deep_screenshots[0], "screenshotSHA256")
    arguments.readiness_proof_output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(app_proof_path, arguments.readiness_proof_output)
    if isinstance(deep_scroll, dict):
        shutil.copyfile(
            deep_app_proof_path,
            deep_readiness_proof_output(arguments.readiness_proof_output),
        )
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    if arguments.screenshot_output:
        arguments.screenshot_output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(screenshots[0], arguments.screenshot_output)
    if isinstance(deep_scroll, dict):
        if not arguments.deep_scroll_screenshot_output:
            fail("deep-scroll evidence requires a sealed deep-scroll screenshot output")
        arguments.deep_scroll_screenshot_output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(deep_screenshots[0], arguments.deep_scroll_screenshot_output)
    elif arguments.deep_scroll_screenshot_output:
        fail("deep-scroll screenshot output was requested without deep-scroll evidence")
    product_findings = list(evidence.get("auditIssues", [])) + list(evidence.get("geometryFindings", []))
    if isinstance(deep_scroll, dict):
        product_findings.extend(deep_scroll.get("findings", []))
    if test_status != 0 and not product_findings:
        fail(f"test command exited {test_status} without classified product findings; see {arguments.log}")
    outcome = "captured product findings" if product_findings else "ok"
    print(f"iOS observed screenshot evidence {outcome}: {arguments.output}")


if __name__ == "__main__":
    main()
