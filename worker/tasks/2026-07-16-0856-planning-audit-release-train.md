# Planning: Audit Remediation Release Train

**Status**: drafting
**Created**: 2026-07-16 08:56 PDT

## Goal
Land the currently reviewed Spoonjoy web and native audit remediations, verify the deployed backend and every promised native surface, and publish the exact green native main revision to the internal TestFlight group.

## Upstream Work Items
- 2026-07-15 Spoonjoy shipped-work audit findings 1-4 and 6-12

## Scope

### In Scope
- Verify every already-merged audit PR at its exact commit and reconcile the remaining native PR #52 and web PRs #266, #268, #270, #271, and #272 in dependency-safe order, repairing cancelled or failing checks without weakening coverage or release gates.
- Finish the canonical audit queue still not represented by a merged PR: native mutation single-flight/retry identity, native Photo Studio product truth, local OAuth teardown, web repository/artifact cleanup and PR-size hygiene, native cover codec/queue modularization, and build-specific TestFlight tester notes.
- Verify the web/backend production deployment for the exact merged web main revision and smoke the OAuth, AASA, image/media, CSP, and public product contracts touched by the train.
- Reconcile current App Store Connect feedback, screenshots, crashes, build metadata, and local feedback-worker health before native publication.
- Validate the merged native app with Swift tests, scenario verifier, app bundle builds, coverage, production auth/AASA preflight, iOS simulator route screenshots, macOS launch/screenshots, accessibility evidence, and a closed visual absurdity ledger.
- Capture and manually inspect direct iOS and macOS Photo Studio evidence for default, Spoon-off, editorial-off, processing, failure, and narrow-layout states, plus equivalent web evidence for the shared product contract.
- Fix any blocking functional or visual regression discovered by the required dogfood pass through reviewed, tested PRs before publication.
- Publish the exact green native main SHA to `Spoonjoy Internal`, wait for Apple processing, verify group attachment and `IN_BETA_TESTING`, and verify testers were notified.
- Retire every task branch and disposable worktree created or consumed by this release train after its work is safely merged.

### Out of Scope
- Public App Store submission or external TestFlight distribution.
- Removing another person's active production credential without that account holder's authenticated participation; the audit's Clem credential item remains a named human-only security follow-up.
- New product domains unrelated to audit findings or dogfood regressions.

## Completion Criteria
- [ ] Already-merged native PRs #47-#51 and #53 and web PRs #255-#264, #267, #269, and #274 are traced to exact commits and remain represented in current main; native PR #52 and web PRs #266, #268, #270, #271, and #272 are merged with required checks green.
- [ ] Audit findings for native mutation serialization/retry identity, Photo Studio product truth, repository cleanup/local OAuth teardown, native cover modularization, and build-specific tester notes have merged implementation evidence; none is deferred behind the release.
- [ ] The exact merged web main revision is deployed and its affected production contracts pass smoke validation.
- [ ] Current TestFlight feedback reconciliation reports zero unhandled actionable submissions.
- [ ] The exact merged web main passes `pnpm run typecheck`, `pnpm run typecheck:scripts`, `pnpm run test:coverage`, `pnpm run test:e2e`, `pnpm run build`, and `pnpm run cleanup:local`; deployed production passes `smoke:live`, `smoke:mcp:oauth`, and `smoke:api` for the exact revision.
- [ ] `scripts/validate-native-local.sh` reports `fullyValidated: true` and zero blockers for the exact merged native main, including Swift tests, scenario verification, app bundle builds, coverage, production auth/AASA preflight, iOS simulator smoke, and macOS smoke with no warnings.
- [ ] Every shipped first-level iOS and macOS route has fresh screenshot/live evidence; the six Photo Studio states are captured directly on both platforms; equivalent web states are inspected; the absurdity ledger has no `ready` or `needs reviewer gate` entries and automated visual metrics pass.
- [ ] Complete build-specific tester notes are bound to the exact native main SHA before dispatch and App Store Connect `betaBuildLocalizations` confirms the uploaded build's `whatsNew` matches those notes.
- [ ] A new `1.0` build newer than build 35 is `VALID`, attached to `Spoonjoy Internal`, has nonzero testers, and reports `IN_BETA_TESTING`; the `notifyTesters` apply artifact and final build/group API relationships confirm testers were notified.
- [ ] `testflight-feedback-autopilot.mjs doctor`, `status`, and `reconcile --mode dry-run` pass after publication; listener/tunnel public and local health endpoints and launchd ownership are healthy.
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
- The canonical audit-remediation doing queue remains the source of truth for all unlanded implementation units. A currently active Codex task owns the web merge/deploy queue and pre-publication native PR repairs; this task owns final merged-state Apple dogfood, any release-blocking visual repairs, exact-SHA TestFlight publication, verification, and cleanup.

## Context / References
- `/tmp/spoonjoy-latest-model-audit/audit-report.md`
- `/Users/arimendelow/Projects/spoonjoy-v2-audit-remediation/worker/tasks/2026-07-15-1152-doing-audit-remediation.md`
- `/Users/arimendelow/Projects/spoonjoy-apple-audit-release-train/docs/apple-distribution.md`
- `/Users/arimendelow/Projects/spoonjoy-apple-audit-release-train/docs/native-design-language.md`
- `/Users/arimendelow/Projects/spoonjoy-v2/docs/design-language.md`
- Native merged trace: #47 `bad81b49`, #48 `0bacf7e1`, #49 `b910c111`, #50 `7c146632`, #51 `3013c361`, #53 `8b5418b7`; open: #52.
- Web merged trace: #255 `b22c5fec`, #256 `f4f28db`, #258 `7adaa220`, #259 `5c0fd3c`, #260 `edf22ce1`, #261 `1fecbb75`, #262 `7b06c496`, #263 `6958370b`, #264 `42267511`, #267 `e7b0e9ec`, #269 `b07d787e`, #274 `dcf296bd`; open: #266, #268, #270, #271, #272.
- Native validation: `scripts/validate-native-local.sh`, `scripts/validate-aasa.rb`, `scripts/check-apple-distribution-kit.sh`, and the exact-SHA `.github/workflows/testflight.yml` workflow.
- Web validation: `pnpm run typecheck`, `pnpm run typecheck:scripts`, `pnpm run test:coverage`, `pnpm run test:e2e`, `pnpm run build`, `pnpm run cleanup:local`, and protected production smoke workflows.
- App Store Connect app `6787505444`; internal group `31d60f58-aef9-4d44-b047-3a1f0dc61b5e`

## Notes
Build 35 is currently valid and in internal beta testing, but it predates the open native fixes. The feedback system is healthy with zero unhandled items and fourteen older reports awaiting tester confirmation.

The parallel audit-remediation task has been told not to publish TestFlight or retire native worktrees. It must hand off exact stable web/native main SHAs and evidence; this task retains exclusive ownership of the Apple release and terminal cleanup.

## Progress Log
- 2026-07-16 08:56 Created.
- 2026-07-16 09:05 Addressed harsh planning review round-one findings: restored omitted audit units, corrected live PR state, strengthened visual acceptance, made validation commands concrete, and added build-note/App Store Connect notification verification.
