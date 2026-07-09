//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

/// Horizontal row of keys/delays inserted into snippet content. Hosted as the content editor's
/// keyboard input accessory so it stays tied to the text view's editing state.
struct SnippetKeyToolbar: View {
    let onInsert: (SnippetToken) -> Void
    let onCursor: () -> Void
    let onFunctionKeys: () -> Void
    let onDelay: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                keyButton(.tab)
                keyButton(.enter)
                cursorButton
                fnButton
                delayButton
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(Color.groupedBackground)
    }

    private func keyButton(_ token: SnippetToken) -> some View {
        Button {
            onInsert(token)
        } label: {
            if let label = KeyChipLabel(token: token) {
                label
            }
        }
        .buttonStyle(.plain)
    }

    private var cursorButton: some View {
        Button {
            onCursor()
        } label: {
            KeyChipLabel(systemImage: "arrow.right", title: String(localized: "Cursor", comment: "Cursor keys chip"))
        }
        .buttonStyle(.plain)
    }

    private var fnButton: some View {
        Button {
            onFunctionKeys()
        } label: {
            KeyChipLabel(systemImage: nil, title: String(localized: "Fn", comment: "Function keys chip"))
        }
        .buttonStyle(.plain)
    }

    private var delayButton: some View {
        Button {
            onDelay()
        } label: {
            KeyChipLabel(systemImage: "timer", title: String(localized: "Delay", comment: "Delay chip"))
        }
        .buttonStyle(.plain)
    }
}
