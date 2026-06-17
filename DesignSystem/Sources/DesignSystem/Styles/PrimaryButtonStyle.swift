//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

public struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    private let height: CGFloat
    private let cornerRadius: CGFloat

    public init(
        height: CGFloat = ComponentSize.buttonHeight,
        cornerRadius: CGFloat = CornerRadius.pill
    ) {
        self.height = height
        self.cornerRadius = cornerRadius
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.clickStickBodyEmphasized)
            .foregroundStyle(isEnabled ? Color.white : Color.white.opacity(OpacityLevel.disabled))
            .padding(.horizontal, Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(background(isPressed: configuration.isPressed))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? OpacityLevel.pressed : 1.0)
            .animation(.easeInOut(duration: Motion.quick), value: configuration.isPressed)
            .animation(.easeInOut(duration: Motion.quick), value: isEnabled)
    }

    private func background(isPressed: Bool) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(isEnabled ? Color.clickStickBlue : Color(.systemGray3))
    }
}

public extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }

    static func primary(
        height: CGFloat = ComponentSize.buttonHeight,
        cornerRadius: CGFloat = CornerRadius.pill
    ) -> PrimaryButtonStyle {
        PrimaryButtonStyle(height: height, cornerRadius: cornerRadius)
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        Button("Connect") {}
            .buttonStyle(.primary)
        Button("Disabled") {}
            .buttonStyle(.primary)
            .disabled(true)
    }
    .padding()
    .background(Color.clickStickGroupedBackground)
}
