import Foundation

/// A recipe field the editor changes with `PATCH /api/v1/recipes/{id}`.
public enum NativeRecipeEditField: String, CaseIterable, Equatable, Sendable {
    case title
    case description
    case servings

    /// The field's name as the cook reads it.
    public var label: String {
        switch self {
        case .title: "Title"
        case .description: "Description"
        case .servings: "Servings"
        }
    }
}

/// A recipe's editable fields, as one version of the recipe has them. Values are trimmed, and an empty
/// description or servings is `nil`, the way the editor sends them.
public struct NativeRecipeFields: Equatable, Sendable {
    public let title: String
    public let description: String?
    public let servings: String?

    public init(title: String, description: String?, servings: String?) {
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.description = Self.trimmedOptional(description)
        self.servings = Self.trimmedOptional(servings)
    }

    public init(recipe: Recipe) {
        self.init(title: recipe.title, description: recipe.description, servings: recipe.servings)
    }

    public subscript(field: NativeRecipeEditField) -> String? {
        switch field {
        case .title: title
        case .description: description
        case .servings: servings
        }
    }

    private static func trimmedOptional(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// One field the cook changed: the value they gave it and the value they changed it from.
public struct NativeRecipeFieldChange: Equatable, Sendable {
    public let field: NativeRecipeEditField
    public let value: String?
    /// The value the edit started from, or `nil` when it is not known (an edit queued by an earlier version
    /// of the app, which did not record it).
    public let base: NativeRecipeFieldBase?

    public init(field: NativeRecipeEditField, value: String?, base: NativeRecipeFieldBase?) {
        self.field = field
        self.value = value
        self.base = base
    }
}

/// The value a field had when the edit started. A wrapper, because that value can itself be `nil`.
public struct NativeRecipeFieldBase: Equatable, Sendable {
    public let value: String?

    public init(_ value: String?) {
        self.value = value
    }
}

/// A recipe edit as the app sends it: only the fields the cook changed, and the recipe's `updatedAt` as the
/// edit read it. The server applies it only while the recipe is still that version; otherwise it answers
/// `409 edit_conflict` with the recipe as it is now.
public struct NativeRecipeEdit: Equatable, Sendable {
    public let changes: [NativeRecipeFieldChange]
    public let expectedUpdatedAt: String?

    public init(changes: [NativeRecipeFieldChange], expectedUpdatedAt: String?) {
        self.changes = changes
        self.expectedUpdatedAt = expectedUpdatedAt
    }

    /// The fields that differ between `original`, the recipe the edit started from, and `edited`.
    public init(from original: NativeRecipeFields, to edited: NativeRecipeFields, expectedUpdatedAt: String?) {
        self.init(
            changes: NativeRecipeEditField.allCases.compactMap { field in
                original[field] == edited[field]
                    ? nil
                    : NativeRecipeFieldChange(field: field, value: edited[field], base: NativeRecipeFieldBase(original[field]))
            },
            expectedUpdatedAt: expectedUpdatedAt
        )
    }

    public var isEmpty: Bool {
        changes.isEmpty
    }

    /// Compares this edit with the recipe as the server has it now, after the server turned the edit down.
    ///
    /// A field the server already has at the cook's value needs nothing. A field the server still has at the
    /// value the edit started from was changed by nobody else, so the cook's value can go on top of the
    /// current version. Any other field was changed elsewhere too: that is a conflict only the cook can settle.
    public func merged(with server: NativeRecipeServerVersion) -> NativeRecipeEditMerge {
        var unconflicted: [NativeRecipeFieldChange] = []
        var conflicts: [NativeRecipeEditConflict.Field] = []
        for change in changes {
            let current = server.fields[change.field]
            if current == change.value {
                continue
            }
            if change.base == NativeRecipeFieldBase(current) {
                unconflicted.append(NativeRecipeFieldChange(field: change.field, value: change.value, base: NativeRecipeFieldBase(current)))
            } else {
                conflicts.append(NativeRecipeEditConflict.Field(field: change.field, mine: change.value, theirs: current))
            }
        }
        if !conflicts.isEmpty {
            return .conflict(NativeRecipeEditConflict(fields: conflicts, unconflicted: unconflicted, server: server))
        }
        if unconflicted.isEmpty {
            return .alreadySaved
        }
        return .resend(NativeRecipeEdit(changes: unconflicted, expectedUpdatedAt: server.updatedAt))
    }
}

/// The recipe as the server has it now, read from a `409 edit_conflict` answer.
public struct NativeRecipeServerVersion: Equatable, Sendable {
    public let fields: NativeRecipeFields
    public let updatedAt: String

    public init(fields: NativeRecipeFields, updatedAt: String) {
        self.fields = fields
        self.updatedAt = updatedAt
    }

    /// The current recipe in `error.details.recipe`, or `nil` when `error` is not an edit conflict that
    /// carries one.
    public init?(editConflict error: APIError) {
        guard error.code == Self.editConflictCode,
              case .object(let recipe)? = error.details["recipe"],
              case .string(let title)? = recipe["title"],
              case .string(let updatedAt)? = error.details["currentUpdatedAt"] ?? recipe["updatedAt"] else {
            return nil
        }
        self.init(
            fields: NativeRecipeFields(
                title: title,
                description: Self.string(recipe["description"]),
                servings: Self.string(recipe["servings"])
            ),
            updatedAt: updatedAt
        )
    }

    /// The error code of the server's answer to an edit based on an older version of the recipe.
    public static let editConflictCode = "edit_conflict"

    private static func string(_ value: JSONValue?) -> String? {
        guard case .string(let string)? = value else {
            return nil
        }
        return string
    }
}

/// What to do with an edit the server turned down because the recipe changed after the edit read it.
public enum NativeRecipeEditMerge: Equatable, Sendable {
    /// Nobody else changed the fields this edit changes: send it again, based on the current version.
    case resend(NativeRecipeEdit)
    /// The server already has every value this edit sets.
    case alreadySaved
    /// Someone else changed a field this edit changes too.
    case conflict(NativeRecipeEditConflict)
}

/// Which version of the conflicting fields the cook keeps.
public enum NativeRecipeEditChoice: Equatable, Sendable {
    /// The cook's own edit, put on top of the current version.
    case mine
    /// The values saved elsewhere. The cook's other changes, which nobody else touched, are still sent.
    case theirs
}

/// An edit held because the recipe was changed elsewhere in a field the edit changes too. It names each
/// such field with both values, so the cook can choose, and nothing is overwritten without that choice.
public struct NativeRecipeEditConflict: Equatable, Sendable {
    public struct Field: Equatable, Sendable {
        public let field: NativeRecipeEditField
        public let mine: String?
        public let theirs: String?

        public init(field: NativeRecipeEditField, mine: String?, theirs: String?) {
            self.field = field
            self.mine = mine
            self.theirs = theirs
        }
    }

    /// The fields changed both here and elsewhere.
    public let fields: [Field]
    /// The cook's other changes, already based on the current version.
    public let unconflicted: [NativeRecipeFieldChange]
    /// The recipe as the server has it now.
    public let server: NativeRecipeServerVersion

    public init(fields: [Field], unconflicted: [NativeRecipeFieldChange], server: NativeRecipeServerVersion) {
        self.fields = fields
        self.unconflicted = unconflicted
        self.server = server
    }

    /// What the banner says above the two versions.
    public static let message = "This recipe was changed somewhere else after you started editing it. Choose which version to keep."

    /// The edit to send once the cook has chosen, based on the current version, or `nil` when there is
    /// nothing left to send.
    public func resolved(keeping choice: NativeRecipeEditChoice) -> NativeRecipeEdit? {
        let kept: [NativeRecipeFieldChange]
        switch choice {
        case .mine:
            kept = fields.map { NativeRecipeFieldChange(field: $0.field, value: $0.mine, base: NativeRecipeFieldBase($0.theirs)) }
        case .theirs:
            kept = []
        }
        let changes = NativeRecipeEditField.allCases.compactMap { field in
            (unconflicted + kept).first { $0.field == field }
        }
        guard !changes.isEmpty else {
            return nil
        }
        return NativeRecipeEdit(changes: changes, expectedUpdatedAt: server.updatedAt)
    }
}

public extension APITransportError {
    /// True when the server turned a recipe edit down because the recipe changed after the edit read it.
    var isRecipeEditConflict: Bool {
        statusCode == 409 && apiError?.code == NativeRecipeServerVersion.editConflictCode
    }
}
