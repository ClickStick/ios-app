//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

/// A pill-shaped chip showing an optional icon and a label. Used both for the key-insertion
/// toolbar buttons (Tab, Enter, …) and for the inline key chips inside the content editor.
struct KeyChipLabel: View {
    let systemImage: String?
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.footnote.weight(.semibold))
            }
            Text(title)
                .font(.subheadline.weight(.medium))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Capsule(style: .continuous).fill(Color.cardBackground))
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }
}

extension KeyChipLabel {
    /// Builds a chip label for a key token (text tokens have no chip).
    init?(token: SnippetToken) {
        guard let title = token.chipTitle else { return nil }
        self.init(systemImage: token.chipSystemImage, title: title)
    }
}

#Preview {
    HStack {
        KeyChipLabel(systemImage: "arrow.right.to.line", title: "Tab")
        KeyChipLabel(systemImage: "arrow.turn.down.left", title: "Enter")
        KeyChipLabel(systemImage: nil, title: "F5")
    }
    .padding()
    .background(Color.groupedBackground)
}
