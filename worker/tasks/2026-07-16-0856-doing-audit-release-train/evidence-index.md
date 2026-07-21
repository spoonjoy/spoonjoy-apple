# Audit Release Train Evidence Index

## Candidate Handoff

| Field | Value |
| --- | --- |
| `web_sha` | pending |
| `cloudflare_version` | pending |
| `native_sha` | pending |
| `native_run_url` | pending |
| `build_version` | pending |
| `build_number` | pending |
| `asc_app_id` | `6787505444` |
| `asc_build_id` | pending |
| `asc_group_id` | `31d60f58-aef9-4d44-b047-3a1f0dc61b5e` |
| `notes_checksum` | pending |
| `notify_apply_result` | pending |
| `installed_dogfood_status` | pending |
| `residual_blockers` | pending |

## Evidence Rows

| Unit | Source SHA | Command / operation | Result | Warning count | CI / run URL | External artifact | SHA-256 | Reviewer | Cleanup / rollback |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Planning | `542f6a6f` | Fresh convergence review including final command corrections | `APPROVED` | 0 | n/a | planning doc | pending | Popper plus final doing reviewers | no rollback needed |
| Ownership | `c4d13881` / `77a8c2d` | Canonical doing + Desk handoff | `RECORDED` | 0 | n/a | canonical doing / Desk task | pending | pending doing review | coordinated worker retains current train only |
| Doing gate | `542f6a6f` | Independent hostile release/execution convergence | `APPROVED` | 0 | n/a | doing doc / evidence index / crosswalk | pending | Descartes, Poincare | findings fixed through fresh review |
| Unit 2A | `1bea760ba0c8f10b997f0ca5352880050c30c683` | Apple Services ID Save/fresh readback; 10 GET + 10 POST probes on each clean/legacy callback | `COMPLETE` (40/40 controlled `302`; no 404/5xx) | 0 | live Worker `c7a2517a-6076-4dcd-bee9-6c9e76ecfeb8` | `/tmp/spoonjoy-audit-release-train/apple-callback-registration-2026-07-16/` | `e990e5d00a0dac9969e9fcc8930c04a25c82c6506c996b6add38c8b17e8b4c7b` | fresh portal readback plus machine canary assertion | clean and all six legacy return URLs retained; legacy start remains rollback path |
| Unit 1 / feedback tunnel | `0309768c31a37ca1c2627e0efefc86aa721f62b0` | Merge PR #56; exact-main Native gate; install launchd; local/public health; Apple ping/delivery; feedback reconcile; generic Ouro-to-Slugger event | `COMPLETE` (HTTP/2 tunnel live; Apple `202`; actionable/unhandled 0; Slugger iMessage sent) | 0 | [Native run 29528190225](https://github.com/spoonjoy/spoonjoy-apple/actions/runs/29528190225) | `/tmp/spoonjoy-audit-release-train/feedback-tunnel-http2/` plus live launchd/Ouro receipts | `78402f7b9fd8ef42c67ff2db1ee6d284f7faff57c1cc335e6ed4c3fd2051c8f2` (installed script digest) | hostile reviewer `CONVERGED` before merge | PR #54 rebased onto exact main; TestFlight mutation still prohibited pending owner release |

Raw validation output belongs under `/tmp/spoonjoy-audit-release-train/<source-sha>/` and must not be committed.

## Owner-Release Handoff

| Field | Value |
| --- | --- |
| Coordinated worker scope | current web PR merge/deploy train plus native #52 |
| Exclusive release owner | source thread `019f2e25-2fc3-75b2-8ba3-335f3777115a` |
| Canonical doing commit | `c4d13881` |
| Desk commit | `77a8c2d` |
| Final web SHA / deploy | pending handoff |
| Final native SHA / Native run | pending handoff |
| Native tunnel prerequisite | PR #56 / `0309768c31a37ca1c2627e0efefc86aa721f62b0` / Native run `29528190225` / live HTTP/2 health and Slugger iMessage proof complete |
| Merged PR/run inventory | pending handoff |
| Residual agent-owned work | pending handoff |
| Zero in-flight web merges | pending (`true` required) |
| Zero in-flight web deploys | pending (`true` required) |
| Web cleanup owner | pending |
| Releasing thread / commit | pending |
| Ownership released at | pending |
| Canonical outbound release | `worker/tasks/2026-07-16-0856-doing-audit-release-train/outbound-owner-release.json` |
| Outbound release schema | `worker/tasks/2026-07-16-0856-doing-audit-release-train/outbound-owner-release.schema.json` |
| Receiver acknowledgment schema | `worker/tasks/2026-07-16-0856-doing-audit-release-train/receiver-ack.schema.json` |
| Protected `ReceiverAcknowledged` ledger commit / payload SHA-256 | pending |
| Delivery projection commit / path | pending external verifier evidence |
| Upstream acknowledgment copy commit / path | pending external verifier evidence |

Ownership changes only when canonical `outbound-owner-release.json`, the protected `ReceiverAcknowledged` ledger event, and acyclic `receiver-ack.json` agree on the outbound commit/path/SHA-256, receiver identities, and every protected outbound field. The acknowledgment never names a commit that contains itself. Its delivery and upstream copies must be byte-identical commits reachable from each repository's protected `refs/heads/main`. Run `scripts/verify-release-ownership-handoff.rb --release worker/tasks/2026-07-16-0856-doing-audit-release-train/outbound-owner-release.json --ack worker/tasks/2026-07-16-0856-doing-audit-release-train/receiver-ack.json --delivery-ack-commit "$DELIVERY_ACK_COMMIT" --delivery-ack-path "$DELIVERY_ACK_PATH" --upstream-ack-commit "$UPSTREAM_ACK_COMMIT" --upstream-ack-path worker/tasks/2026-07-16-0856-doing-audit-release-train/receiver-ack.json --output "$CLEANUP_ROOT/ownership.json"`; it must independently prove exact-ref ancestry/stability, effective GitHub protection or mutability-blocking rules, and exact acknowledgment bytes in both remote commit trees before Unit 0 or cleanup closes.

## Human-Only Dispositions

Allowed terminal values are `COMPLETE` and `BLOCKED_HUMAN`; `pending` is nonterminal. Both terminal values require owner, prerequisite/condition, UTC attempt time, attempted path, attempted-artifact SHA-256, exact remaining action (`none` for complete), required evidence, and closure effect. A `BLOCKED_HUMAN` checksum must prove the attempted authorized path and unavailable prerequisite; a `COMPLETE` checksum must prove the completed outcome. The table mirrors `worker/tasks/2026-07-16-0856-doing-audit-release-train/human-dispositions.json`; `scripts/verify-release-human-dispositions.rb --dispositions worker/tasks/2026-07-16-0856-doing-audit-release-train/human-dispositions.json --index worker/tasks/2026-07-16-0856-doing-audit-release-train/evidence-index.md --output "$CLEANUP_ROOT/human-dispositions-proof.json"` enforces equality/schema and persists deterministic proof before closure.

| Action | Owner | Prerequisite / condition | Attempted at UTC | Attempted path | Attempt artifact SHA-256 | Exact remaining action | Required evidence | Closure effect | Resulting status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Clem credential retirement | Clem | linked non-password provider and fresh recovery verified | pending | pending | pending | Clem verifies fresh provider login/recovery and authorizes password removal | linked provider, successful fresh login/recovery, password absent | canonical task remains nonterminal if unavailable | pending |
| Clean Apple callback registration | authorized Apple browser session | dual callback support live | 2026-07-16T17:49:24Z | existing authorized Apple Developer session; Save, reopen, fresh readback, live clean/legacy canaries | `e990e5d00a0dac9969e9fcc8930c04a25c82c6506c996b6add38c8b17e8b4c7b` | none | redacted portal state proves clean plus all six legacy return URLs; 40/40 clean/legacy GET/POST canaries controlled `302` on Worker `c7a2517a-6076-4dcd-bee9-6c9e76ecfeb8` | Units 2B-2D unblocked; legacy rollback retained | `COMPLETE` |
| Confirmed live-secret rotation | authorized secret-store session | private scan result: live tracked secret requires rotation; no live tracked secret closes `COMPLETE` as `not_required` | pending | private redacted scan | pending | rotate/revoke the named secret, or `none` when scan proves `not_required` | rotation: new works/old revoked/redacted incident; no-rotation: private scan checksum proving no live tracked value | only affected release path blocks when rotation is required | pending |
| Authenticated production owner smoke | existing signed-in browser session / Ari only if unavailable | exact final web SHA live | pending | existing browser/computer-control session first | pending | complete owner Photo Studio flow and clean data | screenshots/network summary/zero residue | owner-smoke row `BLOCKED_HUMAN` only | pending |
| Installed TestFlight dogfood | authorized physical device / Ari only if unavailable | locked build `IN_BETA_TESTING` | pending | available device-control path first | pending | install exact build and run provider/HEIC/mutation/queue/Photo Studio checks | device UDID hash, installed `1.0`/build identity, screenshots, result, cleanup checksum | installed row `BLOCKED_HUMAN`; functional failures are never human blockers | pending |

## Task Terminal States

| Record | Required terminal state | Current |
| --- | --- | --- |
| Release doing task | `done` after every agent-owned unit, TestFlight verification, telemetry, immutable evidence, and cleanup | `reviewing` |
| Canonical audit doing task | `done` only if all five human rows close; otherwise exact `BLOCKED_HUMAN` after all independent work | `processing` |
| Desk `spoonjoy/audit-remediation` | mirrors canonical task and includes build/SHAs/blockers | `processing` |

## Telemetry Windows

| Window | UTC start/end | Web SHA | App version/build | Queries/events | Baseline | Threshold | Result | Artifact/checksum |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Pre-publish 24h | pending | pending | prior-good build plus candidate SHA/build simulator events | pending | n/a | zero new crash/actionable feedback; record API/native rates and sample counts | pending | `prepublish-24h.json` / pending |
| Post-publish 30m minimum | pending; start must equal apply receipt `publishedAt`; elapsed proof required | pending | exact locked build | pending | pending | zero correlated release-smoke failures; API 5xx <= `max(1%,2x baseline)` at n>=20 | pending | `18-elapsed.json`, `18-postpublish.json` / pending |

## Immutable Artifacts

| Name | Source SHA | Run URL | Artifact URL | Retention | SHA256SUMS verified | Downloaded after local cleanup |
| --- | --- | --- | --- | --- | --- | --- |
| `spoonjoy-web-release-evidence-<sha>` | pending | pending | pending | 90 days | pending | pending |
| `spoonjoy-native-release-evidence-<sha>` | pending | pending | pending | 90 days | pending | pending |
| `testflight-release-candidate-note-<sha>-<run>` | pending | pending | pending | 90 days | pending | pending |
| `testflight-publish-artifacts-<sha>` | pending | pending | pending | 90 days | pending | pending |

`scripts/verify-release-evidence-index.rb` rejects placeholders, missing URLs, wrong SHAs, wrong retention, checksum failures, undeleted draft staging releases, and artifacts that cannot be redownloaded after local cleanup.

## Cleanup Deletion Allowlist

| Owner | Authorized cleanup owner | Path | Branch | HEAD | Upstream | Dirty | Untracked | Stashes | Unpushed | Recovery ref | Reachable | Fingerprint / inventoried UTC | Disposition | Apply revalidated | Review |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| pending | pending | pending | pending | pending | pending | pending | pending | pending | pending | pending | pending | pending | preserve/remove | pending | pending |
