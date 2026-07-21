#!/usr/bin/env python3

import argparse
import json
import os
import plistlib
import shutil
import subprocess
import sys
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
        try:
            result = subprocess.run(
                command,
                stdout=output,
                stderr=subprocess.STDOUT,
                timeout=timeout,
                check=False,
            )
        except subprocess.TimeoutExpired:
            fail(f"command timed out after {timeout} seconds; see {log}")
    if result.returncode != 0 and not allow_failure:
        fail(f"command exited {result.returncode}; see {log}")
    return result.returncode


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
    if observed_dynamic_type != expected_dynamic_type:
        fail(
            "Dynamic Type mismatch: "
            f"requested {requested_content_size}, app observed {observed_dynamic_type}"
        )
    evidence["observedContentSizeCategory"] = requested_content_size
    evidence["observedDynamicTypeSize"] = observed_dynamic_type


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--xctestrun", required=True, type=Path)
    parser.add_argument("--app", required=True, type=Path)
    parser.add_argument("--runner", required=True, type=Path)
    parser.add_argument("--destination-udid", required=True)
    parser.add_argument("--platform", required=True, choices=("ios", "ipad"))
    parser.add_argument("--route", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--screenshot-output", type=Path)
    parser.add_argument("--deep-scroll-screenshot-output", type=Path)
    parser.add_argument("--work-root", required=True, type=Path)
    parser.add_argument("--log", required=True, type=Path)
    parser.add_argument("--timeout-seconds", type=int, default=180)
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
    if not app_proof_value or not requested_content_size:
        fail("actual Dynamic Type attestation requires app proof and requested category paths")
    attest_observed_dynamic_type(evidence, Path(app_proof_value), requested_content_size)
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    if arguments.screenshot_output:
        screenshots = observed_screenshot_files(attachments)
        if len(screenshots) != 1:
            fail(f"expected one initial observed screenshot, found {len(screenshots)}; see {attachments}")
        arguments.screenshot_output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(screenshots[0], arguments.screenshot_output)
    deep_scroll = evidence.get("deepScroll")
    if isinstance(deep_scroll, dict):
        if not arguments.deep_scroll_screenshot_output:
            fail("deep-scroll evidence requires a sealed deep-scroll screenshot output")
        deep_screenshots = deep_scroll_screenshot_files(attachments)
        if len(deep_screenshots) != 1:
            fail(f"expected one deep-scroll screenshot, found {len(deep_screenshots)}; see {attachments}")
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
