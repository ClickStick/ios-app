//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

public struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(
                        isEnabled
                            ? LinearGradient.clickStickGradient
                            : LinearGradient(
                                colors: [.gray],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? OpacityLevel.pressed : 1.0)
            .animation(.easeInOut(duration: Motion.quick), value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

#Preview {
    VStack(spacing: 16) {
        Button("Connect") {}
            .buttonStyle(.primary)
        Button("Disabled") {}
            .buttonStyle(.primary)
            .disabled(true)
    }
    .padding()
}
