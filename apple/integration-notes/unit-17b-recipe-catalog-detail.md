# Unit 17b Recipe Catalog And Detail Integration Notes

## Orchestrator-Applied Files

- `Sources/SpoonjoyCore/Features/RecipeCatalog/RecipeCatalogRepository.swift`
- `Sources/SpoonjoyCore/Features/RecipeCatalog/RecipeCatalogViewModel.swift`
- `Sources/SpoonjoyCore/Features/RecipeCatalog/RecipeDetailScreenViewModel.swift`
- `Sources/SpoonjoyCore/RecipeCookbook/RecipeCookbook.swift`
- `Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift`
- `Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift`
- `Apps/Spoonjoy/Shared/Views/RecipesView.swift`
- `Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift`
- `Apps/Spoonjoy/Shared/Views/CookModeView.swift`

## Product Surface

- `/recipes` native surface now reads through `RecipeCatalogViewModel` and `RecipeCatalogRepository` instead of raw fixture arrays; visible shell wiring uses `FallbackRecipeCatalogRepository(primary: LiveRecipeCatalogRepository, fallback: SnapshotRecipeCatalogRepository)`.
- Recipe detail native surface now exposes the current web read surface through `RecipeDetailRouteView`, so direct recipe links can fetch live detail data even when the id is not already in the restored shell snapshot. Start-cook routes use `CookModeRouteView` with the same repository fallback so direct-fetched details do not route into a placeholder. The detail screen covers cover provenance, chef attribution, servings, source attribution, ingredients, method steps, step-output dependencies, recent spoons, cookbook-save state, shopping-list ingredient presence, owner tools, share, start-cook, and offline stale display.
- Unsupported product surfaces remain absent: no comments, social feed, meal plan, nutrition, fitness, or media playback UI was introduced.

## Cache And Live Reads

- `LiveRecipeCatalogRepository` uses `PublicCatalogRequests.listRecipes` and `PublicCatalogRequests.recipeDetail`.
- Snapshot/offline shell wiring uses `contentState.recipeCatalog` with `NativeCacheDomain.recipeCatalog` and `NativeCacheDomain.recipeDetail` freshness indicators. Snapshot fallback honors q-only list filtering and direct detail fallback while live reads are unavailable.
- The existing live store continues to restore full recipe payloads from sync records, with durable-cache placeholder fallback reserved for missing decoded sync records only.

## App And Project Metadata

- SwiftPM automatically includes the new `Sources/SpoonjoyCore/Features/RecipeCatalog/**` files.
- `scripts/check-kitchen-recipe-surfaces.rb` and `scripts/check-xcode-project-contract.rb` pass under `apple/unit-17b-recipe-catalog-detail-surface-green.log`.
- No Xcode project membership patch was required for the new core feature files.
