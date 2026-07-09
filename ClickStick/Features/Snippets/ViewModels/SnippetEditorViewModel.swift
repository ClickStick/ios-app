//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import Foundation
import Observation

/// Draft state for creating or editing a single snippet.
///
/// Content is an ordered list of `tokens` (text runs and special keys). The content editor edits
/// this list directly via a `UITextView`, so typing "admin", inserting Tab, then typing more yields
/// `[.text("admin"), .tab, .text(...)]`.
@Observable
@MainActor
final class SnippetEditorViewModel {
    var name: String
    var icon: SnippetIcon
    var tokens: [SnippetToken]

    private let existingSnippet: Snippet?
    var isEditing: Bool { existingSnippet != nil }

    init(snippet: Snippet?) {
        existingSnippet = snippet
        name = snippet?.name ?? ""
        icon = snippet?.icon ?? .default
        tokens = snippet?.tokens ?? []
    }

    var hasContent: Bool { !tokens.isEmpty }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hasContent
    }

    func build() -> Snippet {
        Snippet(
            id: existingSnippet?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            icon: icon,
            tokens: tokens,
            createdAt: existingSnippet?.createdAt ?? Date()
        )
    }
}
