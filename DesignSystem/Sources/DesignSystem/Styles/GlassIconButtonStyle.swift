//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

public struct GlassIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    private let tint: Color
    private let size: CGFloat
    private let shape: GlassIconButtonShape

    public init(
        tint: Color = .primary,
        size: CGFloat = ComponentSize.iconButton,
        shape: GlassIconButtonShape = .circle
    ) {
        self.tint = tint
        self.size = size
        self.shape = shape
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: IconSize.inline, weight: .semibold))
            .foregroundStyle(isEnabled ? tint : Color.secondary)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: resolvedCornerRadius, style: .continuous)
                    .fill(Color.clickStickGlassFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: resolvedCornerRadius, style: .continuous)
                    .stroke(Color.clickStickSeparator.opacity(OpacityLevel.subtleBorder), lineWidth: BorderWidth.hairline)
            )
            .contentShape(RoundedRectangle(cornerRadius: resolvedCornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .opacity(currentOpacity(isPressed: configuration.isPressed))
            .animation(.easeInOut(duration: Motion.quick), value: configuration.isPressed)
            .animation(.easeInOut(duration: Motion.quick), value: isEnabled)
    }

    private var resolvedCornerRadius: CGFloat {
        switch shape {
        case .circle:
            return size / 2
        case .roundedRectangle(let cornerRadius):
            return cornerRadius
        }
    }

    private func currentOpacity(isPressed: Bool) -> Double {
        if !isEnabled {
            return OpacityLevel.disabled
        }
        return isPressed ? OpacityLevel.pressed : 1
    }
}

public enum GlassIconButtonShape {
    case circle
    case roundedRectangle(cornerRadius: CGFloat = CornerRadius.control)
}

public extension ButtonStyle where Self == GlassIconButtonStyle {
    static var glassIcon: GlassIconButtonStyle { GlassIconButtonStyle() }

    static func glassIcon(
        tint: Color = .primary,
        size: CGFloat = ComponentSize.iconButton,
        shape: GlassIconButtonShape = .circle
    ) -> GlassIconButtonStyle {
        GlassIconButtonStyle(tint: tint, size: size, shape: shape)
    }
}

#Preview {
    HStack(spacing: Spacing.md) {
        Button {} label: {
            Image(systemName: "xmark")
        }
        .buttonStyle(.glassIcon)

        Button {} label: {
            Image(systemName: "qrcode.viewfinder")
        }
        .buttonStyle(.glassIcon(tint: .clickStickBlue))

        Button {} label: {
            Image(systemName: "ellipsis")
        }
        .buttonStyle(.glassIcon(shape: .roundedRectangle()))
    }
    .padding()
    .background(Color.clickStickGroupedBackground)
}
