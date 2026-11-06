import OuroReins
import SpoonjoyCore

extension SpoonjoyReinsShell {
    /// Imports (`CaptureDraftView`): the capture draft, or the empty queue. Importing sends the draft to an AI service
    /// after a consent sheet, which no headless journey drives yet.
    var captureNode: ReinsNode {
        let draft = content.captureDraft.map(CaptureDraftViewModel.init(draft:))
        return ReinsNode("capture", state: [
            "title": "Import queue",
            "draft": draft.map { draft in
                [
                    "id": .string(draft.draft.id),
                    "source": .string(draft.draft.source.rawValue),
                    "previewLines": .array(draft.previewLines.map(ReinsValue.string)),
                    "status": .string(draft.status.rawValue),
                    "canImport": .bool(draft.canCreateServerRecipe),
                ]
            } ?? .null,
            "x-unmodelled": "Import and Delete capture are not driven headless yet",
        ])
    }
}
