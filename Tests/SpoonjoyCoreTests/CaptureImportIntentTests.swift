import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Capture import Siri intent contracts")
struct CaptureImportIntentTests {
    @Test("capture import Siri intents require entity-backed lifecycle actions")
    func captureImportSiriIntentsRequireEntityBackedLifecycleActions() throws {
        var failures = captureImportIntentSourceContractFailures(
            requiredFiles: [
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                "Apps/Spoonjoy/Shared/Native/SpoonjoyCaptureDraftEntities.swift",
                "Sources/SpoonjoyCore/Native/CaptureDraftEntityCatalog.swift",
                "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift",
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift",
                "scripts/check-app-intents-contract.rb"
            ],
            requiredTokens: [
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift": [
                    "struct CaptureRecipeIntent: AppIntent",
                    "struct SubmitCaptureImportIntent: AppIntent",
                    "struct OpenCaptureDraftIntent: AppIntent",
                    "struct DiscardCaptureDraftIntent: AppIntent",
                    "@Parameter(title: \"Source\", requestValueDialog:",
                    "var draft: SpoonjoyCaptureDraftEntity",
                    "NativeIntentActionResolver().captureRecipe(",
                    "NativeIntentActionResolver().submitCaptureImport(draft: draft.descriptor",
                    "NativeIntentActionResolver().openCaptureDraft(draft: draft.descriptor",
                    "NativeIntentActionResolver().discardCaptureDraft(draft: draft.descriptor",
                    "try await requestConfirmation(",
                    "let currentChefID = try await SpoonjoyIntentStateWriter().currentAccountID()",
                    "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)",
                    "SpoonjoyInteractionDonor",
                    "OpenURLIntent(action.url)",
                    "String(describing: SubmitCaptureImportIntent())",
                    "String(describing: OpenCaptureDraftIntent())",
                    "String(describing: DiscardCaptureDraftIntent())"
                ],
                "Apps/Spoonjoy/Shared/Native/SpoonjoyCaptureDraftEntities.swift": [
                    "struct SpoonjoyCaptureDraftEntity: AppEntity, IndexedEntity, Transferable",
                    "struct SpoonjoyCaptureDraftEntityQuery: EntityQuery, EntityStringQuery",
                    "resolvedCaptureDraftID() throws",
                    "NativeIntentActionError.unresolvedCaptureDraftEntity"
                ],
                "Sources/SpoonjoyCore/Native/CaptureDraftEntityCatalog.swift": [
                    "public let importableDraft: CaptureDraft?",
                    "public let pendingImport: NativeQueuedMutation?",
                    "importableDraft: draft",
                    "pendingImport: record.pendingImport",
                    "recipeImportSource == draftImportSource"
                ],
                "Sources/SpoonjoyCore/Native/NativeIntentAction.swift": [
                    "case captureDraftOwnershipRequired(draftID: String)",
                    "case captureImportNeedsTextRecognition(draftID: String)",
                    "public func submitCaptureImport(",
                    "func captureImportSubmitAction(from plan:",
                    "public func openCaptureDraft(",
                    "public func discardCaptureDraft(",
                    "currentChefID: String",
                    "CaptureImportViewModel(",
                    "pendingRetryMutation:",
                    "NativeQueuedMutation.captureDraftDiscard(",
                    "captureDraftForMutation(",
                    "captureDraftIDForMutation(",
                    "DeepLinkURLBuilder.url(for: .capture)"
                ],
                "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift": [
                    "CaptureRecipeIntent",
                    "SubmitCaptureImportIntent",
                    "OpenCaptureDraftIntent",
                    "DiscardCaptureDraftIntent"
                ],
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift": [
                    "Capture import Siri intents",
                    "CaptureRecipeIntent",
                    "SubmitCaptureImportIntent",
                    "OpenCaptureDraftIntent",
                    "DiscardCaptureDraftIntent"
                ],
                "scripts/check-app-intents-contract.rb": [
                    "\"capture-import-intents\"",
                    "if domain == \"capture-import-intents\"",
                    "SubmitCaptureImportIntent",
                    "OpenCaptureDraftIntent",
                    "DiscardCaptureDraftIntent"
                ]
            ],
            forbiddenTokens: [
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift": [
                    "@Parameter(title: \"Draft ID\")",
                    "var draftID: String",
                    "String-only capture import",
                    "CommentIntent",
                    "FeedIntent",
                    "MessageIntent",
                    "MailIntent",
                    "social-feed",
                    "/comments",
                    "/feeds",
                    "/messages",
                    "mailto:",
                    "MessageUI",
                    "TODO CaptureImportIntent",
                    "eventually add capture import intents"
                ],
                "Sources/SpoonjoyCore/Native/NativeIntentAction.swift": [
                    "submitCaptureImport(draftID:",
                    "discardCaptureDraft(draftID:",
                    "TODO CaptureImportIntent",
                    "eventually add capture import intents"
                ]
            ]
        )

        failures.append(contentsOf: captureImportIntentShortcutBudgetFailures(
            relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
            maximumShortcuts: 10,
            libraryOnlyIntentNames: [
                "SubmitCaptureImportIntent",
                "OpenCaptureDraftIntent",
                "DiscardCaptureDraftIntent"
            ]
        ))

        failures.append(contentsOf: captureImportIntentBodyContractFailures(
            contracts: [
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "SpoonjoyIntentShortcutBudget",
                    pattern: #"private\s+enum\s+SpoonjoyIntentShortcutBudget"#,
                    requiredTokens: [
                        "String(describing: SubmitCaptureImportIntent())",
                        "String(describing: OpenCaptureDraftIntent())",
                        "String(describing: DiscardCaptureDraftIntent())"
                    ],
                    forbiddenTokens: []
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "CaptureRecipeIntent",
                    pattern: #"struct\s+CaptureRecipeIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Source\", requestValueDialog:",
                        "var source: String",
                        "NativeIntentActionResolver().captureRecipe(",
                        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)",
                        "await SpoonjoyInteractionDonor().donateBestEffort(self)",
                        "OpenURLIntent(action.url)"
                    ],
                    forbiddenTokens: []
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "SubmitCaptureImportIntent",
                    pattern: #"struct\s+SubmitCaptureImportIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Capture Draft\", requestValueDialog:",
                        "var draft: SpoonjoyCaptureDraftEntity",
                        "try await requestConfirmation(",
                        "let currentChefID = try await SpoonjoyIntentStateWriter().currentAccountID()",
                        "let createdAt = SpoonjoyIntentClock.timestamp()",
                        "NativeIntentActionResolver().submitCaptureImport(draft: draft.descriptor",
                        "currentChefID: currentChefID",
                        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)",
                        "await SpoonjoyInteractionDonor().donateBestEffort(self)",
                        "OpenURLIntent(action.url)"
                    ],
                    forbiddenTokens: [
                        "var draftID: String",
                        "@Parameter(title: \"Draft ID\")"
                    ]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "OpenCaptureDraftIntent",
                    pattern: #"struct\s+OpenCaptureDraftIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Capture Draft\", requestValueDialog:",
                        "var draft: SpoonjoyCaptureDraftEntity",
                        "NativeIntentActionResolver().openCaptureDraft(draft: draft.descriptor",
                        "await SpoonjoyInteractionDonor().donateBestEffort(self)",
                        "OpenURLIntent(action.url)"
                    ],
                    forbiddenTokens: [
                        "var draftID: String",
                        "@Parameter(title: \"Draft ID\")"
                    ]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "DiscardCaptureDraftIntent",
                    pattern: #"struct\s+DiscardCaptureDraftIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Capture Draft\", requestValueDialog:",
                        "var draft: SpoonjoyCaptureDraftEntity",
                        "try await requestConfirmation(",
                        "let currentChefID = try await SpoonjoyIntentStateWriter().currentAccountID()",
                        "let createdAt = SpoonjoyIntentClock.timestamp()",
                        "NativeIntentActionResolver().discardCaptureDraft(draft: draft.descriptor",
                        "currentChefID: currentChefID",
                        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)",
                        "await SpoonjoyInteractionDonor().donateBestEffort(self)",
                        "OpenURLIntent(action.url)"
                    ],
                    forbiddenTokens: [
                        "var draftID: String",
                        "@Parameter(title: \"Draft ID\")"
                    ]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "SpoonjoyIntentStateWriter",
                    pattern: #"private\s+struct\s+SpoonjoyIntentStateWriter"#,
                    requiredTokens: [
                        ".recipeImportSubmit",
                        "queue.mutations.contains(where:",
                        "clientMutationID == mutation.clientMutationID",
                        "recipeImportSource == source",
                        "recordingCaptureImportRetry",
                        ".captureDraftDiscard",
                        "recipeImportSource == draftImportSource",
                        "removing(clientMutationIDs:",
                        "discardingCaptureDraft",
                        "CaptureDraftEntityIndexPurgePlan.draftDiscardPurge",
                        "CaptureDraftEntityCatalog.purgeEntityIdentifiers",
                        "SpoonjoySpotlightIndexer().delete"
                    ],
                    forbiddenTokens: []
                )
            ]
        ))

        failures.append(contentsOf: captureImportIntentBodyContractFailures(
            contracts: [
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "submitCaptureImport resolver",
                    pattern: #"public\s+func\s+submitCaptureImport\("#,
                    requiredTokens: [
                        "let captureDraftID = try captureDraftIDForMutation(draft)",
                        "let chefID = try canonicalObjectID(currentChefID, invalidError: .captureDraftOwnershipRequired(draftID: captureDraftID))",
                        "guard draft.scope.accountID == chefID else",
                        "let captureDraft = try captureDraftForMutation(draft)",
                        "guard captureDraft.importReadiness == .ready else",
                        "throw NativeIntentActionError.captureImportNeedsTextRecognition(draftID: captureDraftID)",
                        "let plan = try CaptureImportViewModel(",
                        "pendingRetryMutation: draft.pendingImport",
                        "return try captureImportSubmitAction(from: plan, draftID: captureDraftID)"
                    ],
                    forbiddenTokens: [
                        "draftID: String"
                    ]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "captureImportSubmitAction helper",
                    pattern: #"func\s+captureImportSubmitAction\(from\s+plan:"#,
                    requiredTokens: [
                        "guard let mutation = plan.offlineRetryMutation else",
                        "throw NativeIntentActionError.captureImportQueueUnavailable(draftID: draftID)",
                        "route: .capture",
                        "DeepLinkURLBuilder.url(for: .capture)"
                    ],
                    forbiddenTokens: [
                        "draftID: String"
                    ]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "openCaptureDraft resolver",
                    pattern: #"public\s+func\s+openCaptureDraft\("#,
                    requiredTokens: [
                        "_ = try captureDraftIDForMutation(draft)",
                        "route: .capture",
                        "DeepLinkURLBuilder.url(for: .capture)"
                    ],
                    forbiddenTokens: [
                        "draftID: String"
                    ]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "discardCaptureDraft resolver",
                    pattern: #"public\s+func\s+discardCaptureDraft\("#,
                    requiredTokens: [
                        "let captureDraftID = try captureDraftIDForMutation(draft)",
                        "let chefID = try canonicalObjectID(currentChefID, invalidError: .captureDraftOwnershipRequired(draftID: captureDraftID))",
                        "guard draft.scope.accountID == chefID else",
                        "let captureDraft = try captureDraftForMutation(draft)",
                        "let draftImportSource = try? captureDraft.importSource()",
                        "NativeQueuedMutation.captureDraftDiscard(",
                        "route: .capture",
                        "DeepLinkURLBuilder.url(for: .capture)"
                    ],
                    forbiddenTokens: [
                        "draftID: String"
                    ]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "captureDraftIDForMutation helper",
                    pattern: #"private\s+func\s+captureDraftIDForMutation\("#,
                    requiredTokens: [
                        "guard !draft.isPlaceholder else",
                        "throw NativeIntentActionError.unresolvedCaptureDraftEntity",
                        "let captureDraftID = try canonicalObjectID(draft.captureDraftID",
                        "guard draft.route == .capture else",
                        "return captureDraftID"
                    ],
                    forbiddenTokens: []
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "captureDraftForMutation helper",
                    pattern: #"private\s+func\s+captureDraftForMutation\("#,
                    requiredTokens: [
                        "guard let captureDraft = draft.importableDraft else",
                        "throw NativeIntentActionError.unresolvedCaptureDraftEntity",
                        "return captureDraft"
                    ],
                    forbiddenTokens: []
                )
            ]
        ))

        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
    }

    @Test("capture import intent resolver queues import-ready drafts through the native import API")
    func captureImportIntentResolverQueuesImportReadyDraftsThroughNativeImportAPI() throws {
        let resolver = NativeIntentActionResolver()
        let draft = try CaptureDraft.localText(
            id: "draft_capture_import_text",
            rawText: "Siri captured pasta\nBoil noodles until springy.",
            sourceURL: URL(string: "https://example.com/siri-capture")!,
            createdAt: "2026-06-29T15:59:00.000Z"
        )
        let descriptor = captureImportIntentDescriptor(draft: draft)

        let action = try resolver.submitCaptureImport(
            draft: descriptor,
            currentChefID: " chef_ari ",
            createdAt: "2026-06-29T16:00:00.000Z"
        )
        let mutation = try #require(action.nativeQueuedMutation)
        let expectedSource = try draft.importSource()

        #expect(action.queuedMutation == nil)
        #expect(action.captureDraft == nil)
        #expect(action.route == .capture)
        #expect(action.url == URL(string: "spoonjoy://capture"))
        #expect(mutation.queueableKind == .recipeImportSubmit)
        #expect(mutation.clientMutationID == "intent-capture-import-draft_capture_import_text-2026-06-29T16-00-00-000Z")
        #expect(mutation.createdAt == "2026-06-29T16:00:00.000Z")
        #expect(mutation.recipeImportSource == expectedSource)
        try captureImportIntentAssertJSONRequest(
            try captureImportIntentRequest(from: mutation),
            expected: [
                "clientMutationId": "intent-capture-import-draft_capture_import_text-2026-06-29T16-00-00-000Z",
                "source": [
                    "type": "text",
                    "text": "Siri captured pasta\nBoil noodles until springy.",
                    "url": "https://example.com/siri-capture"
                ]
            ]
        )
    }

    @Test("capture import intent resolver reuses pending import mutations and opens drafts")
    func captureImportIntentResolverReusesPendingImportMutationsAndOpensDrafts() throws {
        let resolver = NativeIntentActionResolver()
        let draft = try CaptureDraft.importURL(
            id: "draft_capture_import_url",
            url: URL(string: "https://example.com/importable-recipe")!,
            createdAt: "2026-06-29T16:01:00.000Z"
        )
        let pendingMutation = NativeQueuedMutation.recipeImportSubmit(
            source: try draft.importSource(),
            clientMutationID: "cm_existing_capture_import",
            createdAt: "2026-06-29T16:01:30.000Z"
        )
        let descriptor = captureImportIntentDescriptor(
            draft: draft,
            pendingImport: pendingMutation
        )

        let submitAction = try resolver.submitCaptureImport(
            draft: descriptor,
            currentChefID: "chef_ari",
            createdAt: "2026-06-29T16:02:00.000Z"
        )
        let openAction = try resolver.openCaptureDraft(draft: descriptor)
        let mutation = try #require(submitAction.nativeQueuedMutation)

        #expect(mutation == pendingMutation)
        #expect(submitAction.route == .capture)
        #expect(submitAction.url == URL(string: "spoonjoy://capture"))
        #expect(openAction.route == .capture)
        #expect(openAction.url == URL(string: "spoonjoy://capture"))
        #expect(openAction.queuedMutation == nil)
        #expect(openAction.nativeQueuedMutation == nil)
        #expect(openAction.captureDraft == nil)
    }

    @Test("capture import intent resolver discards drafts and preserves queued import cancellation metadata")
    func captureImportIntentResolverDiscardsDraftsAndPreservesQueuedImportCancellationMetadata() throws {
        let resolver = NativeIntentActionResolver()
        let draft = try CaptureDraft.shareSheetURL(
            id: "draft_capture_import_discard",
            url: URL(string: "https://example.com/discardable-recipe")!,
            createdAt: "2026-06-29T16:03:00.000Z"
        )
        let descriptor = captureImportIntentDescriptor(draft: draft)

        let action = try resolver.discardCaptureDraft(
            draft: descriptor,
            currentChefID: "chef_ari",
            createdAt: "2026-06-29T16:04:00.000Z"
        )
        let mutation = try #require(action.nativeQueuedMutation)
        let expectedSource = try draft.importSource()

        guard case .captureDraftDiscard(let discardMutation, let draftID, let draftImportSource, let route, let url) = action else {
            Issue.record("Expected capture draft discard action.")
            return
        }

        #expect(discardMutation == mutation)
        #expect(draftID == "draft_capture_import_discard")
        #expect(draftImportSource == expectedSource)
        #expect(route == .capture)
        #expect(url == URL(string: "spoonjoy://capture"))
        #expect(action.queuedMutation == nil)
        #expect(action.captureDraft == nil)
        #expect(mutation.queueableKind == .captureDraftDiscard)
        #expect(mutation.clientMutationID == "intent-capture-discard-draft_capture_import_discard-2026-06-29T16-04-00-000Z")
        #expect(mutation.createdAt == "2026-06-29T16:04:00.000Z")
        #expect(throws: NativeQueuedMutationRequestError.localOnlyMutation) {
            _ = try mutation.requestBuilder()
        }
    }

    @Test("capture import intent resolver can discard OCR-needed image drafts without import source")
    func captureImportIntentResolverCanDiscardOCRNeededImageDraftsWithoutImportSource() throws {
        let resolver = NativeIntentActionResolver()
        let imageDraft = try CaptureDraft.cameraImage(
            id: "draft_capture_import_ocr_needed",
            assetIdentifier: "local-camera-ocr-needed",
            recognizedText: Optional<String>.none,
            createdAt: "2026-06-29T16:05:00.000Z"
        )
        let descriptor = captureImportIntentDescriptor(draft: imageDraft)

        #expect(throws: NativeIntentActionError.captureImportNeedsTextRecognition(draftID: "draft_capture_import_ocr_needed")) {
            try resolver.submitCaptureImport(
                draft: descriptor,
                currentChefID: "chef_ari",
                createdAt: "2026-06-29T16:06:00.000Z"
            )
        }

        let discardAction = try resolver.discardCaptureDraft(
            draft: descriptor,
            currentChefID: "chef_ari",
            createdAt: "2026-06-29T16:07:00.000Z"
        )
        guard case .captureDraftDiscard(_, let draftID, let draftImportSource, _, _) = discardAction else {
            Issue.record("Expected capture draft discard action.")
            return
        }

        #expect(draftID == "draft_capture_import_ocr_needed")
        #expect(draftImportSource == nil)
    }

    @Test("capture import intent resolver rejects unresolved unsafe and non-owner draft entities")
    func captureImportIntentResolverRejectsUnresolvedUnsafeAndNonOwnerDraftEntities() throws {
        let resolver = NativeIntentActionResolver()
        let draft = try CaptureDraft.localText(
            id: "draft_capture_import_guarded",
            rawText: "Guarded draft\nKeep this private.",
            createdAt: "2026-06-29T16:08:00.000Z"
        )
        let descriptor = captureImportIntentDescriptor(draft: draft)

        #expect(
            NativeIntentActionError.captureDraftOwnershipRequired(draftID: "draft_capture_import_guarded").description ==
                "Only the capture draft owner can update draft_capture_import_guarded from Siri."
        )
        #expect(
            NativeIntentActionError.captureImportNeedsTextRecognition(draftID: "draft_capture_import_guarded").description ==
                "Capture draft draft_capture_import_guarded needs text recognition before Siri can submit it."
        )
        #expect(
            NativeIntentActionError.captureImportQueueUnavailable(draftID: "draft_capture_import_guarded").description ==
                "Capture draft draft_capture_import_guarded could not be queued for import from Siri."
        )
        #expect(throws: NativeIntentActionError.captureImportQueueUnavailable(draftID: "draft_capture_import_guarded")) {
            try resolver.captureImportSubmitAction(
                from: CaptureImportPlan(userFacingMessage: "Missing retry mutation."),
                draftID: "draft_capture_import_guarded"
            )
        }

        #expect(throws: NativeIntentActionError.unresolvedCaptureDraftEntity) {
            try resolver.openCaptureDraft(draft: .placeholder)
        }
        #expect(throws: NativeIntentActionError.unresolvedCaptureDraftEntity) {
            try resolver.submitCaptureImport(
                draft: captureImportIntentDescriptor(draft: draft, route: .recipes),
                currentChefID: "chef_ari",
                createdAt: "2026-06-29T16:09:00.000Z"
            )
        }
        #expect(throws: NativeIntentActionError.unresolvedCaptureDraftEntity) {
            try resolver.discardCaptureDraft(
                draft: captureImportIntentDescriptor(draft: draft, captureDraftID: "bad/draft"),
                currentChefID: "chef_ari",
                createdAt: "2026-06-29T16:10:00.000Z"
            )
        }
        #expect(throws: NativeIntentActionError.unresolvedCaptureDraftEntity) {
            try resolver.submitCaptureImport(
                draft: captureImportIntentDescriptor(draft: draft, includeImportableDraft: false),
                currentChefID: "chef_ari",
                createdAt: "2026-06-29T16:11:00.000Z"
            )
        }
        #expect(throws: NativeIntentActionError.captureDraftOwnershipRequired(draftID: "draft_capture_import_guarded")) {
            try resolver.submitCaptureImport(
                draft: descriptor,
                currentChefID: "chef_jules",
                createdAt: "2026-06-29T16:12:00.000Z"
            )
        }
        #expect(throws: NativeIntentActionError.captureDraftOwnershipRequired(draftID: "draft_capture_import_guarded")) {
            try resolver.discardCaptureDraft(
                draft: descriptor,
                currentChefID: "bad/chef",
                createdAt: "2026-06-29T16:13:00.000Z"
            )
        }
        #expect(throws: NativeIntentActionError.captureDraftOwnershipRequired(draftID: "draft_capture_import_guarded")) {
            try resolver.discardCaptureDraft(
                draft: descriptor,
                currentChefID: "chef_jules",
                createdAt: "2026-06-29T16:14:00.000Z"
            )
        }
    }
}

private let captureImportIntentConfiguration = APIClientConfiguration(
    baseURL: URL(string: "https://spoonjoy.app")!,
    bearerToken: "sj_private_token"
)

private func captureImportIntentDescriptor(
    draft: CaptureDraft,
    captureDraftID: String? = nil,
    accountID: String = "chef_ari",
    route: AppRoute = .capture,
    includeImportableDraft: Bool = true,
    pendingImport: NativeQueuedMutation? = nil
) -> CaptureDraftEntityDescriptor {
    let resolvedDraftID = captureDraftID ?? draft.id
    let scope = CaptureDraftEntityScope(accountID: accountID, environment: .production)
    let title = "Capture Draft \(resolvedDraftID)"
    return CaptureDraftEntityDescriptor(
        id: CaptureDraftEntityCatalog.captureDraftEntityIdentifier(
            draftID: resolvedDraftID,
            accountID: scope.accountID,
            environment: scope.environment
        ),
        captureDraftID: resolvedDraftID,
        scope: scope,
        title: title,
        subtitle: pendingImport == nil ? "Text draft" : "Text draft - pending import",
        disambiguationLabel: "\(title) from capture",
        route: route,
        source: draft.source,
        importReadiness: draft.importReadiness,
        hasPendingImport: pendingImport != nil,
        importableDraft: includeImportableDraft ? draft : nil,
        pendingImport: pendingImport,
        transferValue: CaptureDraftEntityTransferValue(
            kind: .captureDraft,
            rawResourceID: resolvedDraftID,
            title: title,
            routeIdentifier: route.stateIdentifier,
            publicURL: nil,
            privateTransferValue: "schema=app.spoonjoy.capture-draft-entity.v1;domain=capture-draft;title=\(title)",
            userVisibleSummary: title
        )
    )
}

private func captureImportIntentRequest(from mutation: NativeQueuedMutation) throws -> APIRequest {
    try mutation.requestBuilder().urlRequest(configuration: captureImportIntentConfiguration)
}

private func captureImportIntentAssertJSONRequest(
    _ request: APIRequest,
    expected: [String: Any]
) throws {
    #expect(request.method == .post)
    #expect(request.url.baseURL.absoluteString == "https://spoonjoy.app")
    #expect(request.url.path == "/api/v1/recipes/import")
    #expect(request.queryItems.isEmpty)
    #expect(request.headers == [
        "Accept": "application/json",
        "Authorization": "Bearer sj_private_token",
        "Content-Type": "application/json"
    ])
    #expect(request.responseCachePolicy == .privateNoStore)
    #expect(NSDictionary(dictionary: try captureImportIntentJSONBody(from: request)).isEqual(to: expected))
}

private func captureImportIntentJSONBody(from request: APIRequest) throws -> [String: Any] {
    let body = try #require(request.body)
    return try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
}

private func captureImportIntentSourceContractFailures(
    requiredFiles: [String],
    requiredTokens: [String: [String]],
    forbiddenTokens: [String: [String]]
) -> [String] {
    var failures: [String] = []
    for relativePath in requiredFiles {
        guard let content = try? captureImportIntentReadRepoFile(relativePath) else {
            failures.append("missing \(relativePath)")
            continue
        }
        let uncommented = captureImportIntentUncommentedSource(content, relativePath: relativePath)
        for token in requiredTokens[relativePath, default: []] where !uncommented.contains(token) {
            failures.append("\(relativePath) missing \(token)")
        }
        for token in forbiddenTokens[relativePath, default: []] where uncommented.contains(token) {
            failures.append("\(relativePath) contains forbidden \(token)")
        }
    }
    return failures
}

private func captureImportIntentShortcutBudgetFailures(
    relativePath: String,
    maximumShortcuts: Int,
    libraryOnlyIntentNames: [String]
) -> [String] {
    guard let content = try? captureImportIntentReadRepoFile(relativePath) else {
        return ["missing \(relativePath)"]
    }
    let uncommented = captureImportIntentUncommentedSwift(content)
    let shortcutCount = uncommented.components(separatedBy: "AppShortcut(").count - 1
    var failures: [String] = []
    if shortcutCount > maximumShortcuts {
        failures.append("\(relativePath) declares \(shortcutCount) App Shortcuts, above Apple limit \(maximumShortcuts)")
    }

    if let body = captureImportIntentDeclarationBody(in: uncommented, pattern: #"struct\s+SpoonjoyAppShortcuts\s*:\s*AppShortcutsProvider"#) {
        for intentName in libraryOnlyIntentNames where body.contains("\(intentName)(") {
            failures.append("\(relativePath) promotes library-only \(intentName) into AppShortcuts")
        }
    } else {
        failures.append("\(relativePath) missing body for SpoonjoyAppShortcuts")
    }
    return failures
}

private func captureImportIntentBodyContractFailures(
    contracts: [(
        relativePath: String,
        label: String,
        pattern: String,
        requiredTokens: [String],
        forbiddenTokens: [String]
    )]
) -> [String] {
    var failures: [String] = []
    for contract in contracts {
        guard let content = try? captureImportIntentReadRepoFile(contract.relativePath) else {
            failures.append("missing \(contract.relativePath)")
            continue
        }
        let uncommented = captureImportIntentUncommentedSource(content, relativePath: contract.relativePath)
        guard let body = captureImportIntentDeclarationBody(in: uncommented, pattern: contract.pattern) else {
            failures.append("\(contract.relativePath) missing body for \(contract.label)")
            continue
        }
        for token in contract.requiredTokens where !body.contains(token) {
            failures.append("\(contract.relativePath) \(contract.label) missing \(token)")
        }
        for token in contract.forbiddenTokens where body.contains(token) {
            failures.append("\(contract.relativePath) \(contract.label) contains forbidden \(token)")
        }
    }
    return failures
}

private func captureImportIntentReadRepoFile(_ relativePath: String) throws -> String {
    let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return try String(contentsOf: rootURL.appendingPathComponent(relativePath), encoding: .utf8)
}

private func captureImportIntentDeclarationBody(in content: String, pattern: String) -> String? {
    guard let declarationRange = content.range(of: pattern, options: .regularExpression),
          let openBrace = content[declarationRange.upperBound...].firstIndex(of: "{")
    else {
        return nil
    }

    var depth = 0
    var index = openBrace
    while index < content.endIndex {
        let character = content[index]
        if character == "{" {
            depth += 1
        } else if character == "}" {
            depth -= 1
            if depth == 0 {
                return String(content[content.index(after: openBrace)..<index])
            }
        }
        index = content.index(after: index)
    }

    return nil
}

private func captureImportIntentUncommentedSource(_ content: String, relativePath: String) -> String {
    relativePath.hasSuffix(".swift") ? captureImportIntentUncommentedSwift(content) : content
}

private func captureImportIntentUncommentedSwift(_ content: String) -> String {
    var output = ""
    var index = content.startIndex
    var inString = false
    var escaping = false

    while index < content.endIndex {
        let character = content[index]
        let nextIndex = content.index(after: index)

        if inString {
            output.append(character)
            if escaping {
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else if character == "\"" {
                inString = false
            }
            index = nextIndex
            continue
        }

        if character == "\"" {
            inString = true
            output.append(character)
            index = nextIndex
            continue
        }

        if character == "/", nextIndex < content.endIndex {
            let nextCharacter = content[nextIndex]
            if nextCharacter == "/" {
                index = nextIndex
                while index < content.endIndex, content[index] != "\n" {
                    index = content.index(after: index)
                }
                if index < content.endIndex {
                    output.append(content[index])
                    index = content.index(after: index)
                }
                continue
            }
            if nextCharacter == "*" {
                index = content.index(after: nextIndex)
                while index < content.endIndex {
                    let maybeEnd = content[index]
                    let afterMaybeEnd = content.index(after: index)
                    if maybeEnd == "*", afterMaybeEnd < content.endIndex, content[afterMaybeEnd] == "/" {
                        index = content.index(after: afterMaybeEnd)
                        break
                    }
                    index = afterMaybeEnd
                }
                continue
            }
        }

        output.append(character)
        index = nextIndex
    }

    return output
}
