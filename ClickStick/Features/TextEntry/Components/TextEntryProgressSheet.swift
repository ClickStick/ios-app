//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

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
                            .foregroundStyle(Color(uiColor: .systemGreen))
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
                    .foregroundStyle(Color(uiColor: .systemRed))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(uiColor: .systemRed).opacity(0.04))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(uiColor: .systemRed).opacity(0.2), lineWidth: 1)
                    }
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
