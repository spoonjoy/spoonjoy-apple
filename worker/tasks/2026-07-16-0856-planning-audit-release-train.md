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
- Complete clean Apple callback registration/canary, tests, default-start switch, deployment, and clean/legacy rollback verification (canonical Units 3j-3m); use an existing authorized Apple Developer browser session when available, otherwise preserve the exact prerequisite/action as `BLOCKED_HUMAN` while shipping all independent work.
- Verify the web/backend production deployment for the exact merged web main revision and smoke the OAuth, AASA, image/media, CSP, and public product contracts touched by the train.
- Reconcile current App Store Connect feedback, screenshots, crashes, build metadata, and local feedback-worker health before native publication.
- Validate the merged native app with Swift tests, scenario verifier, app bundle builds, coverage, production auth/AASA preflight, iOS simulator route screenshots, macOS launch/screenshots, accessibility evidence, and a closed visual absurdity ledger.
- Capture and manually inspect direct Photo Studio evidence for default, Spoon-off, editorial-off, processing, failure, empty/no-cover, and narrow/dense states on iPhone, iPad, macOS, web mobile, and web desktop, each bound to the exact native source SHA or exact deployed web SHA.
- Fix any blocking functional or visual regression discovered by the required dogfood pass through reviewed, tested PRs before publication.
- Publish the exact green native main SHA to `Spoonjoy Internal`, wait for Apple processing, verify group attachment and `IN_BETA_TESTING`, and verify testers were notified.
- After publication, dogfood the installed TestFlight build's signed-out provider, HEIC cover, mutation-lock, queue-replay, Photo Studio, and cleanup flows on a compatible physical device when an already authorized device-control path exists; otherwise record the exact installed-device action as `BLOCKED_HUMAN` without concealing it or blocking independent App Store Connect verification.
- Retire every task branch and disposable worktree created or consumed by this release train after its work is safely merged.

### Out of Scope
- Public App Store submission or external TestFlight distribution.
- Removing another person's active production credential without that account holder's authenticated participation; the audit's Clem credential item remains a named human-only security follow-up.
- New product domains unrelated to audit findings or dogfood regressions.

## Completion Criteria
- [ ] Already-merged native PRs #47, #48, #49, #50, #51, and #53 and web PRs #255, #256, #258, #259, #260, #261, #262, #263, #264, #267, #269, and #274 are traced to exact commits and remain represented in current main; native PR #52 and web PRs #266, #268, #270, #271, and #272 are merged with required checks green.
- [ ] Audit findings for native mutation serialization/retry identity, Photo Studio product truth, repository cleanup/local OAuth teardown, native cover modularization, and build-specific tester notes have merged implementation evidence; none is deferred behind the release.
- [ ] Clean Apple social callback registration is evidenced in the Apple portal, both callbacks pass canaries, clean starts are selected only after that prerequisite, legacy rollback remains available, and the exact switched web SHA is deployed; if portal access cannot be satisfied by existing sessions, Units 3j-3m are durably `BLOCKED_HUMAN` with the exact action and no premature start switch.
- [ ] The exact merged web main revision is deployed and its affected production contracts pass smoke validation.
- [ ] Current TestFlight feedback reconciliation reports zero unhandled actionable submissions.
- [ ] From a clean exact web main checkout, complete Unit 18 passes: `pnpm cleanup:qa`, local migrations twice, API generation with a zero diff, both typechecks, full 100% coverage, E2E, production build, Storybook build, repository hygiene, advisory scan, and fresh implementation/test/security/visual reviews; deployed production then passes readiness, public/API/MCP/provider/callback smokes, authenticated owner Photo Studio coverage when an authorized session exists, responsive visuals, and zero-residue cleanup.
- [ ] From a clean exact native main checkout, complete Unit 20 passes: Swift tests with warnings as errors, enforced 100% core coverage, scenario verifier, project/generator contracts, iOS/macOS app-target builds, full screenshot matrix, simulator/macOS smokes, repository/advisory gates, accessibility proof, and fresh implementation/test/security/visual reviews; `scripts/validate-native-local.sh` reports `fullyValidated: true` and zero blockers.
- [ ] Every shipped first-level iOS and macOS route has fresh screenshot/live evidence; all seven Photo Studio states are captured directly on iPhone, iPad, macOS, web mobile, and web desktop; the absurdity ledger has no `ready` or `needs reviewer gate` entries and automated visual metrics pass.
- [ ] Durable release evidence is indexed at `worker/tasks/2026-07-16-0856-doing-audit-release-train/evidence-index.md`; raw logs/screenshots/binaries live under ignored `/tmp/spoonjoy-audit-release-train/<source-sha>/`; the index records exact source/deploy SHA, command, exit result, warning count, CI/run URL, artifact path, SHA-256 checksum, reviewer verdict, screenshot reference, cleanup residue, and rollback proof. The final handoff row must contain `web_sha`, `cloudflare_version`, `native_sha`, `native_run_url`, `build_version`, `build_number`, `asc_app_id`, `asc_build_id`, `asc_group_id`, `notes_checksum`, `notify_apply_result`, `installed_dogfood_status`, and `residual_blockers`.
- [ ] Complete build-specific tester notes are bound to the exact native main SHA before dispatch and App Store Connect `betaBuildLocalizations` confirms byte-for-byte `whatsNew` equality with those notes.
- [ ] A new `1.0` build newer than build 35 is `VALID`, attached to `Spoonjoy Internal`, has nonzero testers, and reports `IN_BETA_TESTING`; a successful publish/notify apply artifact proves Apple accepted the notification operation. Notification delivery/receipt is claimed only if installed-build confirmation proves it, otherwise the final report says exactly that delivery was not independently observed.
- [ ] The installed candidate passes provider sign-in, HEIC cover, mutation-lock, queue replay, Photo Studio, and cleanup checks on a physical device, or the exact device/build/action is durably classified `BLOCKED_HUMAN` after every independent release criterion is complete.
- [ ] `testflight-feedback-autopilot.mjs doctor`, `status`, and `reconcile --mode dry-run` pass after publication; listener/tunnel public and local health endpoints and launchd ownership are healthy.
- [ ] Final inventories cover both repositories: canonical checkouts are clean at exact current `origin/main`; every task PR is merged/closed with proof; only merged, clean task branches and terminal worktrees are pruned; dirty, unmerged, active, or ambiguously owned state is preserved and classified; task/doing/Desk state is terminal or explicitly `BLOCKED_HUMAN`; Slugger receives the final status.
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
- Five canonical human-action dispositions must be explicit at closure: Clem credential retirement; clean Apple callback registration; any confirmed live-secret rotation; authenticated production owner smoke; and installed TestFlight dogfood. Existing authenticated browser/computer-control sessions are used first. Truly unavailable human-only actions are recorded `BLOCKED_HUMAN` with owner, prerequisite, exact action, evidence needed, and effect; they never disappear into a generic follow-up.

## Decisions Made
- Web/backend remediations deploy before the final native production-contract and TestFlight validation.
- Existing PRs remain the atomic review units; release integration does not flatten or bypass them.
- Cancelled or failed CI is repaired and rerun, never treated as passing evidence.
- Build publication uses the repository's protected exact-main-SHA TestFlight workflow and remains internal-only.
- Dogfood findings that block a shipped route are part of this train and must be fixed before publishing.
- Clem credential retirement is not allowed to hold the build hostage because it requires the account holder's authenticated participation and is independent of the app binaries.
- The canonical audit-remediation doing queue remains the source of truth for all unlanded implementation units. A currently active Codex task owns the web merge/deploy queue and pre-publication native PR repairs; this task owns final merged-state Apple dogfood, any release-blocking visual repairs, exact-SHA TestFlight publication, verification, and cleanup.
- The release may finish its independent publication work with human-only rows classified `BLOCKED_HUMAN`, but the canonical audit task is marked `done` only if all five rows close; otherwise it remains durably non-terminal with no ready agent-owned work hidden behind the classification.

## Context / References
- `/tmp/spoonjoy-latest-model-audit/audit-report.md`
- `/Users/arimendelow/Projects/spoonjoy-v2-audit-remediation/worker/tasks/2026-07-15-1152-doing-audit-remediation.md`
- `/Users/arimendelow/Projects/spoonjoy-apple-audit-release-train/docs/apple-distribution.md`
- `/Users/arimendelow/Projects/spoonjoy-apple-audit-release-train/docs/native-design-language.md`
- `/Users/arimendelow/Projects/spoonjoy-v2/docs/design-language.md`
- Native merged trace: N0/Photo Studio #47 `bad81b49`; N1/release containment #48 `0bacf7e1`; warning repair #49 `b910c111`; repository hygiene #50 `7c146632`; N9/advisory #51 `3013c361`; N4/provider sign-in #53 `8b5418b7`. N2/cover normalization #52 is open at `a738e4b515` with app bundle/scenario/advisory green and Swift/coverage running at review time. N3/mutation single-flight, N5/Photo Studio truth, cover modularization, and N10/tester notes require new PRs.
- Web merged trace: Photo Studio polish #255 `b22c5fec`; W1/release containment #256 `f4f28db` plus #258 `7adaa220` and #274 `dcf296bd`; W6/native upload contract #259 `5c0fd3c`; W4/dual Apple callbacks #260 `edf22ce1`; W2/provider hints #261 `1fecbb75`; W3/provider bounds #262 `7b06c496`; action matching #263 `6958370b`; W13/database search #264 `42267511`; browser readiness #267 `e7b0e9ec`; dual-channel readiness #269 `b07d787e`. Open at review time: W7/demo eradication #266 `0b7dbce28f` (E2E repair active); W15/home hero #268 `9cba7bc28a` (green); shared cover extraction #270 `8e8d94e07c` (green, behind); W14/CSP #271 `14b85985ca` (green, behind); W16/advisory #272 `0d388fb95a` (green, behind). W5/clean callback switch, W8/local teardown, and W9/repository cleanup require new PRs.
- Native validation: `scripts/validate-native-local.sh`, `scripts/validate-aasa.rb`, `scripts/check-apple-distribution-kit.sh`, and the exact-SHA `.github/workflows/testflight.yml` workflow.
- Web validation: `pnpm run typecheck`, `pnpm run typecheck:scripts`, `pnpm run test:coverage`, `pnpm run test:e2e`, `pnpm run build`, `pnpm run cleanup:local`, and protected production smoke workflows.
- App Store Connect app `6787505444`; internal group `31d60f58-aef9-4d44-b047-3a1f0dc61b5e`

## Notes
Build 35 is currently valid and in internal beta testing, but it predates the open native fixes. The feedback system is healthy with zero unhandled items and fourteen older reports awaiting tester confirmation.

The parallel audit-remediation task has been told not to publish TestFlight or retire native worktrees. It must hand off exact stable web/native main SHAs and evidence; this task retains exclusive ownership of the Apple release and terminal cleanup.

At every handoff, open-PR head/check state is refreshed in the evidence index rather than treated as static planning truth.

## Progress Log
- 2026-07-16 08:56 Created.
- 2026-07-16 09:05 Addressed harsh planning review round-one findings: restored omitted audit units, corrected live PR state, strengthened visual acceptance, made validation commands concrete, and added build-note/App Store Connect notification verification.
- 2026-07-16 09:18 Addressed harsh planning review round-two findings: added Units 3j-3m and installed dogfood, explicit five-row human dispositions, unit-to-PR/head traceability, iPad and empty/no-cover visual states, full Units 18/20 evidence schema, honest notification semantics, and two-repo terminal cleanup rules.
