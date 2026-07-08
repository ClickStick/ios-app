//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

/// The "Sent to <device>" confirmation toast shown after content is delivered to a device.
/// Shared by text entry and snippets so both surface identical success feedback.
struct SentToastView: View {
    let deviceName: String

    var body: some View {
        Label("Sent to \(deviceName)", systemImage: "checkmark.circle")
            .font(.body.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Capsule(style: .continuous).fill(Color.black))
            .accessibilityElement(children: .combine)
    }
}
