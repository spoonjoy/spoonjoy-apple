# Doing: Audit Remediation Release Train

**Status**: REVIEWING
**Execution Mode**: spawn
**Created**: 2026-07-16 09:34 PDT
**Planning**: ./2026-07-16-0856-planning-audit-release-train.md
**Artifacts**: ./2026-07-16-0856-doing-audit-release-train/

## Objective
Finish every agent-owned item in the Spoonjoy audit-remediation queue, deploy and prove the exact final web SHA, validate the exact final native SHA across iPhone, iPad, and macOS, and publish that native SHA as an internal-only TestFlight build attached to `Spoonjoy Internal`.

## Execution Rules
- Use tests-first red/green/refactor for every new implementation unit.
- Keep web and native work in separate agent-owned branches/worktrees and atomic PRs.
- The active audit-remediation task owns its current web PR train and native PR #52; adopt its merged SHAs and evidence without duplicating changes or Apple publication.
- Every PR receives focused tests, full repository gates, fresh harsh review, green PR CI, green merged-main CI, and exact-SHA deployment verification where applicable.
- Raw logs, screenshots, binaries, and reports are staged in `/tmp/spoonjoy-audit-release-train/<source-sha>/`, then bundled with `SHA256SUMS` and uploaded to an exact-SHA GitHub Actions evidence artifact with 90-day retention before local cleanup. The durable index must contain the run/artifact URL and prove it remains downloadable.
- Never print secrets or private user data. Public App Store submission is forbidden.
- Human-only rows are attempted through existing authorized browser/computer-control sessions first, then classified exactly as `BLOCKED_HUMAN` only after all independent work is complete.

## Ownership And Invalidation

- Canonical ownership is durably split at audit doing commit `c4d13881` and Desk commit `77a8c2d`: the coordinated worker owns only its current web merge/deploy train and native #52 until an explicit owner-release handoff; this task exclusively owns TestFlight, native worktree cleanup, and the delegated Unit 22 closure.
- Unit 0 remains nonterminal until the handoff references the exact final current-train web/native SHAs, merged PRs, CI/deploy evidence, and remaining work. After handoff, this task is the sole web merge/deploy owner; no later web merge/deploy may occur without coordination.
- Any change to web `origin/main` or its deployed SHA invalidates Unit 10. Any change to native `origin/main`, candidate notes, candidate build number, or required Native run invalidates Units 11-12 and requires a fresh candidate lock and validation rerun.
- Agent-owned failure is never a terminal blocker. It is adopted and fixed. Only the five named human-only rows may become `BLOCKED_HUMAN`.
- `upstream-crosswalk.md` is exhaustive. Units 10-12 cannot start until unmatched, `pending`, and agent-owned `active` counts are zero.

## Shared PR Gates

For each new unit, set `UNIT_ROOT=/tmp/spoonjoy-audit-release-train/<head-sha>/<unit>` and run under `set -o pipefail`. The exact focused-test file list is recorded before implementation in `evidence-index.md`.

### Web PR Gate

| Key | Exact operation | Required result / artifact |
| --- | --- | --- |
| `web.focused.red` | `pnpm exec vitest run $FOCUSED_TESTS --fileParallelism=false \|& tee "$UNIT_ROOT/01-focused-red.log"` before implementation | nonzero for the intended missing behavior; reason recorded |
| `web.focused.green` | same command after implementation, writing `02-focused-green.log` | exit 0 |
| `web.typechecks` | `{ pnpm run typecheck && pnpm run typecheck:scripts; } \|& tee "$UNIT_ROOT/03-typechecks.log"` | exit 0 |
| `web.coverage` | `pnpm run test:coverage \|& tee "$UNIT_ROOT/04-coverage.log"` | exit 0; 100% statements/branches/functions/lines |
| `web.e2e` | `pnpm run test:e2e \|& tee "$UNIT_ROOT/05-e2e.log"` | exit 0 |
| `web.builds` | `{ pnpm run build && pnpm run build-storybook; } \|& tee "$UNIT_ROOT/06-builds.log"` | exit 0 |
| `web.advisory` | `pnpm run advisory:scan -- --output "$UNIT_ROOT/advisory.json" \|& tee "$UNIT_ROOT/07-advisory.log"` | exit 0 |
| `web.warning` | `ruby /Users/arimendelow/Projects/spoonjoy-apple-audit-release-train/scripts/fail-on-warning.rb --log "$UNIT_ROOT/02-focused-green.log" --log "$UNIT_ROOT/03-typechecks.log" --log "$UNIT_ROOT/04-coverage.log" --log "$UNIT_ROOT/05-e2e.log" --log "$UNIT_ROOT/06-builds.log" --log "$UNIT_ROOT/07-advisory.log" \|& tee "$UNIT_ROOT/08-warning.log"` | exit 0; warning count 0 |
| `web.review` | Call `multi_agent_v1__spawn_agent` with `{agent_type:"default",fork_context:false,message:"Harsh review exact SHA <sha>, unit <unit>, artifacts <UNIT_ROOT>; return APPROVED or FINDINGS"}`, then `multi_agent_v1__wait_agent` with `{targets:[<id>],timeout_ms:600000}`; persist the verbatim verdict using `tools.apply_patch` to `$UNIT_ROOT/09-review.md` | only `APPROVED` passes; `FINDINGS` requires fixes, full gate rerun, and a fresh reviewer |
| `web.pr` | `gh pr checks "$PR" --repo spoonjoy/spoonjoy-v2 --watch --interval 20`, then `gh pr merge "$PR" --repo spoonjoy/spoonjoy-v2 --squash --delete-branch` | all checks green; merge SHA recorded |
| `web.main` | resolve the exact push CI/Storybook runs with `gh run list --repo spoonjoy/spoonjoy-v2 --commit "$MERGE_SHA" --json databaseId,workflowName,status,conclusion,headSha,url`; `gh run watch` each required run with `--exit-status` | exact SHA, CI and Storybook green |
| `web.deploy` | wait for or dispatch `gh workflow run production-deploy.yml --repo spoonjoy/spoonjoy-v2 --ref main -f source_sha="$MERGE_SHA"`; watch exact run and execute the Unit 19 matrix before admitting the next merge | exact SHA live; canary/cleanup green |

### Native PR Gate

| Key | Exact operation | Required result / artifact |
| --- | --- | --- |
| `native.focused.red` | `swift test --filter "$FOCUSED_TEST_FILTER" --disable-xctest -Xswiftc -warnings-as-errors \|& tee "$UNIT_ROOT/01-focused-red.log"` before implementation | nonzero for intended missing behavior |
| `native.focused.green` | same command after implementation, writing `02-focused-green.log` | exit 0 |
| `native.tests` | `swift test --disable-xctest --parallel -Xswiftc -warnings-as-errors \|& tee "$UNIT_ROOT/03-swift.log"` | exit 0 |
| `native.coverage` | `{ swift test --enable-code-coverage --disable-xctest --parallel -Xswiftc -warnings-as-errors && ruby scripts/enforce-swift-coverage.rb --coverage-json "$(swift test --show-codecov-path)" --minimum 100 --include Sources/SpoonjoyCore; } \|& tee "$UNIT_ROOT/04-coverage.log"` | exit 0; 100% core coverage |
| `native.scenario` | `scripts/verify-native-scenarios.sh --stage final --output "$UNIT_ROOT/scenario.json" \|& tee "$UNIT_ROOT/05-scenario.log"` | exit 0 |
| `native.builds` | `{ xcodebuild -project Spoonjoy.xcodeproj -scheme "Spoonjoy iOS" -configuration BootstrapDebug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES build && xcodebuild -project Spoonjoy.xcodeproj -scheme "Spoonjoy macOS" -configuration BootstrapDebug -destination "generic/platform=macOS" CODE_SIGNING_ALLOWED=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES build; } \|& tee "$UNIT_ROOT/06-builds.log"` | exit 0 |
| `native.advisory` | `ruby scripts/scan-ruby-advisories.rb --output "$UNIT_ROOT/advisory.json" \|& tee "$UNIT_ROOT/07-advisory.log"` | exit 0 |
| `native.warning` | `ruby scripts/fail-on-warning.rb --log "$UNIT_ROOT/02-focused-green.log" --log "$UNIT_ROOT/03-swift.log" --log "$UNIT_ROOT/04-coverage.log" --log "$UNIT_ROOT/05-scenario.log" --log "$UNIT_ROOT/06-builds.log" --log "$UNIT_ROOT/07-advisory.log" \|& tee "$UNIT_ROOT/08-warning.log"` | exit 0; warning count 0 |
| `native.review` | Call `multi_agent_v1__spawn_agent`, `multi_agent_v1__wait_agent`, then `tools.apply_patch` exactly as the web reviewer row, persisting `$UNIT_ROOT/09-review.md` | only `APPROVED`; findings force fixes/full rerun/fresh review |
| `native.pr` | `gh pr checks "$PR" --repo spoonjoy/spoonjoy-apple --watch --interval 20`, then `gh pr merge "$PR" --repo spoonjoy/spoonjoy-apple --squash --delete-branch` | all checks green; merge SHA recorded |
| `native.main` | resolve the exact Native push run with `gh run list --repo spoonjoy/spoonjoy-apple --workflow Native --commit "$MERGE_SHA" --json databaseId,status,conclusion,headSha,url`; `gh run watch "$RUN_ID" --repo spoonjoy/spoonjoy-apple --exit-status` | exact SHA Native run green |

## Rollback And Containment

| Class | Trigger | Exact mechanic | Proof |
| --- | --- | --- | --- |
| `WEB_REVERT` | pre-deploy contract/test regression | Revert the unit commit in a new PR; rerun Web PR Gate | exact revert SHA green; no production change before merge |
| `WEB_RELEASE` | production canary/smoke/telemetry regression | `gh workflow run production-deploy.yml --repo spoonjoy/spoonjoy-v2 --ref main -f source_sha="$WEB_PRIOR_GOOD_SHA" -f rollback_version_id="$WEB_PRIOR_GOOD_VERSION_ID"`; watch with `gh run watch --exit-status` | release artifact/live Cloudflare version maps to prior-good SHA; smokes and zero-residue cleanup pass |
| `APPLE_SWITCH` | clean callback registration/canary/default regression | keep or restore legacy start configuration in a reviewed PR and deploy through `WEB_RELEASE`; never remove legacy handler | legacy and clean callback canaries pass; starts resolve to intended callback |
| `LOCAL_DATA` | dry-run/apply mismatch or retained-owner drift | abort transaction or restore the private pre-apply snapshot/manifest; fix matcher before rerun | retained checksums match; disposable residue zero |
| `NATIVE_REVERT` | pre-TestFlight native regression | revert in reviewed PR and rerun Native PR/Unit 20 gates | exact new main SHA green; no immutable build changed |
| `TESTFLIGHT_CONTAIN` | upload/publish/dogfood finds bad build | stop before notify apply when possible; otherwise run `scripts/contain-testflight-build.sh --mode dry-run` then `--mode apply --build-id "$BUILD_ID" --group-id "$GROUP_ID" --expire`, followed by ASC relationship/state GETs; publish only a newly validated forward-fix build | group relationship absent and build expired, or forward-fix build verified; receipt stored |
| `CLEANUP_RECOVERY` | deletion inventory is dirty/unpushed/unreachable/ambiguous | skip deletion; create/push recovery ref; never `reset --hard`, `clean -fd`, or discard stashes | recovery ref resolves; preserved path/owner recorded |

## Telemetry Observation Contract

- Before publish, capture a 24-hour baseline keyed by deployed web SHA and native `app_version`/`build_number`: ASC screenshot/crash submissions, feedback reconciliation, PostHog `spoonjoy.native.telemetry` events, API lifecycle 5xx/error codes, and production smoke results. Unit 6B adds `pnpm run telemetry:native:release -- --build "$BUILD_NUMBER" --window-hours 24 --output <path>` with tests and redaction.
- After internal publication, observe for at least 30 minutes while installed/simulator dogfood runs. Fail and re-enter repair if there is any new TestFlight crash/actionable feedback, any build-correlated auth/sync/cover failure from the release smoke, or API 5xx rate exceeds `max(1%, 2x baseline)` with at least 20 requests. A no-sample window is recorded as `NO_SAMPLE` and never substitutes for dogfood.
- Every query records start/end UTC, app/build/SHA filters, event names, counts/rates, baseline, threshold, redaction statement, and artifact checksum. Secrets, tokens, emails, and private payloads are forbidden.

## Durable Evidence

- Unit 6B adds exact-SHA web/native evidence workflows that produce `spoonjoy-web-release-evidence-<sha>` and `spoonjoy-native-release-evidence-<sha>` GitHub Actions artifacts with `SHA256SUMS`, source manifest, logs, screenshots, ledgers, and 90-day retention.
- TestFlight already uploads exact-SHA candidate notes and publish artifacts with 90-day retention. Unit 14 verifies every indexed artifact URL remains downloadable after local `/tmp` removal.

The helper scripts and `release-evidence.yml` workflow named below are mandatory Unit 6B/9 deliverables. Their tests must prove exact-SHA selection, timeout behavior, redaction, idempotency, and artifact checksums before Units 10-12 may invoke them.

## Unit 19 Production Matrix

Set `WEB_ROOT=/tmp/spoonjoy-audit-release-train/$WEB_SHA/web-production`, `WEB_REPO=spoonjoy/spoonjoy-v2`, and `set -o pipefail`. Every row must persist its stdout/stderr and machine result below `WEB_ROOT`.

| Key | Exact operation | Required result / artifact |
| --- | --- | --- |
| `prod.lock` | `git fetch origin main && test "$(git rev-parse HEAD)" = "$WEB_SHA" && test "$(git rev-parse origin/main)" = "$WEB_SHA"` | exact validated checkout is still current main; `00-source-lock.log` |
| `prod.ci` | `scripts/resolve-exact-sha-runs.mjs --repo "$WEB_REPO" --sha "$WEB_SHA" --require CI --require Storybook --watch --timeout-minutes 60 --output "$WEB_ROOT/01-main-runs.json"` | unique successful exact-SHA push runs and URLs |
| `prod.deploy` | `scripts/dispatch-production-release.mjs --repo "$WEB_REPO" --source-sha "$WEB_SHA" --workflow production-deploy.yml --timeout-minutes 40 --output "$WEB_ROOT/02-production-run.json"` | adopt one already-successful exact-SHA run or dispatch/watch one new run; no ambiguous concurrent run |
| `prod.canary_artifact` | `gh run download "$(jq -r .runId "$WEB_ROOT/02-production-run.json")" --repo "$WEB_REPO" --name mcp-oauth-canary-artifacts --dir "$WEB_ROOT/03-canary" && jq -e --arg sha "$WEB_SHA" '.sourceSha == $sha and .status == "success" and (.cloudflareVersionId \| type == "string" and length > 0)' "$WEB_ROOT/03-canary/production-release.json"` | exact source SHA, successful promotion, Cloudflare version captured |
| `prod.live` | `pnpm run smoke:live -- --out "$WEB_ROOT/04-live" \|& tee "$WEB_ROOT/04-live.log"` | exit 0 |
| `prod.mcp` | `pnpm run smoke:mcp:oauth -- --out "$WEB_ROOT/05-mcp" \|& tee "$WEB_ROOT/05-mcp.log"` | exit 0; Claude/MCP OAuth and cleanup pass |
| `prod.api` | `pnpm run smoke:api -- --out "$WEB_ROOT/06-api" \|& tee "$WEB_ROOT/06-api.log"` | exit 0; auth/sync/cover contracts pass |
| `prod.providers` | `scripts/smoke-provider-callbacks.mjs --base-url https://spoonjoy.app --provider apple --provider google --provider github --apple-path clean --apple-path legacy --output "$WEB_ROOT/07-providers.json" \|& tee "$WEB_ROOT/07-providers.log"` | all start/callback canaries pass; clean Apple path is default and legacy remains live |
| `prod.owner` | `scripts/dogfood-owner-photo-studio.mjs --base-url https://spoonjoy.app --states default,spoon-off,editorial-off,processing,failure,empty,narrow --viewports mobile,desktop --output "$WEB_ROOT/08-owner" \|& tee "$WEB_ROOT/08-owner.log"` | authenticated owner flow and 14 deployed captures pass, or the named human row alone is classified `BLOCKED_HUMAN` |
| `prod.telemetry` | `pnpm run telemetry:native:release -- --web-sha "$WEB_SHA" --window-hours 24 --output "$WEB_ROOT/09-telemetry.json" \|& tee "$WEB_ROOT/09-telemetry.log"` | redacted 24-hour baseline, thresholds satisfied |
| `prod.cleanup` | `pnpm run cleanup:production -- --out "$WEB_ROOT/10-cleanup" \|& tee "$WEB_ROOT/10-cleanup.log"` | exit 0; disposable residue exactly zero; retained-owner checksums unchanged |
| `prod.evidence` | `gh workflow run release-evidence.yml --repo "$WEB_REPO" --ref main -f source_sha="$WEB_SHA" -f kind=web -f evidence_manifest="$(jq -r .manifest "$WEB_ROOT/evidence-upload.json")"` followed by `scripts/verify-release-evidence.mjs --repo "$WEB_REPO" --source-sha "$WEB_SHA" --name "spoonjoy-web-release-evidence-$WEB_SHA" --retention-days 90 --output "$WEB_ROOT/11-evidence.json"` | one downloadable exact-SHA artifact; `SHA256SUMS` verifies; no secret/private payload |

Any row failure runs the matching rollback/containment class, leaves Unit 10 nonterminal, and requires a fresh matrix from `prod.lock` after repair.

## Unit 21 TestFlight Matrix

Set `TF_ROOT=/tmp/spoonjoy-audit-release-train/$NATIVE_SHA/testflight`, `NATIVE_REPO=spoonjoy/spoonjoy-apple`, `ASC_APP_ID=6787505444`, and `ASC_INTERNAL_GROUP_ID=31d60f58-aef9-4d44-b047-3a1f0dc61b5e`. Commands run under `set -o pipefail`; credential paths and values are never printed.

| Key | Exact operation | Required result / artifact |
| --- | --- | --- |
| `tf.feedback` | `scripts/testflight-feedback-autopilot.mjs doctor > "$TF_ROOT/00-feedback-doctor.json" && scripts/testflight-feedback-autopilot.mjs status --plain > "$TF_ROOT/00-feedback-status.txt" && scripts/testflight-feedback-autopilot.mjs reconcile --dry-run > "$TF_ROOT/00-feedback-reconcile.json" && scripts/testflight-feedback-autopilot.mjs deliveries --since "$(date -u -v-24H '+%Y-%m-%dT%H:%M:%SZ')" > "$TF_ROOT/00-feedback-deliveries.json"` | listener/tunnel/reconcile healthy; zero unhandled actionable feedback; Apple delivery path current |
| `tf.kit` | `scripts/check-apple-distribution-kit.sh \|& tee "$TF_ROOT/01-distribution-kit.log"` | exit 0; pinned kit/config/signing contract passes without secret output |
| `tf.native_run` | `scripts/verify-testflight-release-candidate.rb --source-sha "$NATIVE_SHA" --repository "$NATIVE_REPO" --allow-rollback false --output-dir "$TF_ROOT/02-candidate" \|& tee "$TF_ROOT/02-candidate.log"` | exact current-main SHA has one successful Native push run and fresh note bytes |
| `tf.build_reserve` | `scripts/reserve-testflight-build-number.sh --app-id "$ASC_APP_ID" --source-sha "$NATIVE_SHA" --mode dry-run --artifact "$TF_ROOT/03-reserve-dry.json" && scripts/reserve-testflight-build-number.sh --app-id "$ASC_APP_ID" --source-sha "$NATIVE_SHA" --mode apply --artifact "$TF_ROOT/03-reserve-apply.json"` | one numeric number greater than every ASC build; duplicate reservation is idempotent |
| `tf.lock` | `scripts/lock-testflight-candidate.sh --source-sha "$NATIVE_SHA" --native-run "$(jq -r .runId "$TF_ROOT/02-candidate/candidate.json")" --notes "$TF_ROOT/02-candidate/testflight-release-notes.json" --build-number "$(jq -r .buildNumber "$TF_ROOT/03-reserve-apply.json")" --app-id "$ASC_APP_ID" --group-id "$ASC_INTERNAL_GROUP_ID" --mode apply --artifact "$TF_ROOT/04-candidate-lock.json"` | immutable lock contains source/run/note checksum/build/app/group/prior-good/timestamp; current main and notes still match |
| `tf.dispatch` | `scripts/dispatch-testflight-candidate.sh --repo "$NATIVE_REPO" --source-sha "$NATIVE_SHA" --build-number "$(jq -r .buildNumber "$TF_ROOT/04-candidate-lock.json")" --allow-rollback false --timeout-minutes 125 --output "$TF_ROOT/05-workflow-run.json"` | exactly one TestFlight workflow run owns the lock; same-lock success is adopted; unknown duplicate fails closed |
| `tf.artifacts` | `gh run download "$(jq -r .runId "$TF_ROOT/05-workflow-run.json")" --repo "$NATIVE_REPO" --dir "$TF_ROOT/06-artifacts" && scripts/verify-testflight-publish-artifacts.rb --lock "$TF_ROOT/04-candidate-lock.json" --root "$TF_ROOT/06-artifacts" --require-dry-run --require-apply --require-notify-request --require-retention-days 90 \|& tee "$TF_ROOT/06-artifacts.log"` | candidate note, IPA publish logs, dry-run/apply receipts, source/build/note checksum and notification request match lock |
| `tf.app` | `scripts/apple-distribution-kit.sh asc get --path /v1/apps --query 'filter[bundleId]=app.spoonjoy' --query limit=1 --json > "$TF_ROOT/07-asc-app.json"` | exactly app `6787505444` |
| `tf.build` | `scripts/apple-distribution-kit.sh asc get --path /v1/builds --query "filter[app]=$ASC_APP_ID" --query 'filter[preReleaseVersion.platform]=IOS' --query 'filter[processingState]=VALID' --query 'sort=-uploadedDate' --query 'include=buildBetaDetail' --query limit=100 --json > "$TF_ROOT/08-asc-build.json"` | locked build is newest matching build number, `VALID`, exact build ID and beta-detail relationship |
| `tf.beta_detail` | `scripts/apple-distribution-kit.sh asc get --path "/v1/buildBetaDetails/$ASC_BUILD_BETA_DETAIL_ID" --json > "$TF_ROOT/09-asc-beta-detail.json"` | `internalBuildState == IN_BETA_TESTING` |
| `tf.group_builds` | `scripts/apple-distribution-kit.sh asc get --path "/v1/betaGroups/$ASC_INTERNAL_GROUP_ID/builds" --query limit=100 --json > "$TF_ROOT/10-asc-group-builds.json"` | exact locked build ID attached only to intended internal group |
| `tf.testers` | `scripts/apple-distribution-kit.sh asc get --path "/v1/betaGroups/$ASC_INTERNAL_GROUP_ID/betaTesters" --query limit=200 --json > "$TF_ROOT/11-asc-testers.json"` | tester count greater than zero |
| `tf.notes` | `scripts/apple-distribution-kit.sh asc get --path "/v1/builds/$ASC_BUILD_ID/betaBuildLocalizations" --query limit=200 --json > "$TF_ROOT/12-asc-notes.json" && scripts/verify-testflight-notes.rb --lock "$TF_ROOT/04-candidate-lock.json" --asc "$TF_ROOT/12-asc-notes.json"` | English `whatsNew` is byte-identical to locked notes |
| `tf.feedback_asc` | `scripts/apple-distribution-kit.sh asc get --path "/v1/apps/$ASC_APP_ID/betaFeedbackScreenshotSubmissions" --query limit=50 --json > "$TF_ROOT/13-asc-screenshots.json" && scripts/apple-distribution-kit.sh asc get --path "/v1/apps/$ASC_APP_ID/betaFeedbackCrashSubmissions" --query limit=50 --json > "$TF_ROOT/13-asc-crashes.json"` | no new crash/actionable item correlated to locked build |
| `tf.observe` | `pnpm run telemetry:native:release -- --build "$(jq -r .buildNumber "$TF_ROOT/04-candidate-lock.json")" --window-minutes 30 --compare "$TF_ROOT/prepublish-24h.json" --output "$TF_ROOT/14-postpublish.json"` from exact deployed web main | at least 30 elapsed minutes; telemetry threshold passes; `NO_SAMPLE` never substitutes for functional dogfood |

The workflow's `ci-publish-testflight.sh` must visibly execute `xcode run --kind altool-upload --platform ios --mode apply`, poll up to 120 times at 30 seconds for the locked build to become `VALID`, execute `testflight publish --mode dry-run` before `--mode apply`, poll the group relationship and beta state up to 20 times at 15 seconds, and request tester notification only during apply. A failure after upload invokes `TESTFLIGHT_CONTAIN`; it never reuses the immutable build number.

## Feedback And Cleanup Matrix

| Key | Exact operation | Required result / artifact |
| --- | --- | --- |
| `feedback.install` | `scripts/testflight-feedback-autopilot.mjs install-launchd` | three launchd agents point at the current canonical checkout |
| `feedback.health` | `curl -fsS http://127.0.0.1:48973/health` and `curl -fsS https://spoonjoy-testflight-feedback.ouro.bot/health` | both healthy and same contract version |
| `feedback.exercise` | `scripts/testflight-feedback-autopilot.mjs smoke`, `ping`, `doctor`, `status`, `deliveries`, and `reconcile --dry-run` | all pass; no missed feedback; no wake on no-feedback |
| `feedback.launchd` | `launchctl print "gui/$(id -u)/com.spoonjoy.testflight-feedback-listener"`, `...-tunnel`, and `...-reconcile` | all loaded/running with current paths |
| `cleanup.inventory` | `scripts/inventory-release-worktrees.sh --repo /Users/arimendelow/Projects/spoonjoy-v2 --repo /Users/arimendelow/Projects/spoonjoy-apple --output "$CLEANUP_ROOT/deletion-allowlist.json"` | every worktree/branch/stash has owner, HEAD, upstream, dirty/untracked/unpushed/reachability/recovery/disposition fields |
| `cleanup.review` | fresh harsh cleanup reviewer over allowlist and recovery proofs | `APPROVED`; dirty, active, unpushed, or ambiguous entries preserved |
| `cleanup.apply` | `scripts/apply-release-worktree-cleanup.sh --allowlist "$CLEANUP_ROOT/deletion-allowlist.json" --mode dry-run`, then `--mode apply` | only terminal allowlisted entries removed; every recovery ref still resolves; no reset/clean/stash deletion |
| `cleanup.final` | canonical web/native fetch + fast-forward to exact current main, `git status --porcelain=v1`, artifact redownload/checksum, Desk/task terminal updates, continuation scan, Slugger message | clean canonical checkouts; immutable evidence survives local cleanup; no ready agent work remains |

## Completion Criteria
- [ ] Every accepted planning criterion is represented by a terminal unit below.
- [ ] All agent-owned web/native units are merged and exact-main checks are green.
- [ ] Exact final web SHA is deployed with complete Unit 18/19 evidence and zero disposable residue.
- [ ] Exact final native SHA has complete Unit 20 evidence with `fullyValidated: true`, zero blockers, zero warnings, and closed visual ledgers.
- [ ] Exact native SHA is published as a new internal TestFlight build, processed `VALID`, attached to `Spoonjoy Internal`, in `IN_BETA_TESTING`, and has exact build-specific notes.
- [ ] Notification apply success and any independently observed tester receipt are reported distinctly.
- [ ] Feedback automation is healthy and reports zero unhandled actionable feedback after publication.
- [ ] Both repositories and Desk have terminal, truthful cleanup state; Slugger receives the final status.
- [ ] 100% changed/new code coverage, all tests pass, no warnings.

## Work Units

### 🔄 Unit 0: Adopt Approved Plan And Live Ownership
**What**: Converge the release plan, record the canonical audit doing doc, preserve the parallel worker boundary, and create the durable evidence index.
**Output**: Approved planning doc, this doing doc, evidence index, exhaustive upstream crosswalk, canonical doing commit `c4d13881`, Desk commit `77a8c2d`, and explicit coordinated-worker owner-release handoff.
**Acceptance**: Fresh doing reviewers return `APPROVED`; no duplicate TestFlight owner exists; the crosswalk has zero unmatched rows; the handoff contains exact SHAs/PRs/CI/deploy evidence and releases exclusive web merge/deploy ownership.

### 🔄 Unit 1: Adopt Current Merge And Deploy Train
**What**: Let the coordinated worker finish native #52 and web #266/#270/#271/#272, including repairs, rebases, green checks, merges, main CI, and serialized exact-SHA production deploys. Refresh the evidence index after every handoff.
**Output**: Exact web/native merge SHAs, PR/run URLs, deployment versions, smoke/cleanup artifacts.
**Acceptance**: Every listed agent-owned PR is merged with exact merge SHA, green PR/main CI, and required deployment evidence; native #52 is green on main; no agent-owned blocker is terminal. The coordinated worker sends the owner-release handoff and starts no later web merge/deploy without coordination.

### ⬜ Unit 2A: Clean Apple Callback Registration And Canary (3j)
**What**: Use the existing authorized Apple Developer browser session to add `https://spoonjoy.app/auth/apple/callback` without removing the legacy callback; capture redacted portal evidence and canary GET/POST behavior for both paths.
**Acceptance**: Registration plus both canaries pass before source/config selects the clean path. If existing sessions cannot authenticate, record the exact `BLOCKED_HUMAN` prerequisite/action and keep Units 2B-2D nonterminal/blocked without affecting independent work.

### ⬜ Unit 2B: Clean Apple Start-Switch Red Tests (3k / W5)
**Tests first**: Add failing configuration tests proving clean starts require Unit 2A's evidence checksum, unknown/stale evidence is rejected, and legacy rollback remains selectable.
**Acceptance**: Focused tests fail for the intended current legacy-default behavior and for any switch lacking the prerequisite checksum; red artifact is retained.

### ⬜ Unit 2C: Clean Apple Start-Switch Implementation (3l / W5)
**Implementation**: Switch only new Apple starts behind validated configuration, retain both handlers and one-commit/config rollback, then run the full Web PR Gate and open an atomic W5 PR.
**Acceptance**: Unit 2B passes; full gate and reviewer pass; W5 merges only after Unit 2A.

### ⬜ Unit 2D: Clean Apple Start Deployment And Rollback Proof (3m)
**Verification**: Serialize the exact W5 main deploy; run clean/legacy Apple canaries plus Google/GitHub regressions; exercise `APPLE_SWITCH` rollback proof without removing the clean handler.
**Acceptance**: Exact W5 SHA is live, clean is default, both paths and rollback proof pass, reviewer `APPROVED`.

### ⬜ Unit 3: Local OAuth Teardown (W8)
**Tests first**: Cover dry-run/apply parity, generated-client dependency cleanup, snapshots/manifests, transactions, retained-owner refusal/checksums, partial failures, reruns, recovery, and exact residue.
**Implementation**: Add local-only dependency-aware teardown for disposable OAuth clients/credentials/codes/tokens and related test data; open an atomic web PR.
**Verification**: Run the full Web PR Gate, then two apply/verify cleanup cycles and a fresh data-safety reviewer.
**Acceptance**: Local before/apply/after ends at zero disposable residue without touching retained users; rerun is idempotent.

### ⬜ Unit 4: Web Repository Cleanup And Guard (W9)
**Tests first**: Cover tracked database/generated artifacts, fixture allowlists, durable Markdown preservation, PR-size thresholds, body manifest requirements, and external evidence routing.
**Implementation**: Privately inventory and remove only manifest-approved artifacts/database state, add recovery refs and future guards, and open an atomic web PR.
**Verification**: Redacted scan, full Web PR Gate, hygiene policy, `git count-objects -vH`, recovery test, and fresh security/repository review.
**Acceptance**: Current web tree is clean; no secret or durable evidence is lost; no unauthorized history rewrite occurs.

### ⬜ Unit 5: Native Mutation Single-Flight And Retry Identity (N3)
**Tests first**: Cover the full cover-operation conflict matrix, synchronous double taps, stable IDs across same-payload retry/offline ownership/replay, payload changes, cancel/dismiss, unlock behavior, `idempotency_in_progress`, stage retention, and durable queue ownership.
**Implementation**: Add a testable cover mutation state machine, globally disable conflicts, show operation-specific progress, preserve retry identity, and wire native routes; open an atomic native PR after #52 lands.
**Verification**: Run the full Native PR Gate and fresh concurrency/idempotency review.
**Acceptance**: Duplicate plans cannot form; retries preserve identity and staged media until server success or durable queue ownership.

### ⬜ Unit 6A: Native Photo Studio Product Truth And 21-Entry Visual Harness (N5)
**Tests first**: Cover Spoon gating/nil suppression, optional date, multiline direction, prompts, dynamic outcomes, automatic activation, processing/failure recovery, deterministic screenshot routes, accessibility, and route counts.
**Implementation**: Split draft/presentation from orchestration; implement truthful minimum-click controls/states; add explicit iPhone, iPad, and macOS capture outputs for all seven states plus a machine-readable 21-row manifest; open atomic N5 PR.
**Verification**: Run the full Native PR Gate; assert the manifest has exactly 21 unique state/platform rows, every file exists/nonblank, accessibility proofs validate, and visual reviewer/ledger pass.
**Acceptance**: Native behavior is truthful and all 21 captures are stable, non-overlapping, and direct.

### ⬜ Unit 6B: Web Visual, Telemetry, And Durable Evidence Harness (W17)
**Tests first**: Add failing Playwright/script/workflow contracts for the seven Photo Studio states on mobile/desktop, build-scoped telemetry queries/redaction/thresholds, exact-SHA evidence manifests, checksums, retention, and artifact names.
**Implementation**: Add `e2e/visual/photo-studio-states.spec.ts`, `pnpm run telemetry:native:release`, `scripts/resolve-exact-sha-runs.mjs`, `scripts/dispatch-production-release.mjs`, `scripts/smoke-provider-callbacks.mjs`, `scripts/dogfood-owner-photo-studio.mjs`, `scripts/verify-release-evidence.mjs`, and exact-SHA `release-evidence.yml` workflows in atomic web/native harness PRs with disjoint files.
**Verification**: Run Web and Native PR Gates independently; dispatch both evidence workflows and verify artifact download/checksums/90-day retention.
**Acceptance**: Web has 14 state/viewport captures; native evidence preserves the 21-entry manifest; telemetry query contract is build-scoped/redacted; both immutable artifacts are downloadable.

### ⬜ Unit 7: Native Cover Codec Extraction (N7)
**Tests first**: Add structural and exact-wire-parity tests requiring cover payload encode/decode outside `NativeSyncEngine.swift`.
**Implementation**: Extract a narrow cover codec without weakening unrelated visibility; open atomic native PR.
**Verification**: Run after Unit 5, using the full Native PR Gate and fresh architecture/API-compatibility review.
**Acceptance**: Exact persisted/wire behavior is unchanged and codec ownership is isolated.

### ⬜ Unit 8: Native Cover Queue Transport Extraction (N8)
**Tests first**: Require cover queue factories/replay transport outside the main sync engine while preserving retry, staged media, and persisted-kind behavior.
**Implementation**: Extract queue factories and replay transport behind narrow internal interfaces; open atomic native PR after N7.
**Verification**: Run after Unit 7, using the full Native PR Gate, offline replay scenarios, and fresh architecture/concurrency review.
**Acceptance**: Queue/retry behavior is unchanged and transport ownership is isolated.

### ⬜ Unit 9: Build-Specific TestFlight Notes (N10)
**Tests first**: Tie source SHA, build number, user-facing manifest, and note freshness; require current image, mutation, Photo Studio, and provider-sign-in changes.
**Implementation**: Generate/validate notes from the designated candidate and reject stale/mismatched metadata; open atomic native PR without publishing.
**Implementation**: Also add `scripts/lock-testflight-candidate.sh`, `scripts/reserve-testflight-build-number.sh`, `scripts/dispatch-testflight-candidate.sh`, `scripts/verify-testflight-publish-artifacts.rb`, `scripts/verify-testflight-notes.rb`, and `scripts/contain-testflight-build.sh`, each with duplicate/idempotency, redaction, timeout, exact-lock, and rollback tests; mutation-capable helpers expose dry-run/apply.
**Verification**: Run after Units 5, 7, 8, and 6A so notes cover the final feature set; use the full Native PR Gate and fresh release-copy/automation review.
**Acceptance**: Exact candidate metadata is accepted and stale build-35-era notes are rejected.

### ⬜ Unit 10: Final Web Unit 18 Validation And Production Dogfood
**What**: After the owner-release barrier and zero-pending crosswalk gate, create a clean exact-main validation worktree and run every command in the approved Unit 18 evidence matrix, fresh reviewers, then the executable Unit 19 matrix: assert validated SHA equals current main; resolve/watch exact CI/Storybook/Production Deploy run; download and validate `production-release.json`; run `smoke:live`, `smoke:mcp:oauth`, `smoke:api`, provider/callback canaries, authenticated owner Photo Studio, all seven deployed web state captures, `cleanup:production`, and artifact upload/checksum verification.
**Output**: `/tmp/spoonjoy-audit-release-train/<web-sha>/web/` plus indexed hashes/run URLs/Cloudflare version.
**Acceptance**: Every command exits zero with 100% coverage and zero warnings; reviewer findings are fixed and the matrix reruns; exact SHA/Cloudflare version match; all seven mobile/desktop deployed states pass; zero residue remains. Any new web main/deploy invalidates and restarts Unit 10.

### ⬜ Unit 11: Final Native Unit 20 Validation And Visual Dogfood
**What**: Create a clean exact-main validation worktree and run every command in the approved Unit 20 evidence matrix, including all route/state screenshots and fresh implementation/test/security/visual reviewers.
**Output**: `/tmp/spoonjoy-audit-release-train/<native-sha>/native/` plus indexed hashes/run URLs/screenshots/ledgers.
**Acceptance**: Aggregate matrix is `fullyValidated: true`; no blocker/warning; the 21-entry Photo Studio manifest and every other route pass; exact-SHA evidence artifact downloads/checksums; all reviewer findings are fixed and the exact SHA rerun. Any native main change invalidates Unit 11.

### ⬜ Unit 12A: Feedback/Telemetry Preflight And Candidate Lock
**What**: Run feedback doctor/status/reconcile/deliveries, ASC screenshot/crash/build queries, 24-hour telemetry baseline, distribution-kit check, exact Native-run verification, candidate-note checksum, and build-number reservation. Write an immutable candidate lock containing native SHA, Native run ID/URL, notes bytes/checksum, build number, app/group IDs, prior-good build, and timestamp.
**Acceptance**: Zero actionable feedback/crashes; thresholds pass; exact SHA still equals main; build number has no duplicate; note bytes are final. Any SHA/note/build-number change deletes the lock and restarts Unit 11/12A.

### ⬜ Unit 12B: Exact-SHA TestFlight Dispatch And Upload
**What**: Run `gh workflow run testflight.yml --repo spoonjoy/spoonjoy-apple --ref main -f source_sha="$NATIVE_SHA" -f allow_rollback=false -f build_number="$BUILD_NUMBER"`; resolve the unique run, enforce a 125-minute timeout with `gh run watch --exit-status`, download both 90-day artifacts, and compare source/note/build fields to the lock.
**Acceptance**: One run owns the reserved build. An existing successful same-lock run is adopted; an unknown duplicate invalidates/reserves a higher number before redispatch. Upload becomes `VALID`; no notification claim is made yet.

### ⬜ Unit 12C: Dry-Run, Internal Publish, And Notification Apply
**What**: Inspect `testflight-publish-dry-run.json`; apply only with zero blockers and exact lock match; verify apply artifact records the group relationship, exact `whatsNew`, and notification request. Notification is inert before apply.
**Acceptance**: Build is attached only to `Spoonjoy Internal`; apply succeeds; notification operation is accepted. Any failure runs `TESTFLIGHT_CONTAIN` and remains nonterminal.

### ⬜ Unit 12D: ASC Relationship Verification And Observation Window
**What**: Query app/build/buildBetaDetail/group/builds/testers/betaBuildLocalizations; verify `VALID`, nonzero testers, `IN_BETA_TESTING`, byte-identical `whatsNew`, and apply receipt. Observe feedback/telemetry for at least 30 minutes using the telemetry contract.
**Acceptance**: All ASC relationships and thresholds pass; notification apply versus independently observed receipt are reported distinctly.

### ⬜ Unit 13: Installed Dogfood And Five Human Dispositions
**What**: Exercise installed provider sign-in, HEIC cover, mutation lock, queue replay, Photo Studio, and cleanup when an authorized physical-device path exists. Resolve or exactly classify Clem credential retirement, Apple callback registration, any secret rotation, owner Photo Studio smoke, and installed TestFlight dogfood.
**Acceptance**: No human-only item is hidden. Any functional failure creates a repair PR, invalidates the candidate, reruns Unit 11, and publishes a newer build through Units 12A-12D; only unavailable human/device access may become `BLOCKED_HUMAN`. The canonical audit task is `done` only if all five close.

### ⬜ Unit 14: Feedback Health, Cleanup, Desk Closure, And Slugger Notification
**What**: Tests-first add `scripts/inventory-release-worktrees.sh` and `scripts/apply-release-worktree-cleanup.sh`; run the exact feedback health commands in `docs/apple-distribution.md`; inventory both repos into the deletion allowlist fields `owner,path,branch,HEAD,upstream,dirty,untracked,stashes,unpushed,recovery_ref,reachability,disposition`; obtain fresh cleanup review; remove only allowlisted terminal worktrees/branches; prohibit destructive reset/clean; verify recovery refs after each deletion; restore canonical clean exact-main checkouts; verify immutable artifacts remain downloadable after `/tmp` removal; update planning/doing/evidence/Desk state; continuation scan; `ouro msg --to slugger` with shipped/blocker/build details.
**Acceptance**: Feedback path healthy with zero actionable backlog; 30-minute telemetry window complete; no ready agent work remains; dirty/active/ambiguous work is preserved; recovery proofs pass; both canonical repos are clean current main; release task is terminal and canonical/Desk task is `done` or exact `BLOCKED_HUMAN`; Slugger receives exact status.

## Execution Order
1. Unit 1 runs under the coordinated worker until the explicit owner-release barrier. This task starts no web merge/deploy before that handoff.
2. Units 2A-2D, 3, 4, and 6B then serialize web merges/deploys under this task's sole ownership.
3. After native #52, serialize shared cover ownership as Unit 5 (N3) -> Unit 7 (N7) -> Unit 8 (N8) -> Unit 6A (N5) -> Unit 9 (N10). No parallel writes touch sync/queue/cover orchestration.
4. Unit 10 waits for zero pending web crosswalk rows; Unit 11 waits for zero pending native rows and final web production contracts.
5. Units 12A-12D publish only the locked Unit 11 SHA. Any drift or dogfood defect re-enters repair and validation.
6. Units 13-14 close installed/human status, telemetry, immutable evidence, cleanup, Desk, and Slugger.

## Progress Log
- 2026-07-16 09:34 Converted from approved planning doc; current merge/deploy work remains owned by the coordinated audit worker and this task retains exclusive TestFlight publication ownership.
- 2026-07-16 09:52 Addressed doing-review findings: durable ownership commits, exhaustive upstream crosswalk, exclusive merge barrier, split callback/TestFlight units, serialized native shared ownership, executable PR/rollback/telemetry/evidence contracts, candidate invalidation, installed-failure re-entry, and recovery-safe cleanup.
