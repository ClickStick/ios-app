//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

public struct FeatureIcon: View {
    private let systemName: String
    private let size: CGFloat
    private let iconSize: CGFloat
    private let tint: Color
    private let cornerRadius: CGFloat

    public init(
        systemName: String,
        size: CGFloat = 112,
        iconSize: CGFloat = IconSize.hero,
        tint: Color = .clickStickBlue,
        cornerRadius: CGFloat = CornerRadius.pill
    ) {
        self.systemName = systemName
        self.size = size
        self.iconSize = iconSize
        self.tint = tint
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(tint.opacity(OpacityLevel.tintedFill))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(tint.opacity(OpacityLevel.subtleBorder), lineWidth: BorderWidth.hairline)
                )
                .frame(width: size, height: size)

            Image(systemName: systemName)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(tint)
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: Spacing.xl) {
        FeatureIcon(systemName: "cable.connector.horizontal")
        FeatureIcon(systemName: "antenna.radiowaves.left.and.right", tint: .clickStickGreen)
        FeatureIcon(systemName: "qrcode.viewfinder", tint: .clickStickOrange, cornerRadius: CornerRadius.card)
    }
    .padding()
    .background(Color.clickStickGroupedBackground)
}
