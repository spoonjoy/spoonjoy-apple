# Unit 21j Spotlight/App Shortcuts Contract Review

Reviewer: Singer the 2nd (`019f12cf-de72-7ae2-9721-ac533a29bc44`)

## Verdict

`CONVERGED`

## Review Trail

- Round 1 found stale/fake Apple API pressure around `ViewAnnotation` / `SpoonjoyViewAnnotation`, donation deletion placement, brittle conformance ordering, weak Swift comment stripping, and purge-hook specificity.
- The test and Ruby contract were revised to use public `AppEntityAnnotatable` / `appEntityIdentifier` semantics, separate donation cleanup from Spotlight indexing, allow flexible `IndexedEntity` conformance, strip Swift line comments correctly, and require concrete account/environment/domain purge hooks.
- Round 2 found remaining forced `RelevantIntent` / `RelevantIntentManager` surface and a root-view-only annotation requirement.
- The contract was revised again to remove `RelevantIntent` / `RelevantIntentManager` / `SpoonjoyRelevantIntentProvider` requirements and scan `Apps/Spoonjoy/Shared/**/*.swift` for on-screen entity annotation tokens so real route/feature views can own annotations.

## Evidence

- `rg -n "RelevantIntent|SpoonjoyRelevantIntentProvider|ViewAnnotation|SpoonjoyViewAnnotation" Tests/SpoonjoyCoreTests/SpotlightShortcutTransferTests.swift scripts/check-app-intents-contract.rb || true` produced no output.
- `ruby -c scripts/check-app-intents-contract.rb` returned `Syntax OK`.
- `tasks/2026-06-16-1754-doing-siri-full-access-parity/apple/unit-21j-spotlight-shortcuts-app-intents-contract-red.log` records `expected red status: 1`.
- `tasks/2026-06-16-1754-doing-siri-full-access-parity/apple/unit-21j-spotlight-shortcuts-red.log` records `expected red status: 1`.
