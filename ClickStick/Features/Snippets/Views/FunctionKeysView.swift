//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

/// Grid of function keys F1–F12. Selecting one inserts it into the snippet and pops.
struct FunctionKeysView: View {
    let onSelect: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)

    var body: some View {
        VStack(spacing: 20) {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(1...12, id: \.self) { number in
                    Button {
                        onSelect(number)
                        dismiss()
                    } label: {
                        Text("F\(number)")
                            .font(.title3)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.cardBackground)
                                    .shadow(color: Color.black.opacity(0.06), radius: 6, y: 3)
                            )
                    }
                    .buttonStyle(.plain)
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
        .navigationTitle("Function keys")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .dismissBackButtonToolbar(dismiss: { dismiss() })
    }
}

#Preview {
    NavigationStack {
        FunctionKeysView(onSelect: { _ in })
    }
}
