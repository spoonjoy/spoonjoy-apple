public struct RecipeEditorToolbarSession: Equatable, Sendable {
    public private(set) var routeIdentifier: String?
    public private(set) var canSave = false
    public private(set) var isSaving = false

    public init() {}

    public mutating func configure(routeIdentifier: String, canSave: Bool, isSaving: Bool) {
        self.routeIdentifier = routeIdentifier
        self.canSave = canSave
        self.isSaving = isSaving
    }

    public func canPerformSave(for routeIdentifier: String) -> Bool {
        self.routeIdentifier == routeIdentifier && canSave && !isSaving
    }

    public mutating func reset(ifMatching routeIdentifier: String) {
        guard self.routeIdentifier == routeIdentifier else { return }
        self = Self()
    }
}
