//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

public struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    private let tint: Color
    private let height: CGFloat
    private let cornerRadius: CGFloat

    public init(
        tint: Color = .clickStickBlue,
        height: CGFloat = ComponentSize.buttonHeight,
        cornerRadius: CGFloat = CornerRadius.pill
    ) {
        self.tint = tint
        self.height = height
        self.cornerRadius = cornerRadius
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.clickStickBodyEmphasized)
            .foregroundStyle(isEnabled ? tint : Color.secondary)
            .padding(.horizontal, Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.clickStickMutedFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(tint.opacity(isEnabled ? OpacityLevel.faintFill : 0), lineWidth: BorderWidth.hairline)
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(currentOpacity(isPressed: configuration.isPressed))
            .animation(.easeInOut(duration: Motion.quick), value: configuration.isPressed)
            .animation(.easeInOut(duration: Motion.quick), value: isEnabled)
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

    static func secondary(
        tint: Color = .clickStickBlue,
        height: CGFloat = ComponentSize.buttonHeight,
        cornerRadius: CGFloat = CornerRadius.pill
    ) -> SecondaryButtonStyle {
        SecondaryButtonStyle(tint: tint, height: height, cornerRadius: cornerRadius)
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        Button("Scan QR Code") {}
            .buttonStyle(.secondary)
        Button("Disabled") {}
            .buttonStyle(.secondary)
            .disabled(true)
    }
    .padding()
    .background(Color.clickStickGroupedBackground)
}
