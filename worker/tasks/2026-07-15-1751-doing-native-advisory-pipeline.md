# Native Advisory Pipeline Remediation

Status: in_progress
Execution Mode: direct

## Goal

Remediate audit Unit 16d/e/f by adding a pinned, fail-closed Ruby dependency advisory pipeline for the native repo.

## Scope

- Use a supported Ruby advisory scanner (`bundler-audit` unless disproven) pinned by version and artifact SHA.
- Scan the repo `Gemfile.lock` in CI and the local native validation matrix.
- Treat scanner update/network failures, actionable findings, missing lock coverage, and expired/invalid allowlists as failures.
- Document the policy and keep synthetic fixture coverage for every failure mode.

Out of scope: TestFlight publication, secret access, production operations, history rewrites, or weakening existing Swift/native validation gates.

## Units

### ✅ Unit 16d: Native Advisory Pipeline - Red Contracts
**What**: Add Ruby/workflow contract coverage for a pinned scanner, `Gemfile.lock` coverage, scanner/network failure, actionable finding failure, and explicit expiring allowlists.
**Output**: `scripts/check-native-advisory-pipeline.rb` and ignored evidence under `artifacts/apple/native-advisory-pipeline/`.
**Acceptance**: Contract fails red before implementation because the native advisory scanner pipeline is absent.

### ✅ Unit 16e: Native Advisory Pipeline - Implementation
**What**: Add the pinned `bundler-audit` dependency, fail-closed wrapper, advisory policy, allowlist schema, CI job, local matrix hook, and synthetic fixtures.
**Output**: `scripts/scan-ruby-advisories.rb`, policy/allowlist docs, workflow/matrix updates, and ignored evidence under `artifacts/apple/native-advisory-pipeline/`.
**Acceptance**: Unit 16d contract passes; real advisory scan runs against `Gemfile.lock`; no silent scanner/network failures; real findings are fixed or time-bound-reviewed.
**Evidence**: `bundler-audit` is pinned to 0.9.3, the scanner gem SHA256 is `81c8766c71e47d0d28a0f98c7eed028539f21a6ea3cd8f685eb6f42333c9b4e9`, and the Ruby Advisory Database ref is pinned to `32a64d01964828d2f71ba17fb623a73142e03a3d`. `artifacts/apple/native-advisory-pipeline/unit-16e-native-advisory-green.log` passes the contract plus real scan; `artifacts/apple/native-advisory-pipeline/unit-16e-real-ruby-advisory-report.json` reports zero results and zero allowlisted advisories.

### ✅ Unit 16f: Native Advisory Pipeline - Final Validation
**What**: Run the requested native validation set and a harsh security review.
**Output**: Full Swift tests with warnings-as-errors, fail-on-warning, 100% `Sources/SpoonjoyCore` coverage enforcement, scenario verifier, iOS/macOS builds, real advisory results, and review notes.
**Acceptance**: Required validation is green or has a canonical local capability blocker; PR is opened but not merged.
**Evidence**: Final advisory contract and real scan pass with zero findings. Full Swift tests pass with 598 tests, warning scan clean. Coverage enforces 100.00% `Sources/SpoonjoyCore` (26830/26830). Native scenario verifier passes `--stage final`. iOS and macOS `BootstrapDebug` app builds both succeed and both build logs pass `fail-on-warning`. Security review approves with no blocker/major findings.
**Evidence Index**: `worker/tasks/2026-07-15-1751-doing-native-advisory-pipeline-evidence.md`.

## Progress Log

- 2026-07-16T00:51:45Z Created Unit 16d/e/f execution doc for the native advisory pipeline remediation.
- 2026-07-16T00:59:12Z Unit 16e complete: implemented pinned fail-closed `bundler-audit` wrapper, expiring allowlist policy, CI/local matrix wiring, synthetic fixture coverage, and a clean real `Gemfile.lock` scan with no findings.
- 2026-07-16T01:10:00Z Unit 16f complete: full Swift tests, warning scans, 100% SpoonjoyCore coverage, final scenario verifier, iOS/macOS app builds, final advisory scan, and harsh security review are green.
- 2026-07-16T01:24:00Z Moved generated validation artifacts to ignored `artifacts/apple/native-advisory-pipeline/` and kept only durable Markdown task evidence in git.
