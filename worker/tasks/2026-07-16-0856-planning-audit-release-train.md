# Planning: Audit Remediation Release Train

**Status**: drafting
**Created**: 2026-07-16 08:56 PDT

## Goal
Land the currently reviewed Spoonjoy web and native audit remediations, verify the deployed backend and every promised native surface, and publish the exact green native main revision to the internal TestFlight group.

## Upstream Work Items
- 2026-07-15 Spoonjoy shipped-work audit findings 1-4 and 6-12

## Scope

### In Scope
- Reconcile and merge native PRs #52 and #53, repairing cancelled or failing checks without weakening coverage or release gates.
- Reconcile and merge web PRs #260, #264, #266, #268, #270, #271, and #272 in dependency-safe order, repairing CI failures and merge races.
- Verify the web/backend production deployment for the exact merged web main revision and smoke the OAuth, AASA, image/media, CSP, and public product contracts touched by the train.
- Reconcile current App Store Connect feedback, screenshots, crashes, build metadata, and local feedback-worker health before native publication.
- Validate the merged native app with Swift tests, scenario verifier, app bundle builds, coverage, production auth/AASA preflight, iOS simulator route screenshots, macOS launch/screenshots, accessibility evidence, and a closed visual absurdity ledger.
- Fix any blocking functional or visual regression discovered by the required dogfood pass through reviewed, tested PRs before publication.
- Publish the exact green native main SHA to `Spoonjoy Internal`, wait for Apple processing, verify group attachment and `IN_BETA_TESTING`, and verify testers were notified.
- Retire every task branch and disposable worktree created or consumed by this release train after its work is safely merged.

### Out of Scope
- Public App Store submission or external TestFlight distribution.
- Removing another person's active production credential without that account holder's authenticated participation; the audit's Clem credential item remains a named human-only security follow-up.
- New product domains unrelated to audit findings or dogfood regressions.

## Completion Criteria
- [ ] Native PRs #52 and #53 are merged to `spoonjoy/spoonjoy-apple` main with required checks green.
- [ ] Web PRs #260, #264, #266, #268, #270, #271, and #272 are merged to `spoonjoy/spoonjoy-v2` main with required checks green.
- [ ] The exact merged web main revision is deployed and its affected production contracts pass smoke validation.
- [ ] Current TestFlight feedback reconciliation reports zero unhandled actionable submissions.
- [ ] The exact merged native main revision passes Swift tests, scenario verification, app bundle builds, coverage, auth/AASA preflight, iOS simulator smoke, and macOS smoke with no warnings.
- [ ] Every shipped first-level iOS and macOS route has fresh screenshot/live evidence; the absurdity ledger has no `ready` or `needs reviewer gate` entries and automated visual metrics pass.
- [ ] A new `1.0` build newer than build 35 is `VALID`, attached to `Spoonjoy Internal`, has nonzero testers, and reports `IN_BETA_TESTING` with tester notification enabled.
- [ ] The feedback webhook, listener, tunnel, and reconciliation path are healthy after publication.
- [ ] All task PRs, branches, and disposable worktrees are retired; the canonical native checkout is clean on current main.
- [ ] 100% test coverage on all new code.
- [ ] All tests pass.
- [ ] No warnings.
- [ ] `visual-qa-dogfood` evidence is captured, the absurdity ledger is closed, and automated visual metrics pass.

## Code Coverage Requirements
**MANDATORY: 100% coverage on all new code.**
- No coverage exclusions on new code.
- All branches and error paths introduced by release repairs are tested.
- Adapter repairs assert outbound request URL, body, headers, and arguments where applicable.
- Existing repository coverage gates must remain green in both repos.

## Open Questions
- None. Merge order may adapt to live dependency and race evidence, but the terminal contract is fixed.

## Decisions Made
- Web/backend remediations deploy before the final native production-contract and TestFlight validation.
- Existing PRs remain the atomic review units; release integration does not flatten or bypass them.
- Cancelled or failed CI is repaired and rerun, never treated as passing evidence.
- Build publication uses the repository's protected exact-main-SHA TestFlight workflow and remains internal-only.
- Dogfood findings that block a shipped route are part of this train and must be fixed before publishing.
- Clem credential retirement is not allowed to hold the build hostage because it requires the account holder's authenticated participation and is independent of the app binaries.

## Context / References
- `/tmp/spoonjoy-latest-model-audit/audit-report.md`
- `/Users/arimendelow/Projects/spoonjoy-apple-audit-release-train/docs/apple-distribution.md`
- `/Users/arimendelow/Projects/spoonjoy-apple-audit-release-train/docs/native-design-language.md`
- `/Users/arimendelow/Projects/spoonjoy-v2/docs/design-language.md`
- Native PRs: `https://github.com/spoonjoy/spoonjoy-apple/pull/52`, `https://github.com/spoonjoy/spoonjoy-apple/pull/53`
- Web PRs: `https://github.com/spoonjoy/spoonjoy-v2/pull/260`, `#264`, `#266`, `#268`, `#270`, `#271`, `#272`
- App Store Connect app `6787505444`; internal group `31d60f58-aef9-4d44-b047-3a1f0dc61b5e`

## Notes
Build 35 is currently valid and in internal beta testing, but it predates the open native fixes. The feedback system is healthy with zero unhandled items and fourteen older reports awaiting tester confirmation.

## Progress Log
- 2026-07-16 08:56 Created.
