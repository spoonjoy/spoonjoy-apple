# Doing: Native Mobile UI Overhaul And SpoonDock

**Status**: READY_FOR_EXECUTION
**Execution Mode**: direct
**Created**: 2026-07-07 21:15
**Planning**: ./2026-07-07-2109-planning-native-mobile-ui-overhaul.md
**Artifacts**: ./2026-07-07-2109-doing-native-mobile-ui-overhaul/

## Execution Mode

- **pending**: Awaiting user approval before each unit starts only when the user explicitly requested interactive per-unit approval; otherwise convert this to `spawn` or `direct` unless a hard exception is present
- **spawn**: Spawn sub-agent for each unit (parallel/autonomous)
- **direct**: Execute units sequentially in current session (default)

## Objective
Make the native iOS Spoonjoy app look and behave like a first-class mobile Spoonjoy product instead of a broken SwiftUI shell. Restore the missing SpoonDock concept as a native Liquid Glass-inspired control layer while fixing the concrete clipping, overlap, hierarchy, and mobile layout failures shown in recent TestFlight screenshots.

## Upstream Work Items
- TestFlight feedback `AL3GtjesS-4gK4LAwMY7WJI`
- Desk task `spoonjoy/mobile-first-design-recalibration`

## Completion Criteria
- [ ] Recent TestFlight feedback and screenshots are represented in an audit artifact with explicit failure dispositions.
- [ ] Compact iOS uses a native SpoonDock with the context matrix from `2026-07-07-2109-native-mobile-ui-overhaul-visual-audit.md` instead of relying on a generic top toolbar or five-equal-tab dock.
- [ ] Kitchen and recipe detail screenshots on iPhone show no clipped controls, overlapping title/hero text, nested list cutoffs, or horizontally overflowing action rows.
- [ ] Cook mode and shopping list keep kitchen-safe primary controls reachable and readable on iPhone.
- [ ] Source-contract checks cover SpoonDock, compact iOS navigation, and no-overflow mobile action composition.
- [ ] `visual-qa-dogfood` evidence captured, absurdity ledger closed, and automated visual metrics still pass.
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
**What**: Confirm current visual evidence, create the audit artifact, read native design/SpoonDock sources, verify SwiftUI Liquid Glass API availability, and identify exact files/tests to touch.
**Output**: Planning doc, visual audit artifact, and this doing doc.
**Acceptance**: Audit contains failures F1-F6, SpoonDock matrix, and source references; reviewer convergence recorded in planning progress log.

### ✅ Unit 1a: Compact Shell And SpoonDock — Tests
**What**: Add failing source-contract coverage for compact iOS `NavigationStack`, `SpoonDock`, `SpoonDockContext`, three-zone route matrix, glass/material control layer, and removal of generic compact toolbar dependency.
**Acceptance**: Focused test or script fails red because `SpoonDock` and compact shell tokens do not exist yet.

### ✅ Unit 1b: Compact Shell And SpoonDock — Implementation
**What**: Add `SpoonDock` SwiftUI component and compact iOS branch in `PlatformNavigationView` using `NavigationStack`, bottom `safeAreaInset`, route-aware left/center/right actions, and Liquid Glass/material-backed controls. Preserve desktop-class `NavigationSplitView`.
**Acceptance**: Unit 1a tests pass green; app target compiles without warnings.

### ✅ Unit 1c: Compact Shell And SpoonDock — Coverage & Refactor
**What**: Tighten route context helpers, accessibility labels, fallback behavior for non-iOS/macOS, and source-contract coverage so new code has 100% coverage or direct source-contract proof where SwiftUI rendering is not unit-testable.
**Acceptance**: Focused tests pass; no uncovered helper branches remain untested or uncontracted.

### ✅ Unit 2a: Kitchen And Recipe Detail Mobile Composition — Tests
**What**: Add failing source-contract checks for `MobileActionFlow`, recipe detail overflow prevention, mobile kitchen index rows without nested `List`, stable cover aspect ratios, and route-local overflow/menu fallback.
**Acceptance**: Focused tests or scripts fail red on current `HStack` overflow and `List`-inside-`ScrollView` implementation.

### ✅ Unit 2b: Kitchen And Recipe Detail Mobile Composition — Implementation
**What**: Replace broken mobile recipe detail action row with priority/wrapping composition; make kitchen recipe index and cookbook shelf mobile-first object layouts; improve theme spacing/type helpers without decorative cards.
**Acceptance**: Unit 2a tests pass green; iPhone compact build renders without the known F1-F4 structural failures.

### ✅ Unit 2c: Kitchen And Recipe Detail Mobile Composition — Coverage & Refactor
**What**: Refactor duplicated mobile layout helpers, cover edge cases for empty/long titles/accessibility text, and ensure source-contract scripts encode no nested mobile list/card regressions.
**Acceptance**: Focused tests and scripts pass; no warnings.

### ⬜ Unit 3a: Cook Mode And Shopping SpoonDock Integration — Tests
**What**: Add failing checks that cook mode uses SpoonDock as step handrail and shopping list exposes Add/Search/Clear checked through dock-compatible actions without crowding header controls.
**Acceptance**: Focused tests fail red against current bottom button stack and crowded shopping header.

### ⬜ Unit 3b: Cook Mode And Shopping SpoonDock Integration — Implementation
**What**: Route cook mode previous/status/next through SpoonDock-style controls and move shopping primary/secondary actions into mobile-friendly bottom/context actions while preserving native edit behavior.
**Acceptance**: Unit 3a tests pass green; controls remain reachable and readable at compact width.

### ⬜ Unit 3c: Cook Mode And Shopping SpoonDock Integration — Coverage & Refactor
**What**: Verify helper branches, accessibility labels, destructive action confirmations, and Dynamic Type fallbacks.
**Acceptance**: Focused tests pass; no warnings.

### ⬜ Unit 4d: Visual QA Dogfood
**What**: Run `visual-qa-dogfood` for iOS kitchen and recipe detail, capture screenshots with the project harness, inspect images, update the visual audit ledger from `ready` to `fixed` or explicitly scoped disposition, and rerun automated visual validators.
**Acceptance**: Fresh screenshots show no clipped controls, overlap, nested list cutoffs, or missing SpoonDock; visual audit ledger has no `ready` or `needs reviewer gate` items; screenshot/design review validators pass or produce a concrete blocker that is fixed.

### ⬜ Unit 5: Final Validation, Merge, And TestFlight Release
**What**: Run full local validation, push branch, open PR, wait for required checks, merge, sync canonical checkout, build/upload/publish an internal TestFlight build if the overhaul is release-ready, verify group attachment, and update feedback status.
**Acceptance**: Swift tests, native scenario verifier, app bundle, coverage, screenshot evidence, PR checks, and ASC/TestFlight verification all pass; no public App Store submission.

## Execution
- **TDD strictly enforced**: tests → red → implement → green → refactor
- Commit after each phase (1a, 1b, 1c)
- Push after each unit complete
- Run full test suite before marking unit done
- For UI/rendering/layout units, run `visual-qa-dogfood` before declaring the unit or task complete
- **All artifacts**: Save outputs, logs, data to `./2026-07-07-2109-doing-native-mobile-ui-overhaul/` directory
- **Fixes/blockers**: Spawn sub-agent immediately — don't ask, just do it
- **Decisions made**: Update docs immediately, commit right away

## Progress Log
- 2026-07-07 21:15 Created from planning doc
- 2026-07-07 21:18 Unit 1a red verified with `swift test --filter NativeMobileDesignContractTests`; failure confirms missing `SpoonDock`, missing compact mobile shell, and generic toolbar route buttons.
- 2026-07-07 21:25 Unit 1b green verified with `swift test --filter NativeMobileDesignContractTests` and `xcodebuild -project Spoonjoy.xcodeproj -scheme 'Spoonjoy iOS' -configuration BootstrapDebug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES build`.
- 2026-07-07 21:27 Unit 1c green verified project registration contract plus `xcodebuild -project Spoonjoy.xcodeproj -scheme 'Spoonjoy macOS' -configuration BootstrapDebug -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES build`.
- 2026-07-07 21:28 Unit 2a red verified with `swift test --filter NativeMobileDesignContractTests`; failure confirms nested kitchen `List` and overflowing recipe detail action `HStack`.
- 2026-07-07 21:31 Unit 2b green verified with `swift test --filter NativeMobileDesignContractTests` and `xcodebuild -project Spoonjoy.xcodeproj -scheme 'Spoonjoy iOS' -configuration BootstrapDebug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES build`.
- 2026-07-07 21:32 Unit 2c green verified long-title/accessibility contract plus `xcodebuild -project Spoonjoy.xcodeproj -scheme 'Spoonjoy macOS' -configuration BootstrapDebug -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES build`.
