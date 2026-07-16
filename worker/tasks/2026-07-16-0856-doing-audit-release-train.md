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
- Raw logs, screenshots, binaries, and reports are staged in `/tmp/spoonjoy-audit-release-train/<source-sha>/`, redacted/scanned, bundled with `SHA256SUMS`, transferred through a private draft GitHub release into an exact-SHA GitHub Actions evidence artifact with 90-day retention, and only then removed locally. The ingest workflow verifies the source/checksum before upload and deletes the draft release/tag afterward. The durable index must contain the run/artifact URL and prove it remains downloadable.
- Never print secrets or private user data. Public App Store submission is forbidden.
- Human-only rows are attempted through existing authorized browser/computer-control sessions first, then classified exactly as `BLOCKED_HUMAN` only after all independent work is complete.

## Ownership And Invalidation

- Canonical ownership is durably split at audit doing commit `c4d13881` and Desk commit `77a8c2d`: the coordinated worker owns only its current web merge/deploy train and native #52 until an explicit owner-release handoff; this task exclusively owns TestFlight, native worktree cleanup, and the delegated Unit 22 closure.
- Unit 0 remains nonterminal until the handoff references the exact final current-train web/native SHAs, merged PRs, CI/deploy evidence, remaining work, `zero_in_flight_web_merges=true`, `zero_in_flight_web_deploys=true`, the releasing task/thread and commit, and `web_cleanup_owner`. The coordinated worker commits and pushes the release record; this task commits and pushes a receiver acknowledgement that repeats the same fields before it becomes sole web merge/deploy owner. No later web merge/deploy may occur without coordination.
- Web cleanup remains with the coordinated worker unless that signed handoff explicitly sets `web_cleanup_owner=019f2e25-2fc3-75b2-8ba3-335f3777115a`. This task always owns native cleanup; it may inventory web state but cannot delete web state without that explicit grant.
- Any change to web `origin/main` or its deployed SHA invalidates Unit 10. Any change to native `origin/main`, candidate notes, candidate build number, or required Native run invalidates Units 11-12 and requires a fresh candidate lock and validation rerun.
- Agent-owned failure is never a terminal blocker. It is adopted and fixed. Only the five named human-only rows may become `BLOCKED_HUMAN`.
- `upstream-crosswalk.md` is exhaustive. Units 10-12 cannot start until unmatched, `pending`, and agent-owned `active` counts are zero.

## Shared PR Gates

For each new unit, set `UNIT_ROOT=/tmp/spoonjoy-audit-release-train/<head-sha>/<unit>` and run under `set -o pipefail`. The exact focused-test file list is recorded before implementation in `evidence-index.md`.

Before any reviewer row, the primary executor persists `$UNIT_ROOT/reviewer-tool-preflight.json` proving the active host exposes `multi_agent_v1__spawn_agent` and `multi_agent_v1__wait_agent`. Missing tools stop execution for host repair; reviewer gates cannot be self-approved or silently substituted.

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
| `web.main` | `gh run list --repo spoonjoy/spoonjoy-v2 --commit "$MERGE_SHA" --limit 100 --json databaseId,workflowName,status,conclusion,headSha,url > "$UNIT_ROOT/10-main-runs.json"`; assert with `jq -e --arg sha "$MERGE_SHA" '[.[] \| select(.headSha == $sha and (.workflowName == "CI" or .workflowName == "Storybook"))] as $r \| ($r \| map(.workflowName) \| unique \| sort) == ["CI","Storybook"] and all($r[]; .status == "completed" and .conclusion == "success")'`; watch every selected database ID with `gh run watch "$id" --repo spoonjoy/spoonjoy-v2 --exit-status` and then repeat the assertion | exact SHA, unique required workflow names, all successful; IDs/URLs persisted |
| `web.deploy` | after Unit 6B lands, `scripts/dispatch-production-release.mjs --repo spoonjoy/spoonjoy-v2 --source-sha "$MERGE_SHA" --workflow production-deploy.yml --timeout-minutes 40 --output "$UNIT_ROOT/11-production-run.json"`; Unit 6B itself uses the same helper's focused integration fixture before its first production use | one adopted or newly dispatched exact-SHA run, explicit run ID watched; Unit 19 canary/cleanup evidence green before next merge |

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
| `native.main` | `gh run list --repo spoonjoy/spoonjoy-apple --workflow Native --commit "$MERGE_SHA" --limit 20 --json databaseId,status,conclusion,headSha,url > "$UNIT_ROOT/10-native-main-runs.json"`; set `RUN_ID` only after `jq -e --arg sha "$MERGE_SHA" '[.[] \| select(.headSha == $sha)] \| length == 1 and .[0].status == "completed" and .[0].conclusion == "success"'`; then `RUN_ID="$(jq -r --arg sha "$MERGE_SHA" '.[] \| select(.headSha == $sha) \| .databaseId' "$UNIT_ROOT/10-native-main-runs.json")"` and `gh run watch "$RUN_ID" --repo spoonjoy/spoonjoy-apple --exit-status` | one exact-SHA Native run, explicit run ID/URL, green |

## Rollback And Containment

| Class | Trigger | Exact mechanic | Proof |
| --- | --- | --- | --- |
| `WEB_REVERT` | pre-deploy contract/test regression | Revert the unit commit in a new PR; rerun Web PR Gate | exact revert SHA green; no production change before merge |
| `WEB_RELEASE` | production canary/smoke/telemetry regression | `scripts/dispatch-production-release.mjs --repo spoonjoy/spoonjoy-v2 --source-sha "$WEB_PRIOR_GOOD_SHA" --rollback-version-id "$WEB_PRIOR_GOOD_VERSION_ID" --workflow production-deploy.yml --timeout-minutes 40 --output "$ROLLBACK_ROOT/web-release.json"`; watch the explicit recorded run ID | release artifact/live Cloudflare version maps to prior-good SHA; smokes and zero-residue cleanup pass |
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

- Unit 6B adds `scripts/stage-release-evidence.sh`, exact-SHA web/native evidence-ingest workflows, and `scripts/verify-release-evidence.mjs`. The staging helper redacts/scans the local bundle, writes `SHA256SUMS`, creates a nonce-scoped private draft GitHub release, uploads only the bundle/checksum, and dispatches the ingest workflow with the tag and expected checksum. The workflow downloads and verifies that exact draft asset, uploads `spoonjoy-<kind>-release-evidence-<sha>` with 90-day retention, then deletes the draft release/tag. Any failure preserves the staging object for repair and records it; it never deletes local evidence.
- Unit 11 repeats native ingest after the final native SHA is locked. Unit 10 repeats web ingest after the final deployed SHA is locked. Unit 14 runs `scripts/verify-release-evidence-index.rb`, redownloads every indexed artifact, verifies `SHA256SUMS`, and rejects any placeholder or nonterminal row before `/tmp` cleanup.
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
| `prod.cleanup` | `pnpm run cleanup:production -- --output "$WEB_ROOT/10-cleanup.json" \|& tee "$WEB_ROOT/10-cleanup.log"` after Unit 6B adds/tests the fail-closed `--output` contract; then `jq -e '.targetEnv == "production" and .mode == "dry-run" and .disposableResidue == 0 and .retainedOwnerChecksumsUnchanged == true' "$WEB_ROOT/10-cleanup.json"` | exit 0; production broad cleanup remains read-only; exact zero-residue machine artifact exists |
| `prod.evidence` | `scripts/stage-release-evidence.sh --repo "$WEB_REPO" --kind web --source-sha "$WEB_SHA" --root "$WEB_ROOT" --output "$WEB_ROOT/11-evidence-stage.json"`, then `scripts/verify-release-evidence.mjs --repo "$WEB_REPO" --source-sha "$WEB_SHA" --name "spoonjoy-web-release-evidence-$WEB_SHA" --retention-days 90 --require-staging-cleanup --output "$WEB_ROOT/11-evidence.json"` | one downloadable exact-SHA artifact; `SHA256SUMS` verifies; draft release/tag removed; no secret/private payload |

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
| `tf.baseline` | from exact deployed web main, `pnpm run telemetry:native:release -- --prior-build "$(jq -r .priorGoodBuild "$TF_ROOT/04-candidate-lock.json")" --candidate-build "$(jq -r .buildNumber "$TF_ROOT/04-candidate-lock.json")" --candidate-sha "$NATIVE_SHA" --window-hours 24 --output "$TF_ROOT/prepublish-24h.json"` | redacted prior-good production rates plus candidate simulator/dogfood events; timestamps and sample counts recorded |
| `tf.upload_dry_dispatch` | `scripts/dispatch-testflight-candidate.sh --repo "$NATIVE_REPO" --operation upload-and-dry-run --source-sha "$NATIVE_SHA" --lock "$TF_ROOT/04-candidate-lock.json" --allow-rollback false --timeout-minutes 125 --output "$TF_ROOT/05-upload-dry-run.json"` | exactly one workflow run uploads the reserved build, waits for `VALID`, runs dry-run, and cannot attach a group or notify |
| `tf.dry_artifacts` | `gh run download "$(jq -r .runId "$TF_ROOT/05-upload-dry-run.json")" --repo "$NATIVE_REPO" --dir "$TF_ROOT/06-dry-artifacts" && scripts/verify-testflight-publish-artifacts.rb --lock "$TF_ROOT/04-candidate-lock.json" --root "$TF_ROOT/06-dry-artifacts" --require-operation upload-and-dry-run --require-dry-run --forbid-apply --forbid-notify --require-zero-blockers --require-retention-days 90 \|& tee "$TF_ROOT/06-dry-artifacts.log"` | source/build/note checksums match; dry-run has zero blockers; no group/notification mutation exists |
| `tf.preapply_drift` | `scripts/lock-testflight-candidate.sh --lock "$TF_ROOT/04-candidate-lock.json" --mode verify --require-current-main --require-native-run --require-notes --require-build-valid --require-unattached --artifact "$TF_ROOT/07-preapply-drift.json"` | immediately before apply, SHA/run/note/build/app/group still match and build is not externally attached |
| `tf.apply_dispatch` | `scripts/dispatch-testflight-candidate.sh --repo "$NATIVE_REPO" --operation apply --source-sha "$NATIVE_SHA" --lock "$TF_ROOT/04-candidate-lock.json" --prior-run-id "$(jq -r .runId "$TF_ROOT/05-upload-dry-run.json")" --timeout-minutes 30 --output "$TF_ROOT/08-apply-run.json"` | apply workflow downloads/verifies the prior dry-run artifact and lock, reruns drift/ASC checks, attaches only the intended internal group, then requests notification |
| `tf.apply_artifacts` | `gh run download "$(jq -r .runId "$TF_ROOT/08-apply-run.json")" --repo "$NATIVE_REPO" --dir "$TF_ROOT/09-apply-artifacts" && scripts/verify-testflight-publish-artifacts.rb --lock "$TF_ROOT/04-candidate-lock.json" --root "$TF_ROOT/09-apply-artifacts" --require-operation apply --require-prior-run "$(jq -r .runId "$TF_ROOT/05-upload-dry-run.json")" --require-apply --require-notify-request --require-retention-days 90 \|& tee "$TF_ROOT/09-apply-artifacts.log"` | exact prior dry-run adopted; apply/notification request receipts match lock |
| `tf.app` | `scripts/apple-distribution-kit.sh asc get --path /v1/apps --query 'filter[bundleId]=app.spoonjoy' --query limit=2 --json > "$TF_ROOT/10-asc-app.json" && jq -e --arg id "$ASC_APP_ID" '(.result.data \| length) == 1 and .result.data[0].id == $id and .result.data[0].attributes.bundleId == "app.spoonjoy"' "$TF_ROOT/10-asc-app.json"` | exactly app `6787505444`; assertion exits zero |
| `tf.build` | `scripts/apple-distribution-kit.sh asc get --path /v1/builds --query "filter[app]=$ASC_APP_ID" --query 'filter[preReleaseVersion.platform]=IOS' --query 'sort=-uploadedDate' --query 'include=buildBetaDetail,preReleaseVersion' --query limit=100 --json > "$TF_ROOT/11-asc-build.json" && scripts/verify-testflight-asc-state.rb resolve --lock "$TF_ROOT/04-candidate-lock.json" --builds "$TF_ROOT/11-asc-build.json" --expected-marketing-version 1.0 --output "$TF_ROOT/11-asc-ids.json"` | locked build number is newest matching build, `VALID`, marketing version exactly `1.0`; build and beta-detail IDs assigned in `11-asc-ids.json` |
| `tf.beta_detail` | `ASC_BUILD_BETA_DETAIL_ID="$(jq -r .buildBetaDetailId "$TF_ROOT/11-asc-ids.json")"; scripts/apple-distribution-kit.sh asc get --path "/v1/buildBetaDetails/$ASC_BUILD_BETA_DETAIL_ID" --json > "$TF_ROOT/12-asc-beta-detail.json" && jq -e '.result.data.attributes.internalBuildState == "IN_BETA_TESTING" and .result.data.attributes.externalBuildState != "IN_BETA_TESTING"' "$TF_ROOT/12-asc-beta-detail.json"` | internal state active; external beta not active |
| `tf.build_groups` | `ASC_BUILD_ID="$(jq -r .buildId "$TF_ROOT/11-asc-ids.json")"; scripts/apple-distribution-kit.sh asc get --path "/v1/builds/$ASC_BUILD_ID/betaGroups" --query limit=200 --json > "$TF_ROOT/13-asc-build-groups.json" && scripts/verify-testflight-asc-state.rb groups --groups "$TF_ROOT/13-asc-build-groups.json" --expected-id "$ASC_INTERNAL_GROUP_ID" --require-internal --forbid-external` | exactly one attached group; ID matches `Spoonjoy Internal`; it is internal; zero external groups |
| `tf.group_builds` | `ASC_BUILD_ID="$(jq -r .buildId "$TF_ROOT/11-asc-ids.json")"; scripts/apple-distribution-kit.sh asc get --path "/v1/betaGroups/$ASC_INTERNAL_GROUP_ID/builds" --query limit=100 --json > "$TF_ROOT/14-asc-group-builds.json" && jq -e --arg id "$ASC_BUILD_ID" 'any(.result.data[]?; .id == $id)' "$TF_ROOT/14-asc-group-builds.json"` | exact locked build relationship asserted |
| `tf.testers` | `scripts/apple-distribution-kit.sh asc get --path "/v1/betaGroups/$ASC_INTERNAL_GROUP_ID/betaTesters" --query limit=200 --json > "$TF_ROOT/15-asc-testers.json" && jq -e '(.result.meta.paging.total // (.result.data \| length) // 0) > 0' "$TF_ROOT/15-asc-testers.json"` | tester count greater than zero, asserted |
| `tf.notes` | `ASC_BUILD_ID="$(jq -r .buildId "$TF_ROOT/11-asc-ids.json")"; scripts/apple-distribution-kit.sh asc get --path "/v1/builds/$ASC_BUILD_ID/betaBuildLocalizations" --query limit=200 --json > "$TF_ROOT/16-asc-notes.json" && scripts/verify-testflight-notes.rb --lock "$TF_ROOT/04-candidate-lock.json" --asc "$TF_ROOT/16-asc-notes.json"` | English `whatsNew` is byte-identical to locked notes |
| `tf.feedback_asc` | `scripts/apple-distribution-kit.sh asc get --path "/v1/apps/$ASC_APP_ID/betaFeedbackScreenshotSubmissions" --query limit=50 --json > "$TF_ROOT/17-asc-screenshots.json" && scripts/apple-distribution-kit.sh asc get --path "/v1/apps/$ASC_APP_ID/betaFeedbackCrashSubmissions" --query limit=50 --json > "$TF_ROOT/17-asc-crashes.json" && scripts/verify-testflight-feedback-window.rb --lock "$TF_ROOT/04-candidate-lock.json" --publish "$TF_ROOT/09-apply-artifacts" --screenshots "$TF_ROOT/17-asc-screenshots.json" --crashes "$TF_ROOT/17-asc-crashes.json" --output "$TF_ROOT/17-feedback-result.json"` | every post-publish item is correlated by build/version/time; zero new crash/actionable item for locked build |
| `tf.observe` | `scripts/wait-telemetry-observation.mjs --published-at "$(jq -r .publishedAt "$TF_ROOT/09-apply-artifacts/testflight-publish-summary.json")" --minimum-minutes 30 --output "$TF_ROOT/18-elapsed.json"` and then, from exact deployed web main, `pnpm run telemetry:native:release -- --build "$(jq -r .buildNumber "$TF_ROOT/04-candidate-lock.json")" --since "$(jq -r .publishedAt "$TF_ROOT/09-apply-artifacts/testflight-publish-summary.json")" --compare "$TF_ROOT/prepublish-24h.json" --output "$TF_ROOT/18-postpublish.json"` | proof clock is at least 30 post-publish minutes; threshold passes; `NO_SAMPLE` never substitutes for functional dogfood |

Unit 9 splits the protected TestFlight workflow into `upload-and-dry-run` and `apply`. The first operation visibly executes `xcode run --kind altool-upload --platform ios --mode apply`, polls up to 120 times at 30 seconds for the locked build to become `VALID`, executes `testflight publish --mode dry-run`, machine-inspects a zero-blocker artifact, and is structurally unable to attach a group or notify. Only a later `apply` dispatch can mutate TestFlight; it verifies the immutable prior-run artifact and candidate drift immediately before `testflight publish --mode apply`, polls relationships/state up to 20 times at 15 seconds, and requests notification. A failure after upload invokes `TESTFLIGHT_CONTAIN`; it never reuses the immutable build number.

## Feedback And Cleanup Matrix

Set `CLEANUP_ROOT=/tmp/spoonjoy-audit-release-train/cleanup-$(date -u +%Y%m%dT%H%M%SZ)` and create it before inventory. The apply helper holds an exclusive cleanup lock and re-inventories immediately before every removal.

| Key | Exact operation | Required result / artifact |
| --- | --- | --- |
| `feedback.install` | `scripts/testflight-feedback-autopilot.mjs install-launchd` | three launchd agents point at the current canonical checkout |
| `feedback.health` | `curl -fsS http://127.0.0.1:48973/health` and `curl -fsS https://spoonjoy-testflight-feedback.ouro.bot/health` | both healthy and same contract version |
| `feedback.exercise` | `scripts/testflight-feedback-autopilot.mjs smoke`, `ping`, `doctor`, `status`, `deliveries`, and `reconcile --dry-run` | all pass; no missed feedback; no wake on no-feedback |
| `feedback.launchd` | `launchctl print "gui/$(id -u)/com.spoonjoy.testflight-feedback-listener"`, `...-tunnel`, and `...-reconcile` | all loaded/running with current paths |
| `cleanup.inventory` | `scripts/inventory-release-worktrees.sh --repo /Users/arimendelow/Projects/spoonjoy-v2 --repo /Users/arimendelow/Projects/spoonjoy-apple --ownership-handoff worker/tasks/2026-07-16-0856-doing-audit-release-train/evidence-index.md --output "$CLEANUP_ROOT/deletion-allowlist.json"` | every worktree/branch/stash has owner, HEAD, upstream, dirty/untracked/stash/unpushed/reachability/recovery/disposition fingerprint; web rows are `inventory-only` unless handoff grants web cleanup |
| `cleanup.review` | call `multi_agent_v1__spawn_agent` with a fresh harsh cleanup prompt naming `$CLEANUP_ROOT/deletion-allowlist.json`, call `multi_agent_v1__wait_agent`, and persist the verbatim verdict with `tools.apply_patch` to `$CLEANUP_ROOT/reviewer.md` | only `APPROVED`; dirty, active, unpushed, ambiguous, or unauthorized web entries preserved |
| `cleanup.apply` | `scripts/apply-release-worktree-cleanup.sh --allowlist "$CLEANUP_ROOT/deletion-allowlist.json" --review "$CLEANUP_ROOT/reviewer.md" --mode dry-run --output "$CLEANUP_ROOT/dry-run.json"`, then `--mode apply --output "$CLEANUP_ROOT/apply.json"` | exclusive lock; fresh fingerprint must equal reviewed fingerprint for owner/HEAD/dirty/untracked/stashes/unpushed/upstream/reachability; only terminal authorized rows removed; recovery refs resolve after each removal; no reset/clean/stash deletion |
| `cleanup.final` | `scripts/verify-release-closure.sh --web /Users/arimendelow/Projects/spoonjoy-v2 --native /Users/arimendelow/Projects/spoonjoy-apple --evidence-index worker/tasks/2026-07-16-0856-doing-audit-release-train/evidence-index.md --cleanup "$CLEANUP_ROOT/apply.json" --require-current-main --require-clean --require-artifact-redownload --require-task-terminal --require-continuation-scan --output "$CLEANUP_ROOT/final.json"`, then `ouro msg --to slugger --file "$CLEANUP_ROOT/slugger-message.txt"` | exact commands/SHAs/statuses captured; immutable checksums survive cleanup; no ready agent work; Slugger delivery receipt recorded |

## Completion Criteria
- [ ] Every accepted planning criterion is represented by a terminal unit below.
- [ ] All agent-owned web/native units are merged and exact-main checks are green.
- [ ] Exact final web SHA is deployed with complete Unit 18/19 evidence and zero disposable residue.
- [ ] Exact final native SHA has complete Unit 20 evidence with `fullyValidated: true`, zero blockers, zero warnings, and closed visual ledgers.
- [ ] Exact native SHA is published as a new `1.0` internal TestFlight build, processed `VALID`, attached only to internal `Spoonjoy Internal`, absent from external groups/external beta, in `IN_BETA_TESTING`, and has exact build-specific notes.
- [ ] Notification apply success and any independently observed tester receipt are reported distinctly.
- [ ] Feedback automation is healthy and reports zero unhandled actionable feedback after publication.
- [ ] Both repositories and Desk have terminal, truthful cleanup state; Slugger receives the final status.
- [ ] 100% changed/new code coverage, all tests pass, no warnings.

## Work Units

### 🔄 Unit 0: Adopt Approved Plan And Live Ownership
**What**: Converge the release plan, record the canonical audit doing doc, preserve the parallel worker boundary, create the durable evidence index, and tests-first add `scripts/verify-release-ownership-handoff.rb` plus its JSON schemas.
**Output**: Approved planning doc, this doing doc, evidence index, exhaustive upstream crosswalk, canonical doing commit `c4d13881`, Desk commit `77a8c2d`, and matching committed `owner-release.json`/`receiver-ack.json` records.
**Acceptance**: Fresh doing reviewers return `APPROVED`; no duplicate TestFlight owner exists; the crosswalk has zero unmatched rows; the validator proves exact SHAs/PRs/CI/deploy evidence, zero in-flight web work, cleanup owner, pushed releasing/receiver commits, and exclusive web merge/deploy ownership.

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
**Implementation**: Add `e2e/visual/photo-studio-states.spec.ts`, `pnpm run telemetry:native:release`, `scripts/wait-telemetry-observation.mjs`, `scripts/resolve-exact-sha-runs.mjs`, `scripts/dispatch-production-release.mjs`, `scripts/smoke-provider-callbacks.mjs`, `scripts/dogfood-owner-photo-studio.mjs`, the production-cleanup `--output` contract, `scripts/stage-release-evidence.sh`, `scripts/verify-release-evidence.mjs`, `scripts/verify-release-evidence-index.rb`, and exact-SHA evidence-ingest workflows in atomic web/native harness PRs with disjoint files.
**Verification**: Run Web and Native PR Gates independently. For the bootstrap web PR only, persist the pre-dispatch run-ID set and UTC timestamp, dispatch `production-deploy.yml` with the exact merge SHA, poll until exactly one new run with that SHA/timestamp appears, watch that explicit ID, then require the newly merged helper to adopt and verify the same ID. Dispatch both evidence workflows and verify artifact download/checksums/90-day retention.
**Acceptance**: Web has 14 state/viewport captures; native evidence preserves the 21-entry manifest; telemetry query contract is build-scoped/redacted; both immutable artifacts are downloadable.

### ⬜ Unit 7: Native Cover Codec Extraction (N7)
**Characterization first (canonical 12.0)**: Before structural red tests, run and persist a green exact-wire cover baseline for current sync encode/decode, queue persistence, replay, corrupt legacy payload recovery, source-size limits, and actor responsiveness; a failing baseline is repaired without extraction.
**Tests first**: Add structural and exact-wire-parity tests requiring cover payload encode/decode outside `NativeSyncEngine.swift` while the 12.0 baseline remains green.
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
**Implementation**: Split `.github/workflows/testflight.yml` and `scripts/ci-publish-testflight.sh` into mutually exclusive `upload-and-dry-run` and `apply` operations; apply must download and verify the exact prior-run dry artifact and rerun the lock/drift gate. Add `scripts/lock-testflight-candidate.sh`, `scripts/reserve-testflight-build-number.sh`, `scripts/dispatch-testflight-candidate.sh`, `scripts/verify-testflight-publish-artifacts.rb`, `scripts/verify-testflight-asc-state.rb`, `scripts/verify-testflight-feedback-window.rb`, `scripts/verify-testflight-notes.rb`, `scripts/dogfood-installed-testflight.sh`, and `scripts/contain-testflight-build.sh`, each with duplicate/idempotency, redaction, timeout, exact-lock, internal-only/external-absence, device/build binding, and rollback tests; mutation-capable helpers expose dry-run/apply.
**Verification**: Run after Units 5, 7, 8, and 6A so notes cover the final feature set; use the full Native PR Gate and fresh release-copy/automation review.
**Acceptance**: Exact candidate metadata is accepted and stale build-35-era notes are rejected; upload/dry-run is structurally unable to publish or notify; apply rejects drift and anything other than marketing version `1.0` plus the one intended internal group with zero external groups.

### ⬜ Unit 10: Final Web Unit 18 Validation And Production Dogfood
**What**: After the owner-release barrier and zero-pending crosswalk gate, create a clean exact-main validation worktree and run every command in the approved Unit 18 evidence matrix, fresh reviewers, then the executable Unit 19 matrix: assert validated SHA equals current main; resolve/watch exact CI/Storybook/Production Deploy run; download and validate `production-release.json`; run `smoke:live`, `smoke:mcp:oauth`, `smoke:api`, provider/callback canaries, authenticated owner Photo Studio, all seven deployed web state captures, `cleanup:production`, and artifact upload/checksum verification.
**Output**: `/tmp/spoonjoy-audit-release-train/<web-sha>/web/` plus indexed hashes/run URLs/Cloudflare version.
**Acceptance**: Every command exits zero with 100% coverage and zero warnings; reviewer findings are fixed and the matrix reruns; exact SHA/Cloudflare version match; all seven mobile/desktop deployed states pass; zero residue remains. Any new web main/deploy invalidates and restarts Unit 10.

### ⬜ Unit 11: Final Native Unit 20 Validation And Visual Dogfood
**What**: Create a clean exact-main validation worktree and run every command in the approved Unit 20 evidence matrix, including all route/state screenshots and fresh implementation/test/security/visual reviewers; stage/ingest the final native root with `scripts/stage-release-evidence.sh` and redownload/checksum `spoonjoy-native-release-evidence-$NATIVE_SHA`.
**Output**: `/tmp/spoonjoy-audit-release-train/<native-sha>/native/` plus indexed hashes/run URLs/screenshots/ledgers.
**Acceptance**: Aggregate matrix is `fullyValidated: true`; no blocker/warning; the 21-entry Photo Studio manifest and every other route pass; exact-SHA evidence artifact downloads/checksums; all reviewer findings are fixed and the exact SHA rerun. Any native main change invalidates Unit 11.

### ⬜ Unit 12A: Feedback/Telemetry Preflight And Candidate Lock
**What**: Run feedback doctor/status/reconcile/deliveries, ASC screenshot/crash/build queries, 24-hour telemetry baseline, distribution-kit check, exact Native-run verification, candidate-note checksum, and build-number reservation. Write an immutable candidate lock containing native SHA, Native run ID/URL, notes bytes/checksum, build number, app/group IDs, prior-good build, and timestamp.
**Acceptance**: Zero actionable feedback/crashes; thresholds pass; exact SHA still equals main; build number has no duplicate; note bytes are final. Any SHA/note/build-number change deletes the lock and restarts Unit 11/12A.

### ⬜ Unit 12B: Exact-SHA TestFlight Dispatch And Upload
**What**: Dispatch only `operation=upload-and-dry-run`; resolve the unique run, enforce a 125-minute timeout, inspect the downloaded zero-blocker dry artifact, and compare source/note/build fields to the lock. This operation cannot attach a group or notify.
**Acceptance**: One run owns the reserved build. An existing successful same-lock run is adopted; an unknown duplicate invalidates/reserves a higher number before redispatch. Upload becomes `VALID`; dry-run has zero blockers; ASC shows no external attachment; no apply/notification mutation exists.

### ⬜ Unit 12C: Dry-Run, Internal Publish, And Notification Apply
**What**: Rerun the immutable lock/main/note/build/unattached drift gate immediately before a separate `operation=apply` dispatch. The apply workflow downloads and verifies Unit 12B's exact run/artifact before attaching `Spoonjoy Internal` and requesting notification.
**Acceptance**: Marketing version is exactly `1.0`; build is attached only to internal `Spoonjoy Internal`, absent from every external group, apply succeeds, and notification operation is accepted. Any failure runs `TESTFLIGHT_CONTAIN` and remains nonterminal.

### ⬜ Unit 12D: ASC Relationship Verification And Observation Window
**What**: Query and assert app/build/preReleaseVersion/buildBetaDetail/all build groups/intended group builds/testers/betaBuildLocalizations; verify `VALID`, exact `1.0`, nonzero testers, internal `IN_BETA_TESTING`, no external group/state, byte-identical `whatsNew`, and apply receipt. Start the 30-minute clock, run Unit 13 during that interval, then close feedback/telemetry using the elapsed-time proof.
**Acceptance**: All ASC relationships and thresholds pass; notification apply versus independently observed receipt are reported distinctly.

### ⬜ Unit 13: Installed Dogfood And Five Human Dispositions
**What**: When an authorized physical-device path exists, run `scripts/dogfood-installed-testflight.sh --device "$DEVICE_UDID" --bundle-id app.spoonjoy --expected-version 1.0 --expected-build "$BUILD_NUMBER" --artifact-root "$TF_ROOT/installed"`; it must first prove installed bundle/version/build identity, then exercise provider sign-in, HEIC cover, mutation lock, queue replay, Photo Studio, and cleanup. Resolve or exactly classify Clem credential retirement, Apple callback registration, any secret rotation, owner Photo Studio smoke, and installed TestFlight dogfood.
**Acceptance**: No human-only item is hidden. Any functional failure creates a repair PR, invalidates/contains the candidate, reruns Unit 11, publishes a newer build through Units 12A-12C, reinstalls and identity-verifies that newer build, reruns Unit 13, then restarts Unit 12D's observation. Only unavailable human/device access may become `BLOCKED_HUMAN`. The canonical audit task is `done` only if all five close.

### ⬜ Unit 14: Feedback Health, Cleanup, Desk Closure, And Slugger Notification
**What**: Tests-first add `scripts/inventory-release-worktrees.sh`, `scripts/apply-release-worktree-cleanup.sh`, `scripts/verify-release-human-dispositions.rb`, and `scripts/verify-release-closure.sh`; populate structured `human-dispositions.json`; run the exact feedback health commands in `docs/apple-distribution.md`; inventory both repos with immutable fingerprints; enforce cleanup ownership and apply-time fingerprint equality under an exclusive lock; obtain fresh cleanup review; remove only allowlisted authorized terminal worktrees/branches; prohibit destructive reset/clean; verify recovery refs after each deletion; restore canonical clean exact-main checkouts; validate human/task/evidence schemas; verify immutable artifacts remain downloadable after `/tmp` removal; update planning/doing/evidence/Desk state; continuation scan; `ouro msg --to slugger` with shipped/blocker/build details.
**Acceptance**: Feedback path healthy with zero actionable backlog; 30-minute telemetry window complete; no ready agent work remains; dirty/active/ambiguous work is preserved; recovery proofs pass; both canonical repos are clean current main; release task is terminal and canonical/Desk task is `done` or exact `BLOCKED_HUMAN`; Slugger receives exact status.

## Execution Order
1. Unit 1 runs under the coordinated worker until the explicit owner-release barrier. This task starts no web merge/deploy before that handoff.
2. The web half of Unit 6B lands first as the gate-helper bootstrap (using recorded direct GitHub run-ID resolution for its own merge), then Units 2A-2D, 3, 4, and remaining Unit 6B work serialize web merges/deploys under this task's sole ownership.
3. After native #52, serialize shared cover ownership as Unit 5 (N3) -> Unit 7 (N7) -> Unit 8 (N8) -> Unit 6A (N5) -> Unit 9 (N10). No parallel writes touch sync/queue/cover orchestration.
4. Unit 10 waits for zero pending web crosswalk rows; Unit 11 waits for zero pending native rows and final web production contracts.
5. Units 12A-12C publish only the locked Unit 11 SHA in separate dry/apply operations. Unit 12D starts observation; Unit 13 runs inside it. Any drift or dogfood defect re-enters repair, reinstall, and validation.
6. Unit 12D closes only after the elapsed clock and Unit 13 result; Unit 14 then closes human status, telemetry, immutable evidence, authorized cleanup, Desk, and Slugger.

## Progress Log
- 2026-07-16 09:34 Converted from approved planning doc; current merge/deploy work remains owned by the coordinated audit worker and this task retains exclusive TestFlight publication ownership.
- 2026-07-16 09:52 Addressed doing-review findings: durable ownership commits, exhaustive upstream crosswalk, exclusive merge barrier, split callback/TestFlight units, serialized native shared ownership, executable PR/rollback/telemetry/evidence contracts, candidate invalidation, installed-failure re-entry, and recovery-safe cleanup.
- 2026-07-16 10:24 Addressed fresh hostile findings: split upload/dry-run from publish/notify, asserted internal-only `1.0` ASC state, added elapsed telemetry and installed-build identity gates, made evidence transfer executable, added signed ownership/human schemas, represented accepted ancestry and canonical Unit 0/12.0, and made cleanup ownership/fingerprint checks fail closed.
