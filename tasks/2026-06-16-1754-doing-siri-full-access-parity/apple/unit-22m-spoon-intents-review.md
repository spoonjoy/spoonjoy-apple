# Unit 22m Spoon Intents Re-Review

Verdict: CONVERGED

## Findings

No blockers found in the Unit 22m diff.

## Prior Blocker Verification

1. Spoon edit/delete ownership is now asserted at the `NativeIntentActionResolver` body boundary.

   `Tests/SpoonjoyCoreTests/SpoonIntentTests.swift:235` through `Tests/SpoonjoyCoreTests/SpoonIntentTests.swift:262` require the `editCookLog` and `deleteCookLog` resolver bodies to derive `spoonID`, canonicalize `currentChefID`, compare `spoon.chefID == chefID`, throw `NativeIntentActionError.spoonOwnershipRequired(spoonID:)`, and only then queue `.spoonUpdate` / `.spoonDelete`. The Ruby mirror at `scripts/check-app-intents-contract.rb:2338` through `scripts/check-app-intents-contract.rb:2359` matches that resolver-body pressure.

2. Cover-from-spoon recipe ownership can no longer be satisfied by unrelated existing recipe delete code.

   `Tests/SpoonjoyCoreTests/SpoonIntentTests.swift:264` through `Tests/SpoonjoyCoreTests/SpoonIntentTests.swift:281` scope the ownership checks to the `createCoverFromSpoon` resolver body specifically. They require `recipeIDForMutation(recipe)`, `spoonIDForMutation(spoon)`, `canonicalObjectID(currentChefID, invalidError: .recipeOwnershipRequired(recipeID: recipeID))`, `guard recipe.chefID == chefID else`, `throw NativeIntentActionError.recipeOwnershipRequired(recipeID: recipeID)`, and `guard spoon.recipeID == recipeID else`. The Ruby mirror at `scripts/check-app-intents-contract.rb:2360` through `scripts/check-app-intents-contract.rb:2373` requires the same body-local tokens, so the pre-existing `deleteRecipe` ownership code in `Sources/SpoonjoyCore/Native/NativeIntentAction.swift:289` through `Sources/SpoonjoyCore/Native/NativeIntentAction.swift:309` cannot satisfy the cover contract by itself.

3. Shortcut budget and library-only protection now cover the spoon write intents.

   `Tests/SpoonjoyCoreTests/SpoonIntentTests.swift:108` through `Tests/SpoonjoyCoreTests/SpoonIntentTests.swift:117` count `AppShortcut(` entries and reject visible promotion of `LogCookIntent`, `EditCookLogIntent`, `DeleteCookLogIntent`, and `CreateCoverFromSpoonIntent` inside `SpoonjoyAppShortcuts`. `Tests/SpoonjoyCoreTests/SpoonIntentTests.swift:121` through `Tests/SpoonjoyCoreTests/SpoonIntentTests.swift:132` also require those same intents in `SpoonjoyIntentShortcutBudget`. The Ruby contract mirrors this at `scripts/check-app-intents-contract.rb:2173` through `scripts/check-app-intents-contract.rb:2203`.

## Required Lens

- Red tests compile and fail for the intended missing implementation: `swift test --filter SpoonIntentTests` builds successfully, then fails at `Tests/SpoonjoyCoreTests/SpoonIntentTests.swift:300` with missing spoon-intent implementation tokens.
- Ruby contract red is intentional: `ruby scripts/check-app-intents-contract.rb --domain spoon-intents` exits 1 with missing spoon-intent implementation tokens.
- No invented comments/feed/messaging/mail/social surfaces are introduced by the Unit 22m diff; both Swift and Ruby contracts include explicit forbidden-token pressure for those surfaces.
- Entity-backed parameters are required for recipe and spoon paths; string-only `recipeID` / `spoonID` AppIntent parameters are forbidden in the relevant intent bodies.
- HITL/confirmation pressure is adequate for edit/delete/cover: the AppIntent body contracts require `try await requestConfirmation(` for `EditCookLogIntent`, `DeleteCookLogIntent`, and `CreateCoverFromSpoonIntent`.
- Swift and Ruby contracts are consistent enough for Unit 22n; the key resolver-body, shortcut-budget, entity-parameter, and forbidden-surface assertions are mirrored across both files.

## Validation Run

- `swift test --filter SpoonIntentTests` - expected red; build succeeded; test failed on the new spoon-intent contract assertion.
- `ruby scripts/check-app-intents-contract.rb --domain spoon-intents` - expected red; failed on missing Unit 22m implementation tokens.
