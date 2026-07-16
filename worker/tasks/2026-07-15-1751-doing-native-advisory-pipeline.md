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
**Output**: `scripts/check-native-advisory-pipeline.rb` and `apple/unit-16d-native-advisory-red.log`.
**Acceptance**: Contract fails red before implementation because the native advisory scanner pipeline is absent.

### ⬜ Unit 16e: Native Advisory Pipeline - Implementation
**What**: Add the pinned `bundler-audit` dependency, fail-closed wrapper, advisory policy, allowlist schema, CI job, local matrix hook, and synthetic fixtures.
**Output**: `scripts/scan-ruby-advisories.rb`, policy/allowlist docs, workflow/matrix updates, `apple/unit-16e-native-advisory-green.log`, and real scan report.
**Acceptance**: Unit 16d contract passes; real advisory scan runs against `Gemfile.lock`; no silent scanner/network failures; real findings are fixed or time-bound-reviewed.

### ⬜ Unit 16f: Native Advisory Pipeline - Final Validation
**What**: Run the requested native validation set and a harsh security review.
**Output**: Full Swift tests with warnings-as-errors, fail-on-warning, 100% `Sources/SpoonjoyCore` coverage enforcement, scenario verifier, iOS/macOS builds, real advisory results, and review notes.
**Acceptance**: Required validation is green or has a canonical local capability blocker; PR is opened but not merged.

## Progress Log

- 2026-07-16T00:51:45Z Created Unit 16d/e/f execution doc for the native advisory pipeline remediation.
