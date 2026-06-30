# Unit 22c Open/Search/Share/Cook Intents Review - Noether

Verdict: CONVERGED.

## Evidence Checked

- Diff scope is limited to `Sources/SpoonjoyCore/Native/NativeIntentAction.swift` and `Tests/SpoonjoyCoreTests/OpenSearchShareCookIntentTests.swift`.
- `NativeIntentActionResolver.publicShareValue` moved from `private` to package-internal only, not `public`; this is justified by `@testable` coverage of the typed `NativeIntentActionError.shareUnavailable(.shoppingList)` branch and does not create exported API surface.
- No production force unwrap, `try!`, `as!`, `fatalError`, `preconditionFailure`, or assertion crash was introduced in the changed resolver path.
- Resolver tests cover entity-backed open recipe, start cook mode, continue cook mode, open cookbook, open profile, trimmed scoped search, public recipe/cookbook share values, private shopping-list transfer values, placeholder errors, invalid ID errors, mismatched route errors, and the non-public route share error.
- Unit 22b share semantics remain enforced: recipe/cookbook sharing returns public URLs, while shopping-list sharing returns a private transfer value with `publicURL == nil`.
- App Intents source and contract checks keep Siri paths entity-backed: open/search/share/cook intents use App Entities, and shopping-list share returns `ReturnsValue<String>` without `OpenURLIntent`.
- Product-scope guards remain present: no invented comment/feed/message/mail/social surfaces, no public shopping-list share URL, and no string-ID-only App Intent path.

## Final Matrix

- Focused `OpenSearchShareCookIntentTests`: 3 tests passed in `unit-22c-open-search-share-cook-intents-swift-test.log`.
- `appintents-contract --domain open-search-share-cook`: green in `unit-22c-open-search-share-cook-intents-app-intents-contract.log`.
- `scenario:native-metadata`: green in `unit-22c-open-search-share-cook-intents-scenario-native-metadata.log` and JSON reports `"ok": true`.
- `swift-full`: 470 tests passed in `unit-22c-open-search-share-cook-intents-swift-full.log`.
- Coverage: `Sources/SpoonjoyCore` enforcement is `100.00% (23400/23400)` in `unit-22c-open-search-share-cook-intents-coverage-enforce.log`; the backing codecov JSON and profdata are timestamped with the coverage artifact.
- `project-contract`, `diff-check`, and `warning-scan`: green in their Unit 22c logs.

## Residual Risks

- The focused App Intents checks are source/contract tests rather than runtime `AppIntentsTesting` execution, but this matches the Unit 22c acceptance path and is backed by full Swift, native-metadata scenario, and project-contract artifacts.
