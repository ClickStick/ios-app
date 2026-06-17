//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

// App-local primary button: full-width blue pill. Applied directly as
// `.buttonStyle(AppPrimaryButtonStyle())` to avoid clashing with the
// DesignSystem `.primary` accessor still used by non-redesigned screens.
struct AppPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    var fill: Color = .accentBlue

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(isEnabled ? Color.white : Color.white.opacity(0.5))
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(isEnabled ? fill : Color(.systemGray3))
            )
            .contentShape(RoundedRectangle(cornerRadius: 999, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.1), value: isEnabled)
    }
}
