//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

public struct TintedOutlineButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    private let color: Color
    private let cornerRadius: CGFloat

    public init(color: Color, cornerRadius: CGFloat = CornerRadius.medium) {
        self.color = color
        self.cornerRadius = cornerRadius
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(color)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(color.opacity(OpacityLevel.subtleFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(color.opacity(OpacityLevel.subtleBorder), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
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

public extension ButtonStyle where Self == TintedOutlineButtonStyle {
    static func tintedOutline(
        color: Color,
        cornerRadius: CGFloat = CornerRadius.medium
    ) -> TintedOutlineButtonStyle {
        TintedOutlineButtonStyle(color: color, cornerRadius: cornerRadius)
    }
}

#Preview {
    VStack(spacing: 16) {
        Button("Left Click") {}
            .buttonStyle(.tintedOutline(color: .clickStickBlue))
        Button("Right Click") {}
            .buttonStyle(.tintedOutline(color: .clickStickTeal))
        Button("Disabled") {}
            .buttonStyle(.tintedOutline(color: .clickStickBlue))
            .disabled(true)
    }
    .padding()
}
