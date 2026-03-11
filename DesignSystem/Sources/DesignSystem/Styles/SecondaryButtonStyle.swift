//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

public struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.clickStickBlue)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(Color.clickStickBlue.opacity(OpacityLevel.subtleFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(Color.clickStickBlue.opacity(OpacityLevel.subtleBorder), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(currentOpacity(isPressed: configuration.isPressed))
            .animation(.easeInOut(duration: Motion.quick), value: configuration.isPressed)
    }

    private func currentOpacity(isPressed: Bool) -> Double {
        if !isEnabled {
            return OpacityLevel.disabled
        }
        return isPressed ? OpacityLevel.pressed : 1
    }
}

public extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

#Preview {
    VStack(spacing: 16) {
        Button("Try Demo Mode") {}
            .buttonStyle(.secondary)
    }
    .padding()
}
