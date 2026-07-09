//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

/// A single snippet row: a white card (icon, name, overflow menu) followed by a circular run button.
struct SnippetRowView: View {
    let snippet: Snippet
    var isRunning: Bool = false
    let onRun: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            card
            runButton
        }
    }

    private var card: some View {
        HStack(spacing: 12) {
            SnippetIconTile(icon: snippet.icon, size: 40)

            Text(snippet.name)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Menu {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(String(localized: "More actions", comment: "Snippet row menu accessibility"))
        }
        .padding(.horizontal, 10)
        .frame(height: 60)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var runButton: some View {
        Button(action: onRun) {
            ZStack {
                if isRunning {
                    ProgressView()
                        .tint(Color.accentBlue)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.accentBlue)
                }
            }
            .frame(width: 40, height: 40)
            .background(Circle().fill(Color.accentBlue.opacity(0.1)))
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isRunning)
        .accessibilityLabel(String(localized: "Run snippet", comment: "Run snippet button accessibility"))
    }
}

#Preview {
    VStack(spacing: 10) {
        ForEach(Snippet.previews) { snippet in
            SnippetRowView(snippet: snippet, onRun: {}, onEdit: {}, onDelete: {})
        }
    }
    .padding(20)
    .background(Color.groupedBackground)
}
