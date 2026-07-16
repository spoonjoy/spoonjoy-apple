# Spoonjoy Native Full Moon Autopilot State

## Exit Condition

This run is complete only when:

- Stale Spoonjoy Apple worktrees are retired and `/Users/arimendelow/Projects/spoonjoy-apple` is the clean canonical `main` checkout.
- The full-moon implementation branch is merged to `main`, pushed, and no stale branch/worktree from this run remains.
- Native validation passes: Swift tests, scenario verifier, app bundle, coverage, design/accessibility contract, screenshot route matrix, iOS simulator smoke, and macOS smoke.
- UI changes have fresh iOS and macOS screenshot evidence with valid `design-review.json` or valid `design-review-blocked.json`, app-emitted accessibility proofs, and a closed absurdity ledger.
- Latest TestFlight feedback/screenshots/crashes/telemetry are reconciled before publishing.
- A new internal TestFlight build is uploaded, processed `VALID`, attached to `Spoonjoy Internal`, verified with nonzero tester count, and build beta detail `internalBuildState=IN_BETA_TESTING`.
- TestFlight feedback autopilot transparency is improved or explicitly proven already sufficient.
- A durable continuation scan finds no ready native app work left under this mandate.

## Current Item

- Repo: `/Users/arimendelow/Projects/spoonjoy-apple`
- Canonical checkout: `/Users/arimendelow/Projects/spoonjoy-apple` (detached legacy checkout; must finish clean on `main`)
- Active worktree: `/Users/arimendelow/Projects/spoonjoy-apple-audit-release-train`
- Active branch: `worker/audit-release-train`
- Host: `ouroboros-host` / user: `arimendelow` / cwd: `/Users/arimendelow/Projects/spoonjoy-apple-audit-release-train` / OS: `Darwin` / probed: 2026-07-16
- Planning doc: `worker/tasks/2026-07-16-0856-planning-audit-release-train.md`
- Doing doc: `worker/tasks/2026-07-16-0856-doing-audit-release-train.md`
- Evidence index: `worker/tasks/2026-07-16-0856-doing-audit-release-train/evidence-index.md`
- Current phase: doing-doc reviewer gates and coordinated merge train

## Terminal Evidence

- Stale linked worktrees retired on 2026-07-09.
- Only `/Users/arimendelow/Projects/spoonjoy-apple` and `/Users/arimendelow/Projects/spoonjoy-apple-native-full-moon` remain in `git worktree list`.
- Two named stashes preserve dirty stale-worktree changes:
  - `retire stale worktree codex-native/testflight-nav-paths 2026-07-09`
  - `retire stale worktree codex-native/testflight-cook-mode-checklists 2026-07-09`
- Planning reviewer Round 2 converged after fixes for iOS/macOS baseline, fail-closed design evidence, TestFlight verification, and route matrix scope.
- Unit 0a committed repo/worktree hygiene evidence at `aff517e8`.
- Unit 0b committed TestFlight feedback and telemetry intake at `df4a8d06`: no actionable unhandled feedback, latest valid iOS TestFlight build `1.0 (27)`, app id `6787505444`, group `31d60f58-aef9-4d44-b047-3a1f0dc61b5e`, and launchd listener/tunnel/reconcile services still pointing at retired `/Users/arimendelow/Projects/spoonjoy-apple-cookmode-ui-pass`.
- Unit 0c committed baseline screenshot evidence at `acc450ec`: five routes captured and design-reviewed (`recipes`, `recipe-detail`, `cook-mode`, `cookbooks`, `search`); `kitchen`, `shopping-list`, and `capture` exposed harness failures that did not emit terminal blocker artifacts. `absurdity-ledger.md` now tracks the shell/taste issues and harness gaps.

## Next Action

Reviewer-converge the doing doc, adopt the coordinated worker's exact merged/deployed SHAs, then start the missing W5/W8/W9 and N3/N5/N7/N8/N10 implementation PRs without duplicating current work.

## Continuation Scan

| candidate | classification | evidence | disposition |
| --- | --- | --- | --- |
| Merge open audit remediation PRs | ready | Native PRs #52/#53 and web PRs #260/#264/#266/#268/#270/#271/#272 are open | This release train |
| Repair failed/cancelled checks | ready | Native #52 has cancelled checks; web #266 has failed E2E | This release train |
| Deploy and smoke web/backend | ready | Native auth/media behavior depends on production contracts | This release train |
| Full iOS/macOS visual dogfood | ready | Final merged state has not been captured across every promised route | This release train |
| Publish next internal build | ready after gates | Build 35 predates open native fixes | This release train |
| Retire task worktrees | ready after merges | Active task worktrees intentionally preserve unmerged PR tips | Terminal cleanup |

## Stop Condition

Not stopped. Ready work remains.
