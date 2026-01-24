//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

struct BrandedIcon: View {
    let systemName: String
    var size: CGFloat = 120
    var iconSize: CGFloat = 48

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.clickStickBlue.opacity(0.15), Color.clickStickTeal.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(LinearGradient.brandGradient)
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        BrandedIcon(systemName: "cable.connector.horizontal")
        BrandedIcon(systemName: "book")
        BrandedIcon(systemName: "camera.fill")
    }
}
