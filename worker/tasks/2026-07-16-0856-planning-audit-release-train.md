# Planning: Audit Remediation Release Train

**Status**: drafting
**Created**: 2026-07-16 08:56 PDT

## Goal
Land the currently reviewed Spoonjoy web and native audit remediations, verify the deployed backend and every promised native surface, and publish the exact green native main revision to the internal TestFlight group.

## Upstream Work Items
- 2026-07-15 Spoonjoy shipped-work audit findings 1-4 and 6-12

## Scope

### In Scope
- Verify every already-merged audit PR at its exact commit and reconcile the remaining native PR #52 and web PRs #266, #270, #271, and #272 in dependency-safe order, repairing cancelled or failing checks without weakening coverage or release gates.
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
- [ ] Already-merged native PRs #47, #48, #49, #50, #51, and #53 and web PRs #255, #256, #258, #259, #260, #261, #262, #263, #264, #267, #268, #269, and #274 are traced to exact commits and remain represented in current main; native PR #52 and web PRs #266, #270, #271, and #272 are merged with required checks green.
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
- Native validation: `scripts/validate-native-local.sh`, `scripts/validate-aasa.rb`, `scripts/check-apple-distribution-kit.sh`, and the exact-SHA `.github/workflows/testflight.yml` workflow.
- Web validation: `pnpm run typecheck`, `pnpm run typecheck:scripts`, `pnpm run test:coverage`, `pnpm run test:e2e`, `pnpm run build`, `pnpm run cleanup:local`, and protected production smoke workflows.
- App Store Connect app `6787505444`; internal group `31d60f58-aef9-4d44-b047-3a1f0dc61b5e`

### Unit / PR Trace (refreshed 2026-07-16 09:20:24 PDT)

| Canonical unit | Repository PR | Current full head SHA | Merge SHA / state |
| --- | --- | --- | --- |
| N0 Photo Studio baseline | native #47 | `7826ed2bb767afb5734516384ea70c78e0261e30` | `bad81b49a07c006814315a56e4c98311693a7256` merged |
| N1 TestFlight containment | native #48 | `870a5a2d8528cc2665fc94757c212ddef2cff6a8` | `0bacf7e1c48a162e9fbca87ff0edba01ba6319b2` merged |
| N1 warning repair | native #49 | `f0a2ac8e3a4756e4b70465ee5186c1df8972d53c` | `b910c11101a81bc950d8dcf8d2046804ca60d0ae` merged |
| N6 repository hygiene | native #50 | `af64826f78fddaf08b190e9972a3734fce030c2c` | `7c146632e9e16d53176da502e4fdca87ab17f580` merged |
| N9 advisory pipeline | native #51 | `0f471f2656a3608d4dc083820a1800a2649cc71e` | `3013c361ef178ccb2af67a61e3f2a1d72df46f35` merged |
| N2 cover normalization | native #52 | `a738e4b51549e1ed8944d57b02f14b0fcb353f8f` | open; full CI running |
| N4 provider sign-in | native #53 | `62b1e3eff83ebc77c0ef7fb535d6477426c15587` | `8b5418b7608105d242e44493812ddbbb47d63374` merged |
| N3 mutation single-flight | PR pending | pending | not started |
| N5 Photo Studio truth | PR pending | pending | not started |
| N7 cover codec extraction | PR pending | pending | not started |
| N8 cover queue extraction | PR pending | pending | not started |
| N10 build-specific notes | PR pending | pending | not started |
| Web Photo Studio polish | web #255 | `250cee63fc1ee6aeae0404a2af7a04accb286365` | `b22c5fece92886a03747ccc5e05e525c4b97be55` merged |
| W1 release containment | web #256 / #258 / #274 | `224520a37853d5f46a433ac02834f63e0be99742`; `f51325d2d7133ab434ef1b8aa847c5b06a4e78db`; `8e8c300cb4fa5024d7a653b7d7bc77ba77dc32e0` | `f4f28db88689fc922fee8132257c564831679986`; `7adaa2206c8ed47748e8f897714c57b972353ef3`; `dcf296bd22d2fb9b98f55fbb7c411e88606986f3` merged |
| W6 native upload contract | web #259 | `8de4e4ba10e837ff122da4f03facfc3e46123ede` | `5c0fd3c2916c22698b40dd233bdee2045adf04d4` merged |
| W4 dual Apple callbacks | web #260 | `377a454d1a1f5a8a39d131be4b27dfb07d1286f0` | `edf22ce1dd051937982d1908feb5813034eb276c` merged |
| W2 provider hints | web #261 | `dd2cb7562ed7d1daf007e1e883dd3453ce50f929` | `1fecbb75131d7b6d083caf93a4009b21673bd85b` merged |
| W3 provider bounds | web #262 | `c4a042f441635a7be5eafa6b4e73c8e434ef4172` | `7b06c49696f949d7429ae6898b92f5b0e1c807d6` merged |
| Router action matching | web #263 | `ba8c7eab1c60267b333c57de320b56397ba2f4a2` | `6958370b2bd69658fed1a51ffc5694b40b35b23b` merged |
| W13 database search | web #264 | `60efca6867b3523806289c8adb5831df75b99d55` | `4226751167480d95822f1bac8b5143327b3813d7` merged |
| W7 demo eradication | web #266 | `0b7dbce28f2f5ec32bab5b745f1481d875805df4` | open; E2E repair active |
| Browser readiness | web #267 | `385bf7179f5ffb1c6ca1b2a2209d7c537d7598e9` | `e7b0e9ec662b96467bac9581dbad459c77b4bd0b` merged |
| W15 home hero | web #268 | `9cba7bc28ade7de82ea8c43d62866c9be34e9828` | `2f392840a24fb1c5886cb843071e29f719e1b946` merged |
| Dual-channel readiness | web #269 | `2c4921934948c2e06979e1886945cc874f530939` | `b07d787ee7da7a57f137354a3323f0a7da5e8050` merged |
| W10-W12 cover extraction/delegation | web #270 | `f365f3c5a23df59780cf07129b75f1190da5b225` | open; CI running |
| W14 CSP | web #271 | `14b85985ca8fb312b8455326961c9f3762e31b3d` | open; green, rebase pending |
| W16 advisory | web #272 | `0d388fb95a88a8a39912687a9a673980d2805fc7` | open; green, rebase pending |
| W5 clean callback switch | PR pending | pending | gated by Apple registration/canary |
| W8 local OAuth teardown | PR pending | pending | not started |
| W9 repository cleanup | PR pending | pending | not started |
| Unit 7d web visual matrix harness | PR pending | pending | required before final web evidence |

### Unit 18 Web Evidence Matrix

All shell commands run under `set -o pipefail` from `/Users/arimendelow/Projects/spoonjoy-v2-audit-final-validation`, a clean detached checkout of the selected `origin/main`. Let `ROOT=/tmp/spoonjoy-audit-release-train/<web-sha>/web`; create it before the matrix with `mkdir -p "$ROOT/screenshots/photo-studio"`.

| Evidence key | Exact command | Expected result | Deterministic artifact |
| --- | --- | --- | --- |
| `web.cleanup.before` | `pnpm run cleanup:qa \|& tee "$ROOT/01-cleanup-qa.log"` | exit 0; dry-run manifest is ownership-safe | `$ROOT/01-cleanup-qa.log` |
| `web.migration.first` | `pnpm exec wrangler d1 migrations apply DB --local \|& tee "$ROOT/02-migration-first.log"` | exit 0 | `$ROOT/02-migration-first.log` |
| `web.migration.second` | `pnpm exec wrangler d1 migrations apply DB --local \|& tee "$ROOT/03-migration-second.log"` | exit 0; no pending migrations | `$ROOT/03-migration-second.log` |
| `web.api.zero_diff` | `{ pnpm run api:playground:generate && git diff --exit-code -- app/lib/generated/api-v1-playground.ts; } \|& tee "$ROOT/04-api-generation-zero-diff.log"` | exit 0; zero diff | `$ROOT/04-api-generation-zero-diff.log` |
| `web.typecheck.app` | `pnpm run typecheck \|& tee "$ROOT/05-typecheck.log"` | exit 0 | `$ROOT/05-typecheck.log` |
| `web.typecheck.scripts` | `pnpm run typecheck:scripts \|& tee "$ROOT/06-typecheck-scripts.log"` | exit 0 | `$ROOT/06-typecheck-scripts.log` |
| `web.coverage` | `pnpm run test:coverage \|& tee "$ROOT/07-coverage.log"` | exit 0; 100% statements/branches/functions/lines | `$ROOT/07-coverage.log` |
| `web.e2e` | `pnpm run test:e2e \|& tee "$ROOT/08-e2e.log"` | exit 0; all browser projects pass | `$ROOT/08-e2e.log` |
| `web.build.production` | `pnpm run build \|& tee "$ROOT/09-build.log"` | exit 0 | `$ROOT/09-build.log` |
| `web.build.storybook` | `pnpm run build-storybook \|& tee "$ROOT/10-storybook.log"` | exit 0 | `$ROOT/10-storybook.log` |
| `web.repo_hygiene` | `pnpm exec vitest run test/repo-hygiene.test.ts test/release-workflow-security.test.ts --fileParallelism=false \|& tee "$ROOT/11-repo-hygiene.log"` | exit 0; tracked-file and PR-size policy pass | `$ROOT/11-repo-hygiene.log` |
| `web.advisory` | `pnpm run advisory:scan -- --output "$ROOT/12-advisory-report.json" \|& tee "$ROOT/12-advisory.log"` | exit 0; no unreviewed actionable finding or scanner failure | `$ROOT/12-advisory.log`; `$ROOT/12-advisory-report.json` |
| `web.warning_scan` | `ruby /Users/arimendelow/Projects/spoonjoy-apple-audit-final-validation/scripts/fail-on-warning.rb --log "$ROOT/01-cleanup-qa.log" --log "$ROOT/02-migration-first.log" --log "$ROOT/03-migration-second.log" --log "$ROOT/04-api-generation-zero-diff.log" --log "$ROOT/05-typecheck.log" --log "$ROOT/06-typecheck-scripts.log" --log "$ROOT/07-coverage.log" --log "$ROOT/08-e2e.log" --log "$ROOT/09-build.log" --log "$ROOT/10-storybook.log" --log "$ROOT/11-repo-hygiene.log" --log "$ROOT/12-advisory.log" \|& tee "$ROOT/13-warning-scan.log"` | exit 0; warning count 0 | `$ROOT/13-warning-scan.log` |
| `web.visual.capture` | `SPOONJOY_VISUAL_OUTPUT_DIR="$ROOT/screenshots/photo-studio" pnpm exec playwright test e2e/visual/photo-studio-states.spec.ts --project=chromium --reporter=line \|& tee "$ROOT/14-photo-studio-visual-matrix.log"` | exit 0; default, Spoon-off, editorial-off, processing, failure, empty/no-cover, and narrow/dense captured at mobile and desktop viewports | `$ROOT/14-photo-studio-visual-matrix.log`; `$ROOT/screenshots/photo-studio/` |
| `web.review.implementation` | `multi_agent_v1.spawn_agent({agent_type:"default",fork_context:false,message:"Harsh implementation review exact web SHA and Unit 18 artifacts; APPROVED or findings"}); multi_agent_v1.wait_agent(<id>); apply_patch(<verdict>, "$ROOT/15-review-implementation.md")` | `APPROVED` | `$ROOT/15-review-implementation.md` |
| `web.review.test` | `multi_agent_v1.spawn_agent({agent_type:"default",fork_context:false,message:"Harsh test and coverage review exact web SHA and Unit 18 artifacts; APPROVED or findings"}); multi_agent_v1.wait_agent(<id>); apply_patch(<verdict>, "$ROOT/16-review-test.md")` | `APPROVED` | `$ROOT/16-review-test.md` |
| `web.review.security` | `multi_agent_v1.spawn_agent({agent_type:"default",fork_context:false,message:"Harsh security auth and data review exact web SHA and Unit 18 artifacts; APPROVED or findings"}); multi_agent_v1.wait_agent(<id>); apply_patch(<verdict>, "$ROOT/17-review-security.md")` | `APPROVED` | `$ROOT/17-review-security.md` |
| `web.review.visual` | `multi_agent_v1.spawn_agent({agent_type:"default",fork_context:false,message:"Run visual-qa-dogfood on every exact-SHA web Photo Studio capture; persist absurdity ledger; APPROVED or findings"}); multi_agent_v1.wait_agent(<id>); apply_patch(<verdict-and-ledger>, "$ROOT/18-review-visual.md", "$ROOT/absurdity-ledger.md")` | `APPROVED`; absurdity ledger closed | `$ROOT/18-review-visual.md`; `$ROOT/absurdity-ledger.md` |

### Unit 20 Native Evidence Matrix

All shell commands run under `set -o pipefail` from `/Users/arimendelow/Projects/spoonjoy-apple-final-validation`, a clean detached checkout of the selected `origin/main`. Let `ROOT=/tmp/spoonjoy-audit-release-train/<native-sha>/native`; create it with `mkdir -p "$ROOT/apple"`. `scripts/validate-native-local.sh` owns and records the component commands below; its final invocation is the authoritative aggregate replay.

| Evidence key | Exact command | Expected result | Deterministic artifact |
| --- | --- | --- | --- |
| `native.swift.tests` | `swift test --disable-xctest --parallel -Xswiftc -warnings-as-errors \|& tee "$ROOT/apple/matrix-swift-test.log"` | exit 0 | `$ROOT/apple/matrix-swift-test.log` |
| `native.swift.coverage` | `swift test --enable-code-coverage --disable-xctest --parallel -Xswiftc -warnings-as-errors \|& tee "$ROOT/apple/matrix-coverage-test.log"` | exit 0 | `$ROOT/apple/matrix-coverage-test.log` |
| `native.coverage.enforce` | `ruby scripts/enforce-swift-coverage.rb --coverage-json "$(swift test --show-codecov-path)" --minimum 100 --include Sources/SpoonjoyCore \|& tee "$ROOT/apple/matrix-coverage-enforce.log"` | exit 0; 100% core coverage | `$ROOT/apple/matrix-coverage-enforce.log` |
| `native.scenario.final` | `scripts/verify-native-scenarios.sh --stage final --output "$ROOT/apple/matrix-final-report.json" \|& tee "$ROOT/apple/matrix-final-scenario.log"` | exit 0 | `$ROOT/apple/matrix-final-scenario.log`; `$ROOT/apple/matrix-final-report.json` |
| `native.project.contract` | `scripts/bundle-exec.sh ruby scripts/check-xcode-project-contract.rb \|& tee "$ROOT/apple/matrix-project-contract.log"` | exit 0 | `$ROOT/apple/matrix-project-contract.log` |
| `native.generator.contract` | `scripts/bundle-exec.sh ruby scripts/check-xcode-generator-contract.rb \|& tee "$ROOT/apple/matrix-generator-contract.log"` | exit 0 | `$ROOT/apple/matrix-generator-contract.log` |
| `native.ios.build` | `xcodebuild -project Spoonjoy.xcodeproj -scheme "Spoonjoy iOS" -configuration BootstrapDebug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES build \|& tee "$ROOT/apple/matrix-xcodebuild-ios.log"` | exit 0; no blocker | `$ROOT/apple/matrix-xcodebuild-ios.log` |
| `native.macos.build` | `xcodebuild -project Spoonjoy.xcodeproj -scheme "Spoonjoy macOS" -configuration BootstrapDebug -destination "generic/platform=macOS" CODE_SIGNING_ALLOWED=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES build \|& tee "$ROOT/apple/matrix-xcodebuild-macos.log"` | exit 0; no blocker | `$ROOT/apple/matrix-xcodebuild-macos.log` |
| `native.screenshot.matrix` | `scripts/capture-native-screenshot-matrix.sh --artifact-root "$ROOT" --unit-slug matrix \|& tee "$ROOT/apple/matrix-capture.log"` | exit 0; every route and all seven iPhone/iPad/macOS Photo Studio states pass | `$ROOT/apple/matrix-capture.log`; `$ROOT/apple/matrix-route-matrix.json`; `$ROOT/screenshot-routes/` |
| `native.ios.smoke` | `scripts/smoke-ios-simulator.sh --artifact-root "$ROOT" --log "$ROOT/apple/matrix-smoke-ios-inner.log" --blocker "$ROOT/apple/matrix-smoke-ios-simulator-blocker.json" \|& tee "$ROOT/apple/matrix-smoke-ios.log"` | exit 0; no blocker | `$ROOT/apple/matrix-smoke-ios.log`; `$ROOT/apple/matrix-smoke-ios-inner.log` |
| `native.macos.smoke` | `scripts/smoke-macos.sh --artifact-root "$ROOT" --log "$ROOT/apple/matrix-smoke-macos-inner.log" --blocker "$ROOT/apple/matrix-smoke-macos-blocker.json" \|& tee "$ROOT/apple/matrix-smoke-macos.log"` | exit 0; no blocker | `$ROOT/apple/matrix-smoke-macos.log`; `$ROOT/apple/matrix-smoke-macos-inner.log` |
| `native.accessibility` | `{ ruby scripts/check-design-accessibility-contract.rb && jq -e '.ok == true' "$ROOT/apple/matrix-accessibility-proof-ios.json" && jq -e '.ok == true' "$ROOT/apple/matrix-accessibility-proof-macos.json"; } \|& tee "$ROOT/apple/matrix-design-accessibility-contract.log"` | exit 0; iOS/macOS proofs valid | `$ROOT/apple/matrix-design-accessibility-contract.log`; `$ROOT/apple/matrix-accessibility-proof-ios.json`; `$ROOT/apple/matrix-accessibility-proof-macos.json` |
| `native.repo_hygiene` | `ruby scripts/audit-native-validation-artifacts.rb --artifact-root "$ROOT" --manifest "$ROOT/repo-hygiene-manifest.json" --repo-hygiene-only --base-ref origin/main \|& tee "$ROOT/repo-hygiene.log"` | exit 0 | `$ROOT/repo-hygiene.log`; `$ROOT/repo-hygiene-manifest.json` |
| `native.advisory` | `ruby scripts/scan-ruby-advisories.rb --output "$ROOT/apple/matrix-ruby-advisory-report.json" \|& tee "$ROOT/apple/matrix-ruby-advisory-scan.log"` | exit 0; no unreviewed actionable finding | `$ROOT/apple/matrix-ruby-advisory-scan.log`; `$ROOT/apple/matrix-ruby-advisory-report.json` |
| `native.aggregate` | `{ SPOONJOY_NATIVE_ARTIFACT_ROOT="$ROOT" scripts/validate-native-local.sh --artifact-root "$ROOT" && jq -e '.fullyValidated == true and .counts.failed == 0 and .counts.blocked == 0 and .counts.blockers == 0' "$ROOT/apple/validation-matrix.json"; } \|& tee "$ROOT/apple/validate-native-local.log"` | exit 0; `fullyValidated: true`; zero warnings/blockers | `$ROOT/apple/validate-native-local.log`; `$ROOT/apple/validation-matrix.json`; `$ROOT/apple/validation-matrix.jsonl`; `$ROOT/apple/matrix-warning-scan.log` |
| `native.review.implementation` | `multi_agent_v1.spawn_agent({agent_type:"default",fork_context:false,message:"Harsh implementation review exact native SHA and Unit 20 artifacts; APPROVED or findings"}); multi_agent_v1.wait_agent(<id>); apply_patch(<verdict>, "$ROOT/review-implementation.md")` | `APPROVED` | `$ROOT/review-implementation.md` |
| `native.review.test` | `multi_agent_v1.spawn_agent({agent_type:"default",fork_context:false,message:"Harsh test and coverage review exact native SHA and Unit 20 artifacts; APPROVED or findings"}); multi_agent_v1.wait_agent(<id>); apply_patch(<verdict>, "$ROOT/review-test.md")` | `APPROVED` | `$ROOT/review-test.md` |
| `native.review.security` | `multi_agent_v1.spawn_agent({agent_type:"default",fork_context:false,message:"Harsh auth data and release review exact native SHA and Unit 20 artifacts; APPROVED or findings"}); multi_agent_v1.wait_agent(<id>); apply_patch(<verdict>, "$ROOT/review-security.md")` | `APPROVED` | `$ROOT/review-security.md` |
| `native.review.visual` | `multi_agent_v1.spawn_agent({agent_type:"default",fork_context:false,message:"Run visual-qa-dogfood on every exact-SHA iPhone iPad macOS capture; persist absurdity ledger; APPROVED or findings"}); multi_agent_v1.wait_agent(<id>); apply_patch(<verdict-and-ledger>, "$ROOT/review-visual.md", "$ROOT/absurdity-ledger.md")` | `APPROVED`; absurdity ledger closed | `$ROOT/review-visual.md`; `$ROOT/absurdity-ledger.md` |

## Notes
Build 35 is currently valid and in internal beta testing, but it predates the open native fixes. The feedback system is healthy with zero unhandled items and fourteen older reports awaiting tester confirmation.

The parallel audit-remediation task has been told not to publish TestFlight or retire native worktrees. It must hand off exact stable web/native main SHAs and evidence; this task retains exclusive ownership of the Apple release and terminal cleanup.

At every handoff, open-PR head/check state is refreshed in the evidence index rather than treated as static planning truth.

## Progress Log
- 2026-07-16 08:56 Created.
- 2026-07-16 09:05 Addressed harsh planning review round-one findings: restored omitted audit units, corrected live PR state, strengthened visual acceptance, made validation commands concrete, and added build-note/App Store Connect notification verification.
- 2026-07-16 09:18 Addressed harsh planning review round-two findings: added Units 3j-3m and installed dogfood, explicit five-row human dispositions, unit-to-PR/head traceability, iPad and empty/no-cover visual states, full Units 18/20 evidence schema, honest notification semantics, and two-repo terminal cleanup rules.
- 2026-07-16 09:20 Addressed harsh planning review round-three findings: refreshed exact full PR heads/merge SHAs with pending-unit rows and added executable Unit 18/20 command-to-artifact matrices.
- 2026-07-16 09:25 Addressed final planning review finding: every shell validation now writes its deterministic artifact under `pipefail`, both web and native have executable seven-state visual capture commands, and reviewer gates are exact persisted agent operations.
