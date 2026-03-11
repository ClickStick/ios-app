//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

public struct FeatureIcon: View {
    let systemName: String
    var size: CGFloat = 120
    var iconSize: CGFloat = 48

    public init(systemName: String, size: CGFloat = 120, iconSize: CGFloat = 48) {
        self.systemName = systemName
        self.size = size
        self.iconSize = iconSize
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.clickStickBlue.opacity(OpacityLevel.accentFill), Color.clickStickTeal.opacity(OpacityLevel.subtleFill)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(LinearGradient.clickStickGradient)
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 24) {
        FeatureIcon(systemName: "cable.connector.horizontal")
        FeatureIcon(systemName: "book")
        FeatureIcon(systemName: "camera.fill")
    }
}
