#if canImport(AppIntents)
import AppIntents

// MARK: - Siri AI Developer Preview (Xcode 27.3 beta SDK)

// Siri AI calls only the custom intents an app marks as tools. `ToolIntent` exists only in the 27.3 beta SDK, so the
// marks sit behind ouro-ui-apple's fence for `OuroAXToolIntent`: AppIntents 301.1.16 is Xcode 27.2's; a newer
// framework, or building with -DOURO_SIRI_AI_SDK, turns this on. Xcode 27.2 and earlier compile none of it.
//
// Apple's spelling is `@AppIntent(.tool)` on the type, but an attribute can't be applied conditionally without
// declaring each intent twice. A `ToolIntent` conformance in an extension can, the way ouro-ui-apple builds
// `OuroAXToolIntent = OuroAXOutcomeIntent & ToolIntent`.
//
// The tools are the cooking and shopping actions people ask Siri for. Destructive and account actions (delete, clear,
// remove, discard, log out, revoke, disconnect, access keys, passkeys, password, linking a provider) are never tools.
// No tool adopts an App Intents schema (Ouro AX's intent.tool-not-on-schema). SiriToolIntentTests holds all of this.
#if OURO_SIRI_AI_SDK || canImport(AppIntents, _version: 301.2)
@available(iOS 27.3, macOS 27.3, *)
extension StartCookModeIntent: ToolIntent {}

@available(iOS 27.3, macOS 27.3, *)
extension ContinueCookModeIntent: ToolIntent {}

@available(iOS 27.3, macOS 27.3, *)
extension NextCookStepIntent: ToolIntent {}

@available(iOS 27.3, macOS 27.3, *)
extension PreviousCookStepIntent: ToolIntent {}

@available(iOS 27.3, macOS 27.3, *)
extension StartCookStepTimerIntent: ToolIntent {}

@available(iOS 27.3, macOS 27.3, *)
extension ReadCookStepIntent: ToolIntent {}

@available(iOS 27.3, macOS 27.3, *)
extension SearchSpoonjoyIntent: ToolIntent {}

@available(iOS 27.3, macOS 27.3, *)
extension OpenRecipeIntent: ToolIntent {}

@available(iOS 27.3, macOS 27.3, *)
extension AddRecipeIngredientsToShoppingListIntent: ToolIntent {}

@available(iOS 27.3, macOS 27.3, *)
extension AddShoppingListItemIntent: ToolIntent {}

@available(iOS 27.3, macOS 27.3, *)
extension SetShoppingListItemCheckedIntent: ToolIntent {}

@available(iOS 27.3, macOS 27.3, *)
extension SaveRecipeToCookbookIntent: ToolIntent {}

@available(iOS 27.3, macOS 27.3, *)
extension LogCookIntent: ToolIntent {}
#endif
#endif
