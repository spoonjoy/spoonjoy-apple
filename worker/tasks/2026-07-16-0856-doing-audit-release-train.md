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
- Raw logs, screenshots, binaries, and reports stay in `/tmp/spoonjoy-audit-release-train/<source-sha>/`; only the durable evidence index is tracked.
- Never print secrets or private user data. Public App Store submission is forbidden.
- Human-only rows are attempted through existing authorized browser/computer-control sessions first, then classified exactly as `BLOCKED_HUMAN` only after all independent work is complete.

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

### ✅ Unit 0: Adopt Approved Plan And Live Ownership
**What**: Converge the release plan, record the canonical audit doing doc, preserve the parallel worker boundary, and create the durable evidence index.
**Output**: Approved planning doc, this doing doc, evidence index, coordination message.
**Acceptance**: Fresh planning reviewer returns `APPROVED`; no duplicate TestFlight owner exists; all current/pending units are explicit.

### 🔄 Unit 1: Adopt Current Merge And Deploy Train
**What**: Let the coordinated worker finish native #52 and web #266/#270/#271/#272, including repairs, rebases, green checks, merges, main CI, and serialized exact-SHA production deploys. Refresh the evidence index after every handoff.
**Output**: Exact web/native merge SHAs, PR/run URLs, deployment versions, smoke/cleanup artifacts.
**Acceptance**: Every current PR is merged or has a concrete blocker; native #52 is green on main; web production is green at the latest merged SHA; no work is duplicated locally.

### ⬜ Unit 2: Clean Apple Callback Registration And Default Switch (3j-3m / W5)
**Tests first**: Add configuration tests proving clean starts require recorded portal registration/canary evidence, legacy rollback remains selectable, and no premature switch is possible.
**Implementation**: Use the existing authorized Apple Developer session to register `https://spoonjoy.app/auth/apple/callback` alongside the legacy path, canary both, switch only new starts behind validated configuration, retain legacy handling, and open an atomic web PR.
**Verification**: Full web matrix, security review, merge/main CI, exact-SHA deploy, clean/legacy Apple canaries, Google/GitHub regression canaries, rollback proof.
**Acceptance**: Clean callback is the default only after registration evidence; both callback paths work. If no existing session can complete registration, preserve exact `BLOCKED_HUMAN` action and leave starts legacy.

### ⬜ Unit 3: Local OAuth Teardown (W8)
**Tests first**: Cover dry-run/apply parity, generated-client dependency cleanup, snapshots/manifests, transactions, retained-owner refusal/checksums, partial failures, reruns, recovery, and exact residue.
**Implementation**: Add local-only dependency-aware teardown for disposable OAuth clients/credentials/codes/tokens and related test data; open an atomic web PR.
**Verification**: Focused/full coverage, script typecheck, two cleanup runs, data-safety review, PR/main CI.
**Acceptance**: Local before/apply/after ends at zero disposable residue without touching retained users; rerun is idempotent.

### ⬜ Unit 4: Web Repository Cleanup And Guard (W9)
**Tests first**: Cover tracked database/generated artifacts, fixture allowlists, durable Markdown preservation, PR-size thresholds, body manifest requirements, and external evidence routing.
**Implementation**: Privately inventory and remove only manifest-approved artifacts/database state, add recovery refs and future guards, and open an atomic web PR.
**Verification**: Redacted scan, full web matrix, hygiene policy, `git count-objects -vH`, recovery test, security/repository review, PR/main CI.
**Acceptance**: Current web tree is clean; no secret or durable evidence is lost; no unauthorized history rewrite occurs.

### ⬜ Unit 5: Native Mutation Single-Flight And Retry Identity (N3)
**Tests first**: Cover the full cover-operation conflict matrix, synchronous double taps, stable IDs across same-payload retry/offline ownership/replay, payload changes, cancel/dismiss, unlock behavior, `idempotency_in_progress`, stage retention, and durable queue ownership.
**Implementation**: Add a testable cover mutation state machine, globally disable conflicts, show operation-specific progress, preserve retry identity, and wire native routes; open an atomic native PR after #52 lands.
**Verification**: Focused route/cover/sync tests, 100% core coverage, scenario verifier, iOS/macOS builds, concurrency/idempotency review, PR/main CI.
**Acceptance**: Duplicate plans cannot form; retries preserve identity and staged media until server success or durable queue ownership.

### ⬜ Unit 6: Native Photo Studio Product Truth And Cross-Client Visual Harness (N5 + Unit 7d web harness)
**Tests first**: Cover Spoon gating/nil suppression, optional date, multiline direction, prompts, dynamic outcomes, automatic activation, processing/failure recovery, deterministic screenshot routes, accessibility, and route counts.
**Implementation**: Split draft/presentation from orchestration; implement truthful minimum-click controls/states; add native screenshot routes and a deterministic web Playwright matrix for default, Spoon-off, editorial-off, processing, failure, empty/no-cover, and narrow/dense states; open atomic native and web visual-harness PRs.
**Verification**: Full native/web matrices and direct iPhone/iPad/macOS/web mobile/web desktop screenshots; fresh accessibility and visual reviewers; closed absurdity ledgers.
**Acceptance**: Every state is truthful, stable, non-overlapping, and directly evidenced at exact source/deploy SHAs.

### ⬜ Unit 7: Native Cover Codec Extraction (N7)
**Tests first**: Add structural and exact-wire-parity tests requiring cover payload encode/decode outside `NativeSyncEngine.swift`.
**Implementation**: Extract a narrow cover codec without weakening unrelated visibility; open atomic native PR.
**Verification**: Focused/full native matrix, architecture/API compatibility review, PR/main CI.
**Acceptance**: Exact persisted/wire behavior is unchanged and codec ownership is isolated.

### ⬜ Unit 8: Native Cover Queue Transport Extraction (N8)
**Tests first**: Require cover queue factories/replay transport outside the main sync engine while preserving retry, staged media, and persisted-kind behavior.
**Implementation**: Extract queue factories and replay transport behind narrow internal interfaces; open atomic native PR after N7.
**Verification**: Focused/full native matrix, offline replay scenarios, architecture/concurrency review, PR/main CI.
**Acceptance**: Queue/retry behavior is unchanged and transport ownership is isolated.

### ⬜ Unit 9: Build-Specific TestFlight Notes (N10)
**Tests first**: Tie source SHA, build number, user-facing manifest, and note freshness; require current image, mutation, Photo Studio, and provider-sign-in changes.
**Implementation**: Generate/validate notes from the designated candidate and reject stale/mismatched metadata; open atomic native PR without publishing.
**Verification**: Focused/full native matrix and fresh release-copy/automation review; PR/main CI.
**Acceptance**: Exact candidate metadata is accepted and stale build-35-era notes are rejected.

### ⬜ Unit 10: Final Web Unit 18 Validation And Production Dogfood
**What**: Create a clean exact-main validation worktree and run every command in the approved Unit 18 evidence matrix, fresh reviewers, then the protected exact-SHA production deploy and Unit 19 public/API/MCP/provider/callback/authenticated Photo Studio/responsive/cleanup dogfood.
**Output**: `/tmp/spoonjoy-audit-release-train/<web-sha>/web/` plus indexed hashes/run URLs/Cloudflare version.
**Acceptance**: Every command exits zero with 100% coverage and zero warnings; reviewer findings are fixed and rerun; exact SHA is live; zero residue remains.

### ⬜ Unit 11: Final Native Unit 20 Validation And Visual Dogfood
**What**: Create a clean exact-main validation worktree and run every command in the approved Unit 20 evidence matrix, including all route/state screenshots and fresh implementation/test/security/visual reviewers.
**Output**: `/tmp/spoonjoy-audit-release-train/<native-sha>/native/` plus indexed hashes/run URLs/screenshots/ledgers.
**Acceptance**: Aggregate matrix is `fullyValidated: true`; no blocker/warning; every iPhone/iPad/macOS state passes; all reviewer findings are fixed and the exact SHA rerun.

### ⬜ Unit 12: TestFlight Feedback Preflight And Exact-SHA Publish
**What**: Reconcile comments/screenshots/crashes/build metadata/native telemetry/backend logs first; run distribution-kit preflight; dispatch protected TestFlight for Unit 11's exact SHA; wait through upload/processing; publish internal-only; verify notes/build/group/testers/status/notification apply via ASC API.
**Output**: App/build/group IDs, build version/number, exact SHA, notes checksum, publish/apply artifact, ASC relationship evidence.
**Acceptance**: Zero unhandled actionable feedback; new build is `VALID`, attached to `Spoonjoy Internal`, has nonzero testers, `IN_BETA_TESTING`, and exact `whatsNew`; notification intent/apply and observed receipt are reported separately.

### ⬜ Unit 13: Installed Dogfood And Five Human Dispositions
**What**: Exercise installed provider sign-in, HEIC cover, mutation lock, queue replay, Photo Studio, and cleanup when an authorized physical-device path exists. Resolve or exactly classify Clem credential retirement, Apple callback registration, any secret rotation, owner Photo Studio smoke, and installed TestFlight dogfood.
**Acceptance**: No human-only item is hidden. The canonical audit task is `done` only if all five close; otherwise `BLOCKED_HUMAN` records owner/prerequisite/action/evidence/effect after all independent work ships.

### ⬜ Unit 14: Feedback Health, Cleanup, Desk Closure, And Slugger Notification
**What**: Run feedback doctor/status/reconcile plus listener/tunnel/launchd health; inventory both repos; remove only terminal clean worktrees/merged branches; restore canonical clean exact-main checkouts; update planning/doing/evidence/Desk state; continuation scan; notify Slugger.
**Acceptance**: Feedback path healthy with zero actionable backlog; no ready agent work remains; dirty/active/ambiguous work is preserved and classified; both canonical repos are clean current main; Slugger receives exact shipped/blocker status.

## Execution Order
1. Unit 1 continues externally while Units 2-4 are prepared from stable web main.
2. Units 5-9 begin after native #52 merges; N7 then N8 are sequential, while N3/N5/N10 may use disjoint worktrees.
3. Unit 10 waits for all web PRs; Unit 11 waits for all native PRs and final web production contracts.
4. Unit 12 publishes only Unit 11's selected exact native SHA.
5. Units 13-14 close installed/human status, automation health, cleanup, Desk, and Slugger.

## Progress Log
- 2026-07-16 09:34 Converted from approved planning doc; current merge/deploy work remains owned by the coordinated audit worker and this task retains exclusive TestFlight publication ownership.
