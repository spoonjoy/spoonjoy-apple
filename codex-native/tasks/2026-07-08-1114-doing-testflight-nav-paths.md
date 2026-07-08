# Doing: TestFlight Navigation Paths

**Status**: READY_FOR_EXECUTION
**Execution Mode**: direct
**Created**: 2026-07-08 11:14
**Planning**: ./2026-07-08-1114-planning-testflight-nav-paths.md
**Artifacts**: ./2026-07-08-1114-doing-testflight-nav-paths/

## Execution Mode

- **pending**: Awaiting user approval before each unit starts only when the user explicitly requested interactive per-unit approval; otherwise convert this to `spawn` or `direct` unless a hard exception is present
- **spawn**: Spawn sub-agent for each unit (parallel/autonomous)
- **direct**: Execute units sequentially in current session (default)

## Objective
Fix the TestFlight-reported compact iPhone navigation failure where users can reach Shopping List without an obvious way back to the app home/Kitchen route. Validate that the compact SpoonDock route matrix exposes reliable in-app navigation paths and that the shopping screenshot state no longer strands the user.

## Upstream Work Items
- TestFlight feedback `APHfmldUfhrmP2su-glLyMs`

## Completion Criteria
- [ ] Feedback artifacts are inspected and summarized without exposing secrets or signed URLs.
- [ ] Compact mobile route tests fail before implementation and pass after the fix.
- [ ] Shopping List compact dock exposes a direct Kitchen/Home route.
- [ ] Other compact dock contexts do not strand users away from Kitchen/Home.
- [ ] 100% test coverage on all new code
- [ ] All tests pass
- [ ] No warnings
- [ ] If UI/rendering/layout changed: `visual-qa-dogfood` evidence captured, absurdity ledger closed, and automated visual metrics still pass

## Code Coverage Requirements
**MANDATORY: 100% coverage on all new code.**
- No `[ExcludeFromCodeCoverage]` or equivalent on new code
- All branches covered (if/else, switch, try/catch)
- All error paths tested
- Edge cases: null, empty, boundary values

## TDD Requirements
**Strict TDD — no exceptions:**
1. **Tests first**: Write failing tests BEFORE any implementation
2. **Verify failure**: Run tests, confirm they FAIL (red)
3. **Minimal implementation**: Write just enough code to pass
4. **Verify pass**: Run tests, confirm they PASS (green)
5. **Refactor**: Clean up, keep tests green
6. **No skipping**: Never write implementation without failing test first

## Work Units

### Legend
⬜ Not started · 🔄 In progress · ✅ Done · ❌ Blocked

**CRITICAL: Every unit header MUST start with status emoji (⬜ for new units).**

### ✅ Unit 0: Setup/Research
**What**: Inspect TestFlight detail JSON, screenshot, app instructions, navigation shell, and native design guidance.
**Output**: Planning context and a concrete repro/fix hypothesis.
**Acceptance**: Event/device/build context and missing route affordance are identified without leaking signed URLs or secrets.

### ✅ Unit 1a: Compact Route Matrix — Tests
**What**: Add failing source-contract tests proving compact SpoonDock contexts expose a Kitchen/Home escape and Shopping List wires it.
**Acceptance**: Focused tests fail red before implementation.

### ✅ Unit 1b: Compact Route Matrix — Implementation
**What**: Update `SpoonDockContext` and route wiring so Shopping List and related compact contexts expose Kitchen/Home without losing primary actions.
**Acceptance**: Focused tests pass green and the app builds without warnings.

### ✅ Unit 1c: Compact Route Matrix — Coverage & Refactor
**What**: Run focused Swift tests, relevant scenario verifier checks, and inspect the diff for stale route-matrix gaps.
**Acceptance**: New route contract coverage is complete and no unreachable compact route remains in the tested matrix.

### ✅ Unit 1d: Shopping Route — Visual QA Dogfood
**What**: Capture the fixed shopping route on iPhone-size simulator, inspect screenshots, and maintain an absurdity ledger.
**Acceptance**: Final screenshot shows a direct Kitchen/Home affordance, no overlap/clipping, and the visual ledger has no ready or reviewer-gated items.

### ✅ Unit 2: Internal TestFlight
**What**: After local validation, build/upload/publish an internal TestFlight build if credentials and signing allow it.
**Acceptance**: Build is attached to Spoonjoy Internal, or a compact blocker report lists the unavoidable human-only actions.

## Execution
- **TDD strictly enforced**: tests → red → implement → green → refactor
- Commit after each phase (1a, 1b, 1c)
- Push after each unit complete
- Run full test suite before marking unit done
- For UI/rendering/layout units, run `visual-qa-dogfood` before declaring the unit or task complete

## Progress Log
- 2026-07-08 11:14 Created from approved planning doc.
- 2026-07-08 12:32 Unit 0 complete: inspected TestFlight detail JSON, screenshot, native shell source, route state, and SpoonDock route contexts.
- 2026-07-08 12:32 Unit 1a complete: added failing compact route-matrix tests and captured red evidence in `unit-1a-red.log`.
- 2026-07-08 13:14 Codex took over the stale feedback worker and folded the route fix into `codex-native/web-recipe-parity` so the next TestFlight build includes both recipe web-parity and compact navigation fixes.
- 2026-07-08 13:14 Units 1b-1d complete: Recipes, Shopping List, Search, and Profile compact dock routes now expose Kitchen/Home; focused Swift tests and iOS Shopping List screenshot proof passed. Visual proof: `build/visual-qa/combined-nav-shopping/screenshots/ios-mobile.png`; accessibility proof includes `Kitchen`.
- 2026-07-08 13:22 Unit 2 complete: uploaded and published iOS build `1.0 (22)` to internal TestFlight group `Spoonjoy Internal`; App Store Connect verifies build `7cb1552c-570f-484e-986f-b2654c8b09cd` is attached and `IN_BETA_TESTING`.
