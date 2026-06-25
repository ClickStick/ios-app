//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

struct TextEntryWarningSheet: View {
    let title: LocalizedStringKey
    let message: String
    let secondaryTitle: LocalizedStringKey
    let secondaryAction: () -> Void
    let primaryTitle: LocalizedStringKey
    let primaryAction: () -> Void
    var primaryIsDisabled = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.circle")
                .font(.largeTitle)
                .foregroundStyle(Color(uiColor: .systemRed))
                .padding(20)
                .background(Circle().fill(Color(uiColor: .systemRed).opacity(0.08)))
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextEntrySheetButtonRow(
                secondaryTitle: secondaryTitle,
                secondaryAction: secondaryAction,
                primaryTitle: primaryTitle,
                primaryAction: primaryAction,
                primaryIsDisabled: primaryIsDisabled
            )
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

struct TextEntrySheetButtonRow: View {
    let secondaryTitle: LocalizedStringKey
    let secondaryAction: () -> Void
    let primaryTitle: LocalizedStringKey
    let primaryAction: () -> Void
    var primaryIsDisabled = false

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                Button(secondaryTitle, action: secondaryAction)
                    .buttonStyle(AppSecondaryButtonStyle())

                Button(primaryTitle, action: primaryAction)
                    .buttonStyle(AppPrimaryButtonStyle())
                    .disabled(primaryIsDisabled)
            }

            VStack(spacing: 12) {
                Button(primaryTitle, action: primaryAction)
                    .buttonStyle(AppPrimaryButtonStyle())
                    .disabled(primaryIsDisabled)

                Button(secondaryTitle, action: secondaryAction)
                    .buttonStyle(AppSecondaryButtonStyle())
            }
        }
    }
}
