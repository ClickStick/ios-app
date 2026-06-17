//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

public struct ClickStickCard<Content: View>: View {
    private let background: Color
    private let cornerRadius: CGFloat
    private let borderColor: Color?
    private let borderWidth: CGFloat
    private let hasShadow: Bool
    private let content: Content

    public init(
        background: Color = .clickStickCardBackground,
        cornerRadius: CGFloat = CornerRadius.card,
        borderColor: Color? = nil,
        borderWidth: CGFloat = BorderWidth.hairline,
        hasShadow: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.background = background
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.hasShadow = hasShadow
        self.content = content()
    }

    public var body: some View {
        content
            .clickStickCard(
                background: background,
                cornerRadius: cornerRadius,
                borderColor: borderColor,
                borderWidth: borderWidth,
                hasShadow: hasShadow
            )
    }
}

#Preview {
    ClickStickCard(hasShadow: true) {
        VStack(spacing: Spacing.sm) {
            Text("ClickStick 9F8C")
                .font(.clickStickTitle)
            Text("Ready to type")
                .font(.clickStickCallout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xl)
    }
    .padding()
    .background(Color.clickStickGroupedBackground)
}
