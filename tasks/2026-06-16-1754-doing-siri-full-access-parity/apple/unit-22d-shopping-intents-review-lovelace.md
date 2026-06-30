# Unit 22d Shopping Siri Intents Red-Test Review - Lovelace

## Verdict

CONVERGED.

## Evidence Checked

- Reviewed `Tests/SpoonjoyCoreTests/ShoppingIntentTests.swift`; the red source contract targets only current shopping-list Siri actions: add item, check item, remove item, clear completed, clear all, and add recipe ingredients.
- Confirmed the dynamic resolver test passes for existing queue paths and does not pretend existing add/check/add-from-recipe/clear actions are absent. The artifact shows only the source-contract test failing.
- Confirmed remove-item is in Unit 22d scope and backed by existing product behavior: `ShoppingSurfaceAction.deleteItem` plans `ShoppingListRequests.deleteItem` plus `NativeQueuedMutation.shoppingDeleteItem`, and the queue kind already exists in `NativeQueuedMutationKind`.
- Reviewed `scripts/check-app-intents-contract.rb`; `--domain shopping-intents` is a real supported domain and requires entity-backed item/recipe parameters, shared state writer application, auth sentinel coverage, remove resolver/action metadata, destructive `requestConfirmation` for remove/clear-completed/clear-all, and scenario metadata.
- Ran `ruby scripts/check-app-intents-contract.rb --domain shopping-intents`; it fails red for the intended missing remove intent/resolver/metadata/scenario coverage and missing clear destructive confirmations.
- Checked red artifacts:
  - `apple/unit-22d-shopping-intents-red.log` builds, runs 2 tests, passes the existing resolver queue test, fails the source contract, and ends with `expected red status: 1`.
  - `apple/unit-22d-shopping-intents-app-intents-contract-red.log` fails for the same intended App Intents contract gaps and ends with `expected red status: 1`.

## Residual Risks

- The static checks are token-based and intentionally syntax-sensitive, but they follow the existing App Intents implementation style and are not constraining a future product surface.
- The duplicate missing-body line for `RemoveShoppingListItemIntent` in the static artifact is harmless noise from both require/forbid body checks observing the missing declaration.
