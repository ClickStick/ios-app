//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

// MARK: - Warning sheet

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
                .foregroundStyle(Color(.systemRed))
                .padding(20)
                .background(Circle().fill(Color(.systemRed).opacity(0.08)))
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

// MARK: - Progress sheet

struct TextEntryProgressSheet: View {
    let progress: TextEntryViewModel.ProgressState?
    let cancelAction: () -> Void
    let dismissAction: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            if let progress {
                switch progress {
                case .sending(let sent, let total):
                    progressContent(sent: sent, total: total)
                case .stopped(let sent, let total):
                    progressContent(sent: sent, total: total, stopped: true)
                case .sent:
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(Color(.systemGreen))
                            .accessibilityHidden(true)
                        Text("Sent!")
                            .font(.title.bold())
                    }
                    .padding(.vertical, 40)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private func progressContent(sent: Int, total: Int, stopped: Bool = false) -> some View {
        VStack(spacing: 24) {
            Text("Sending...")
                .font(.title.bold())

            ProgressView(value: total == 0 ? 0 : Double(sent) / Double(total))
                .tint(Color.accentBlue)
                .accessibilityLabel(String(localized: "Sending text", comment: "Send progress accessibility"))

            Text("\(sent) of \(total) characters")
                .font(.title3)
                .foregroundStyle(.secondary)

            if stopped {
                Text("Stopped at \(sent) of \(total). Some text may have appeared on the host device.")
                    .font(.body)
                    .foregroundStyle(Color(.systemRed))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemRed).opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(.systemRed).opacity(0.2), lineWidth: 1)
                    )
            }

            Button(stopped ? "Close" : "Cancel") {
                if stopped {
                    dismissAction()
                } else {
                    cancelAction()
                }
            }
            .buttonStyle(AppSecondaryButtonStyle())
        }
    }
}

// MARK: - Button row

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

// MARK: - Height measurement

extension View {
    func measureHeight(_ height: Binding<CGFloat>) -> some View {
        onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height.wrappedValue = $0 }
    }
}

func sheetDetents(for height: CGFloat) -> Set<PresentationDetent> {
    height > .zero ? [.height(height)] : [.medium]
}
