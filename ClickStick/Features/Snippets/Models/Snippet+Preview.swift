//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import Foundation

#if DEBUG
extension Snippet {
    /// Sample snippets mirroring the Figma "Snippets" list, for previews.
    static var previews: [Snippet] {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let entries: [(String, SnippetIcon)] = [
            ("Work Server SSH", .default),
            ("Database Admin", .password),
            ("Router Admin Panel", .network),
            ("Windows Domain Login", .login),
            ("Backup Server", .server),
            ("Dev Environment", .scripts),
            ("Staging Server", .server),
            ("Production Deploy", .work)
        ]
        return entries.enumerated().map { index, entry in
            Snippet(
                name: entry.0,
                icon: entry.1,
                tokens: [.text("admin@company.local"), .tab, .text("P@ssw0rd!2026"), .enter],
                createdAt: base.addingTimeInterval(TimeInterval(index))
            )
        }
    }

    /// A single filled snippet matching the "New snippet" edit example.
    static var previewFilled: Snippet {
        Snippet(
            name: "Router Admin Panel",
            icon: .network,
            tokens: [.text("admin@company.local"), .tab, .text("P@ssw0rd!2026"), .enter]
        )
    }
}
#endif
