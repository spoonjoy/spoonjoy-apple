# Unit 22i Recipe Action Intents Review

Verdict: CONVERGED

Scope reviewed: `2dc75dc` to current working tree on `slugger/shopping-app-entities`, limited to:
- `Sources/SpoonjoyCore/Native/NativeIntentAction.swift`
- `Tests/SpoonjoyCoreTests/RecipeActionIntentTests.swift`
- `tasks/2026-06-16-1754-doing-siri-full-access-parity/apple/unit-22i-recipe-action-intents-*`

## Findings

No blockers found.

## Evidence

- Resolver mutation refactor is behavior-preserving and does not loosen validation. `forkRecipe`, `saveRecipeToCookbook`, `removeRecipeFromCookbook`, and `deleteRecipe` now call `recipeIDForMutation` / `cookbookIDForMutation`; those helpers still reject placeholders, canonicalize IDs through the existing object-ID guard, and require exact descriptor route shape before returning the mutation ID (`NativeIntentAction.swift:227`, `NativeIntentAction.swift:247`, `NativeIntentAction.swift:268`, `NativeIntentAction.swift:289`, `NativeIntentAction.swift:436`, `NativeIntentAction.swift:447`).
- Outgoing REST request assertions cover method, base URL, path, query, headers, cache policy, and body shape for fork/save/remove/delete. Fork and titled fork assert POST `/api/v1/recipes/{id}/fork` JSON bodies; save asserts POST cookbook recipe path; remove asserts DELETE cookbook recipe path with JSON idempotency body; delete asserts DELETE recipe path with query idempotency and no body (`RecipeActionIntentTests.swift:193`, `RecipeActionIntentTests.swift:237`, `RecipeActionIntentTests.swift:248`, `RecipeActionIntentTests.swift:262`, `RecipeActionIntentTests.swift:275`, `RecipeActionIntentTests.swift:288`, `RecipeActionIntentTests.swift:426`, `RecipeActionIntentTests.swift:445`).
- Negative paths are covered for unresolved recipe placeholder, unresolved cookbook placeholder, bad recipe route, unsafe recipe ID, bad cookbook route, unsafe cookbook ID, non-owner delete, and unsafe current chef ID (`RecipeActionIntentTests.swift:301`).
- Coverage artifact is current and green: `unit-22i-recipe-action-intents-coverage-enforce.log` reports `coverage ok: 100.00% (23524/23524)`, and `.build/arm64-apple-macosx/debug/codecov/SpoonjoyApple.json` reports `NativeIntentAction.swift` at 100% lines/functions/regions. Coverage segments for the new helper range include nonzero counts on success and throwing branches.
- Final artifact set does not contain stale failed logs. The scoped logs end green: targeted Swift log passes 3 tests, full Swift log passes 475 tests, warning scan says `warning scan ok`, diff check says `diff check ok`, app-intents/project/scenario checks are ok.
- `git diff --check 2dc75dc -- Sources/SpoonjoyCore/Native/NativeIntentAction.swift Tests/SpoonjoyCoreTests/RecipeActionIntentTests.swift` produced no whitespace errors.

## Independent Check

Ran `swift test --filter RecipeActionIntentTests`; it passed with 3 Swift Testing tests and no warnings in the build/test output.
