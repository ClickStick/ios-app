//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

/// Grid of cursor-movement keys (arrows, Home, End). Selecting one inserts it and pops.
struct CursorKeysView: View {
    let onSelect: (CursorKey) -> Void

    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)

    var body: some View {
        VStack(spacing: 20) {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(CursorKey.allCases) { key in
                    Button {
                        onSelect(key)
                        dismiss()
                    } label: {
                        keyLabel(key)
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.cardBackground)
                                    .shadow(color: Color.black.opacity(0.06), radius: 6, y: 3)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(key.title))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            Text("Tap a key to insert it into your snippet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.groupedBackground.ignoresSafeArea())
        .navigationTitle("Cursor")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .dismissBackButtonToolbar(dismiss: { dismiss() })
    }

    @ViewBuilder
    private func keyLabel(_ key: CursorKey) -> some View {
        if let systemImage = key.systemImage {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
        } else {
            Text(key.title.uppercased())
                .font(.title3)
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    NavigationStack {
        CursorKeysView(onSelect: { _ in })
    }
}
