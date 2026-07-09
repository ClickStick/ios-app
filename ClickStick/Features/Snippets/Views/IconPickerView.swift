//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

/// Grid of the available snippet icons. Selecting one reports it back and pops.
struct IconPickerView: View {
    let selected: SnippetIcon
    let onSelect: (SnippetIcon) -> Void

    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(SnippetIcon.allCases) { icon in
                    Button {
                        onSelect(icon)
                        dismiss()
                    } label: {
                        VStack(spacing: 8) {
                            SnippetIconTile(icon: icon, size: 72)
                                .overlay {
                                    if icon == selected {
                                        RoundedRectangle(cornerRadius: 72 * 0.35, style: .continuous)
                                            .stroke(Color.accentBlue, lineWidth: 3)
                                    }
                                }
                            Text(icon.title)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
        .background(Color.groupedBackground.ignoresSafeArea())
        .navigationTitle("Choose icon")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .dismissBackButtonToolbar(dismiss: { dismiss() })
    }
}

#Preview {
    NavigationStack {
        IconPickerView(selected: .default, onSelect: { _ in })
    }
}
