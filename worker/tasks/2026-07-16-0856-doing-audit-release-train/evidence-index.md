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
| Planning | `dd5f86a1` | Fresh convergence review | `APPROVED` | 0 | n/a | planning doc | pending | Popper | no rollback needed |
| Ownership | `c4d13881` / `77a8c2d` | Canonical doing + Desk handoff | `RECORDED` | 0 | n/a | canonical doing / Desk task | pending | pending doing review | coordinated worker retains current train only |

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
| Merged PR/run inventory | pending handoff |
| Residual agent-owned work | pending handoff |
| Zero in-flight web merges | pending (`true` required) |
| Zero in-flight web deploys | pending (`true` required) |
| Web cleanup owner | pending |
| Releasing thread / commit | pending |
| Ownership released at | pending |
| Receiver acknowledgement commit | pending |

Ownership changes only when `owner-release.json` and `receiver-ack.json` repeat identical final SHAs, run inventories, zero-in-flight booleans, residual work, and cleanup owner, and each names its pushed commit. `scripts/verify-release-ownership-handoff.rb --release owner-release.json --ack receiver-ack.json` must exit zero before Unit 1 closes.

## Human-Only Dispositions

Allowed terminal values are `COMPLETE` and `BLOCKED_HUMAN`; `pending` is nonterminal. A `BLOCKED_HUMAN` row is valid only when owner, prerequisite, UTC attempt time, attempted path, exact remaining action, required evidence, and closure effect are all nonempty and the attempted-path artifact checksum resolves. The table mirrors structured `human-dispositions.json`; `scripts/verify-release-human-dispositions.rb --dispositions human-dispositions.json --index <this-file>` enforces equality and schema before closure.

| Action | Owner | Prerequisite | Attempted path | Exact remaining action | Required evidence | Closure effect | Resulting status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Clem credential retirement | Clem | linked non-password provider and fresh recovery verified | pending | Clem verifies fresh provider login/recovery and authorizes password removal | linked provider, successful fresh login/recovery, password absent | canonical task remains nonterminal if unavailable | pending |
| Clean Apple callback registration | authorized Apple browser session / Ari only if session unavailable | dual callback support live | existing authorized browser session first | add clean callback without removing legacy; canary both | redacted portal state and both canaries | Units 2B-2D remain `BLOCKED_HUMAN`; starts legacy | pending |
| Confirmed live-secret rotation | authorized secret-store session | private scan proves a tracked value live | private redacted scan | rotate specific secret before deleting evidence | new works, old revoked, redacted incident record | affected release path blocked only | pending |
| Authenticated production owner smoke | existing signed-in browser session / Ari only if unavailable | exact final web SHA live | existing browser/computer-control session first | complete owner Photo Studio flow and clean data | screenshots/network summary/zero residue | owner-smoke row `BLOCKED_HUMAN` only | pending |
| Installed TestFlight dogfood | authorized physical device / Ari only if unavailable | locked build `IN_BETA_TESTING` | available device-control path first; UTC attempt pending | install exact build and run provider/HEIC/mutation/queue/Photo Studio checks | device UDID hash, installed `1.0`/build identity, screenshots, result, cleanup checksum | installed row `BLOCKED_HUMAN`; functional failures are never human blockers | pending |

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
