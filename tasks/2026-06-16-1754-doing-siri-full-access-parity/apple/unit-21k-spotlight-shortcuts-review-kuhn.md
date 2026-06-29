# Unit 21k Spotlight/App Shortcuts Re-Review

Reviewer: Kuhn the 2nd
Scope: Incremental request-batch purge model after the mixed-scope deletion bug was found.

## Verdict

CONVERGED

## Findings

No blockers identified.

## Review Notes

- Request-batch purge requests now carry their own `accountID` and `environment`, fixing the prior flattened mixed-scope deletion bug.
- Shopping, spoon, capture-draft, and chef-profile purge paths use the same scoped request pattern.
- `NativeLiveAppStore` consumes each request's own scope instead of deriving scope from current global state.
- CoreSpotlight identifiers and domains remain generated from scoped account/environment metadata.
- `SpoonjoySpotlightIndexer` maps CoreSpotlight identifiers back to AppEntity descriptor identifiers, including spoon route parsing with the `~` delimiter.
- Donation deletion covers the shipped entity and intent surfaces.
- Tests verify request-level scope preservation for previous-account purges.
- The App Intents contract script checks request-batch consumers for shopping and spoon purges.

## Evidence Reviewed

- `apple/unit-21k-spotlight-shortcuts-affected.log`: 157 focused affected tests passed.
- `apple/unit-21k-spotlight-shortcuts-swift-full.log`: 460 full Swift tests passed.
- `apple/unit-21k-spotlight-shortcuts-app-intents-contract.log`: spotlight-shortcuts contract passed.
- `apple/unit-21k-shopping-app-intents-contract.log`: shopping contract passed.
- `apple/unit-21k-spoon-app-intents-contract.log`: spoon contract passed.
- `apple/unit-21k-capture-draft-app-intents-contract.log`: capture-draft contract passed.
- `apple/unit-21k-spotlight-shortcuts-ios-build.log`: iOS simulator build succeeded with expected local SDK target-27 warning.
- `apple/unit-21k-spotlight-shortcuts-macos-build.log`: macOS build succeeded with expected local SDK target-27 warning.
- `git diff --check`: clean.
