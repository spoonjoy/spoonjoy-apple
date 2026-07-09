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
- Canonical checkout: `/Users/arimendelow/Projects/spoonjoy-apple` on `main` at `2f6c3df`
- Active worktree: `/Users/arimendelow/Projects/spoonjoy-apple-native-full-moon`
- Active branch: `codex-native/native-full-moon`
- Planning doc: `codex-native/tasks/2026-07-09-1243-planning-native-full-moon.md`
- Doing doc: pending creation
- Current phase: planning approved; converting to doing doc

## Terminal Evidence

- Stale linked worktrees retired on 2026-07-09.
- Only `/Users/arimendelow/Projects/spoonjoy-apple` and `/Users/arimendelow/Projects/spoonjoy-apple-native-full-moon` remain in `git worktree list`.
- Two named stashes preserve dirty stale-worktree changes:
  - `retire stale worktree codex-native/testflight-nav-paths 2026-07-09`
  - `retire stale worktree codex-native/testflight-cook-mode-checklists 2026-07-09`
- Planning reviewer Round 2 converged after fixes for iOS/macOS baseline, fail-closed design evidence, TestFlight verification, and route matrix scope.

## Next Action

Create and reviewer-converge `codex-native/tasks/2026-07-09-1243-doing-native-full-moon.md`, then execute Unit 0: validation harness hardening.

## Continuation Scan

| candidate | classification | evidence | disposition |
| --- | --- | --- | --- |
| Create doing doc and begin Unit 0 | ready | Planning doc approved; user delegated control; work-planner/work-doer skills read | Start now |
| Fix screenshot matrix hang | ready | Fresh roadmap attempt hung at `simctl launch`; `scripts/capture-native-screenshot-matrix.sh` lacks per-route timeout handling | Unit 0 |
| Route-by-route taste/product audit | ready | Current screenshots show system blue, heavy dock, loud banners, placeholder labels | Units 1-4 |
| TestFlight feedback transparency | ready | Autopilot status has many `fixed_unconfirmed` records and user reported opacity | Later unit |

## Stop Condition

Not stopped. Ready work remains.
