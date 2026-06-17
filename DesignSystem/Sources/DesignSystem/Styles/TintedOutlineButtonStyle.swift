//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

public struct TintedOutlineButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    private let color: Color
    private let cornerRadius: CGFloat
    private let minHeight: CGFloat?

    public init(
        color: Color,
        cornerRadius: CGFloat = CornerRadius.control,
        minHeight: CGFloat? = nil
    ) {
        self.color = color
        self.cornerRadius = cornerRadius
        self.minHeight = minHeight
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.clickStickBodyEmphasized)
            .foregroundStyle(isEnabled ? color : Color.secondary)
            .frame(minHeight: minHeight)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(color.opacity(OpacityLevel.tintedFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(color.opacity(OpacityLevel.subtleBorder), lineWidth: BorderWidth.thin)
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

public extension ButtonStyle where Self == TintedOutlineButtonStyle {
    static func tintedOutline(
        color: Color,
        cornerRadius: CGFloat = CornerRadius.control,
        minHeight: CGFloat? = nil
    ) -> TintedOutlineButtonStyle {
        TintedOutlineButtonStyle(color: color, cornerRadius: cornerRadius, minHeight: minHeight)
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        Button("Left Click") {}
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .buttonStyle(.tintedOutline(color: .clickStickBlue))
        Button("Right Click") {}
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .buttonStyle(.tintedOutline(color: .clickStickTeal))
        Button("Disabled") {}
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .buttonStyle(.tintedOutline(color: .clickStickBlue))
            .disabled(true)
    }
    .padding()
}
