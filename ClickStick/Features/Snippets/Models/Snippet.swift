//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import Foundation

/// A reusable snippet: a named, icon-tagged sequence of text and special-key tokens that can be
/// typed to any connected device. Shared across all devices, persisted in the app-sandboxed
/// snippets database.
struct Snippet: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var icon: SnippetIcon
    var tokens: [SnippetToken]
    /// Creation timestamp, used to keep append order for the list.
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        icon: SnippetIcon = .default,
        tokens: [SnippetToken] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.tokens = tokens
        self.createdAt = createdAt
    }

    /// Plain-text preview of the content, with key tokens shown as bracketed labels.
    var contentSummary: String {
        tokens.map { token in
            if case .text(let value) = token { return value }
            return "[\(token.chipTitle ?? "")]"
        }.joined()
    }
}
