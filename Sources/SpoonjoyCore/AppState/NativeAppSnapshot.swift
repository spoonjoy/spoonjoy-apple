import Foundation

public enum NativeAppSnapshotError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
}

public struct NativeAppSnapshot: Codable, Equatable {
    public let schemaVersion: Int
    public let accountID: String?
    public let environment: NativeCacheEnvironment?
    public let hasCompletedFirstRun: Bool
    public let cookProgressByRecipeID: [String: CookModeProgress]
    public let spoonCookLogDraftsByRecipeID: [String: SpoonCookLogDraftState]
    public let shoppingList: ShoppingListState?
    public let captureDraft: CaptureDraft?
    public let pendingCaptureImport: NativeQueuedMutation?
    public let captureImportProviderBlocker: String?
    public let pendingMutations: MutationQueue
    public let lastOpenedRoute: String?
    public let savedAt: String

    public init(
        schemaVersion: Int,
        accountID: String? = nil,
        environment: NativeCacheEnvironment? = nil,
        hasCompletedFirstRun: Bool,
        cookProgressByRecipeID: [String: CookModeProgress],
        spoonCookLogDraftsByRecipeID: [String: SpoonCookLogDraftState] = [:],
        shoppingList: ShoppingListState?,
        captureDraft: CaptureDraft?,
        pendingCaptureImport: NativeQueuedMutation? = nil,
        captureImportProviderBlocker: String? = nil,
        pendingMutations: MutationQueue,
        lastOpenedRoute: String?,
        savedAt: String
    ) {
        self.schemaVersion = schemaVersion
        self.accountID = accountID
        self.environment = environment
        self.hasCompletedFirstRun = hasCompletedFirstRun
        self.cookProgressByRecipeID = cookProgressByRecipeID
        self.spoonCookLogDraftsByRecipeID = spoonCookLogDraftsByRecipeID
        self.shoppingList = shoppingList
        self.captureDraft = captureDraft
        self.pendingCaptureImport = pendingCaptureImport
        self.captureImportProviderBlocker = captureImportProviderBlocker
        self.pendingMutations = pendingMutations
        self.lastOpenedRoute = lastOpenedRoute
        self.savedAt = savedAt
    }

    public static func bootstrap(
        shoppingList: ShoppingListState?,
        accountID: String? = nil,
        environment: NativeCacheEnvironment? = nil,
        savedAt: String
    ) -> NativeAppSnapshot {
        NativeAppSnapshot(
            schemaVersion: 1,
            accountID: accountID,
            environment: environment,
            hasCompletedFirstRun: false,
            cookProgressByRecipeID: [:],
            spoonCookLogDraftsByRecipeID: [:],
            shoppingList: shoppingList,
            captureDraft: nil,
            pendingCaptureImport: nil,
            captureImportProviderBlocker: nil,
            pendingMutations: MutationQueue(),
            lastOpenedRoute: nil,
            savedAt: savedAt
        )
    }

    public var pendingMutationCount: Int {
        pendingMutations.mutations.count
    }

    public var offlineState: OfflineState {
        shoppingList == nil
            ? .unavailable
            : .available(snapshotCount: max(1, pendingMutationCount), lastRestoredAt: savedAt)
    }

    public func validated() throws -> NativeAppSnapshot {
        guard schemaVersion == 1 else {
            throw NativeAppSnapshotError.unsupportedSchemaVersion(schemaVersion)
        }

        return self
    }

    public func cookProgress(for recipeID: String) -> CookModeProgress? {
        cookProgressByRecipeID[recipeID]
    }

    public func spoonCookLogDraft(for recipeID: String) -> SpoonCookLogDraftState? {
        spoonCookLogDraftsByRecipeID[recipeID]
    }

    public func isScoped(accountID: String?, environment: NativeCacheEnvironment?) -> Bool {
        self.accountID == accountID && self.environment == environment
    }

    public func completingFirstRun(savedAt: String) -> NativeAppSnapshot {
        copy(hasCompletedFirstRun: true, savedAt: savedAt)
    }

    public func updatingCookProgress(_ progress: CookModeProgress, savedAt: String) -> NativeAppSnapshot {
        var nextProgress = cookProgressByRecipeID
        nextProgress[progress.recipeID] = progress

        return copy(cookProgressByRecipeID: nextProgress, savedAt: savedAt)
    }

    public func updatingSpoonCookLogDraft(
        _ draft: SpoonCookLogDraftState?,
        forRecipeID recipeID: String,
        savedAt: String
    ) -> NativeAppSnapshot {
        let trimmedRecipeID = recipeID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRecipeID.isEmpty else {
            return copy(savedAt: savedAt)
        }

        var nextDrafts = spoonCookLogDraftsByRecipeID
        if let draft = draft?.persistable {
            nextDrafts[draft.recipeID] = draft
        } else {
            nextDrafts.removeValue(forKey: trimmedRecipeID)
        }
        return copy(spoonCookLogDraftsByRecipeID: nextDrafts, savedAt: savedAt)
    }

    public func updatingShoppingList(
        _ shoppingList: ShoppingListState,
        queuedMutation: QueuedMutation?,
        savedAt: String
    ) throws -> NativeAppSnapshot {
        let nextMutations: MutationQueue
        if let queuedMutation {
            nextMutations = try pendingMutations.appending(queuedMutation)
        } else {
            nextMutations = pendingMutations
        }

        return copy(
            shoppingList: shoppingList,
            pendingMutations: nextMutations,
            savedAt: savedAt
        )
    }

    public func updatingCaptureDraft(_ captureDraft: CaptureDraft, savedAt: String) -> NativeAppSnapshot {
        recordingCaptureDraft(captureDraft, savedAt: savedAt)
    }

    public func recordingCaptureDraft(_ captureDraft: CaptureDraft, savedAt: String) -> NativeAppSnapshot {
        let draftImportSource = try? captureDraft.importSource()
        let pendingImportMatchesDraft = draftImportSource.map { pendingCaptureImport?.recipeImportSource == $0 } ?? false
        let shouldClearPendingImport = pendingCaptureImport != nil && !pendingImportMatchesDraft
        let shouldClearProviderBlocker = captureImportProviderBlocker != nil && self.captureDraft != captureDraft

        return copy(
            captureDraft: captureDraft,
            pendingCaptureImport: shouldClearPendingImport ? .some(nil) : nil,
            captureImportProviderBlocker: (shouldClearPendingImport || shouldClearProviderBlocker) ? .some(nil) : nil,
            savedAt: savedAt
        )
    }

    public func discardingCaptureDraft(id: String, savedAt: String) -> NativeAppSnapshot {
        guard captureDraft?.id == id else {
            return copy(savedAt: savedAt)
        }
        return copy(
            captureDraft: .some(nil),
            pendingCaptureImport: .some(nil),
            captureImportProviderBlocker: .some(nil),
            savedAt: savedAt
        )
    }

    public func recordingCaptureImportRetry(_ mutation: NativeQueuedMutation, savedAt: String) -> NativeAppSnapshot {
        copy(pendingCaptureImport: mutation, captureImportProviderBlocker: .some(nil), savedAt: savedAt)
    }

    public func recordingCaptureImportProviderBlocker(resourceID: String, savedAt: String) -> NativeAppSnapshot {
        let trimmed = resourceID.trimmingCharacters(in: .whitespacesAndNewlines)
        return copy(
            pendingCaptureImport: .some(nil),
            captureImportProviderBlocker: trimmed.isEmpty ? "recipe-import" : trimmed,
            savedAt: savedAt
        )
    }

    public func clearingDrainedCaptureImport(clientMutationIDs: Set<String>, savedAt: String) -> NativeAppSnapshot {
        guard let pendingCaptureImport,
              clientMutationIDs.contains(pendingCaptureImport.clientMutationID) else {
            return copy(savedAt: savedAt)
        }
        return copy(
            captureDraft: .some(nil),
            pendingCaptureImport: .some(nil),
            captureImportProviderBlocker: .some(nil),
            savedAt: savedAt
        )
    }

    public func recordingOpenedRoute(_ route: AppRoute, savedAt: String) -> NativeAppSnapshot {
        copy(lastOpenedRoute: route.stateIdentifier, savedAt: savedAt)
    }

    public func copyForCacheMigration(pendingMutations: MutationQueue) -> NativeAppSnapshot {
        copy(pendingMutations: pendingMutations, savedAt: savedAt)
    }

    private func copy(
        hasCompletedFirstRun: Bool? = nil,
        cookProgressByRecipeID: [String: CookModeProgress]? = nil,
        spoonCookLogDraftsByRecipeID: [String: SpoonCookLogDraftState]? = nil,
        shoppingList: ShoppingListState?? = nil,
        captureDraft: CaptureDraft?? = nil,
        pendingCaptureImport: NativeQueuedMutation?? = nil,
        captureImportProviderBlocker: String?? = nil,
        pendingMutations: MutationQueue? = nil,
        lastOpenedRoute: String?? = nil,
        savedAt: String
    ) -> NativeAppSnapshot {
        NativeAppSnapshot(
            schemaVersion: schemaVersion,
            accountID: accountID,
            environment: environment,
            hasCompletedFirstRun: hasCompletedFirstRun ?? self.hasCompletedFirstRun,
            cookProgressByRecipeID: cookProgressByRecipeID ?? self.cookProgressByRecipeID,
            spoonCookLogDraftsByRecipeID: spoonCookLogDraftsByRecipeID ?? self.spoonCookLogDraftsByRecipeID,
            shoppingList: shoppingList ?? self.shoppingList,
            captureDraft: captureDraft ?? self.captureDraft,
            pendingCaptureImport: pendingCaptureImport ?? self.pendingCaptureImport,
            captureImportProviderBlocker: captureImportProviderBlocker ?? self.captureImportProviderBlocker,
            pendingMutations: pendingMutations ?? self.pendingMutations,
            lastOpenedRoute: lastOpenedRoute ?? self.lastOpenedRoute,
            savedAt: savedAt
        )
    }
}

extension NativeAppSnapshot {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case accountID
        case environment
        case hasCompletedFirstRun
        case cookProgressByRecipeID
        case spoonCookLogDraftsByRecipeID
        case shoppingList
        case captureDraft
        case pendingCaptureImport
        case captureImportProviderBlocker
        case pendingMutations
        case lastOpenedRoute
        case savedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schemaVersion: try container.decode(Int.self, forKey: .schemaVersion),
            accountID: try container.decodeIfPresent(String.self, forKey: .accountID),
            environment: try container.decodeIfPresent(NativeCacheEnvironment.self, forKey: .environment),
            hasCompletedFirstRun: try container.decode(Bool.self, forKey: .hasCompletedFirstRun),
            cookProgressByRecipeID: try container.decode([String: CookModeProgress].self, forKey: .cookProgressByRecipeID),
            spoonCookLogDraftsByRecipeID: try container.decodeIfPresent([String: SpoonCookLogDraftState].self, forKey: .spoonCookLogDraftsByRecipeID) ?? [:],
            shoppingList: try container.decodeIfPresent(ShoppingListState.self, forKey: .shoppingList),
            captureDraft: try container.decodeIfPresent(CaptureDraft.self, forKey: .captureDraft),
            pendingCaptureImport: try container.decodeIfPresent(NativeQueuedMutation.self, forKey: .pendingCaptureImport),
            captureImportProviderBlocker: try container.decodeIfPresent(String.self, forKey: .captureImportProviderBlocker),
            pendingMutations: try container.decode(MutationQueue.self, forKey: .pendingMutations),
            lastOpenedRoute: try container.decodeIfPresent(String.self, forKey: .lastOpenedRoute),
            savedAt: try container.decode(String.self, forKey: .savedAt)
        )
    }
}

public enum NativeAppStateLocation {
    public static let appDirectoryName = "Spoonjoy"
    public static let fileName = "native-app-state.json"

    public static func defaultFileURL(
        applicationSupportURLs: [URL]? = nil,
        fileManager: FileManager = .default,
        temporaryDirectory: URL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    ) -> URL {
        let baseURL = (applicationSupportURLs ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)).first ??
            temporaryDirectory
        let directoryURL = baseURL.appendingPathComponent(appDirectoryName, isDirectory: true)
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL.appendingPathComponent(fileName)
    }
}

public struct NativeAppStateStore {
    private let store: JSONFileStore<NativeAppSnapshot>

    public init(fileURL: URL) {
        store = JSONFileStore<NativeAppSnapshot>(fileURL: fileURL)
    }

    public func loadOrCreate(fallback: NativeAppSnapshot) throws -> JSONFileStoreRecord<NativeAppSnapshot> {
        if let record = try store.load() {
            return JSONFileStoreRecord(value: try record.value.validated(), source: record.source)
        }

        return JSONFileStoreRecord(value: fallback, source: .fallback)
    }

    public func save(_ snapshot: NativeAppSnapshot) throws {
        try store.save(try snapshot.validated())
    }
}
