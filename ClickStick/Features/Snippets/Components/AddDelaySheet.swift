//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

/// Sheet for choosing a delay duration to insert into a snippet.
struct AddDelaySheet: View {
    let onCancel: () -> Void
    let onAdd: (Int) -> Void

    @State private var seconds: Double = 4
    private let range: ClosedRange<Double> = 1...10

    var body: some View {
        VStack(spacing: 24) {
            Text("Add delay")
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text("\(Int(seconds))s")
                .font(.title.bold())
                .monospacedDigit()
                .accessibilityLabel(Text(String(localized: "\(Int(seconds)) seconds", comment: "Delay value accessibility")))

            HStack(spacing: 12) {
                Text("1s")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Slider(value: $seconds, in: range, step: 1)
                    .tint(.accentBlue)
                Text("10s")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            TextEntrySheetButtonRow(
                secondaryTitle: "Cancel",
                secondaryAction: onCancel,
                primaryTitle: "Add delay",
                primaryAction: { onAdd(Int(seconds)) }
            )
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    AddDelaySheet(onCancel: {}, onAdd: { _ in })
        .background(Color(uiColor: .systemBackground))
}
