//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

/// A 4-column grid of selectable keys used by the snippet editor. Selecting a key invokes
/// `onSelect` and pops. Callers supply the items, navigation title, and per-key label.
struct KeyGridView<Item: Hashable, Label: View>: View {
    let items: [Item]
    let title: LocalizedStringKey
    let onSelect: (Item) -> Void
    @ViewBuilder let label: (Item) -> Label

    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)

    var body: some View {
        VStack(spacing: 20) {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items, id: \.self) { item in
                    Button {
                        onSelect(item)
                        dismiss()
                    } label: {
                        label(item)
                    }
                    .buttonStyle(
                        RaisedKeyButtonStyle(
                            height: 58,
                            cornerRadius: 14,
                            horizontalPadding: 8,
                            font: .system(size: 20, weight: .regular)
                        )
                    )
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
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .dismissBackButtonToolbar(dismiss: { dismiss() })
    }
}
