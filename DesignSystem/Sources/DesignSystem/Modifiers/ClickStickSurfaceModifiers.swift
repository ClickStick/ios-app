//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

public struct ClickStickScreenBackgroundModifier: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .background(Color.clickStickGroupedBackground.ignoresSafeArea())
    }
}

public struct ClickStickCardModifier: ViewModifier {
    private let background: Color
    private let cornerRadius: CGFloat
    private let borderColor: Color?
    private let borderWidth: CGFloat
    private let hasShadow: Bool

    public init(
        background: Color = .clickStickCardBackground,
        cornerRadius: CGFloat = CornerRadius.card,
        borderColor: Color? = nil,
        borderWidth: CGFloat = BorderWidth.hairline,
        hasShadow: Bool = false
    ) {
        self.background = background
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.hasShadow = hasShadow
    }

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor ?? .clear, lineWidth: borderColor == nil ? 0 : borderWidth)
            )
            .shadow(
                color: hasShadow ? Elevation.cardShadowColor : .clear,
                radius: hasShadow ? Elevation.cardRadius : 0,
                y: hasShadow ? Elevation.cardYOffset : 0
            )
    }
}

public struct ClickStickSheetSurfaceModifier: ViewModifier {
    private let background: Color
    private let cornerRadius: CGFloat
    private let hasGrabberPadding: Bool

    public init(
        background: Color = .clickStickCardBackground,
        cornerRadius: CGFloat = CornerRadius.sheet,
        hasGrabberPadding: Bool = true
    ) {
        self.background = background
        self.cornerRadius = cornerRadius
        self.hasGrabberPadding = hasGrabberPadding
    }

    public func body(content: Content) -> some View {
        content
            .padding(.top, hasGrabberPadding ? Spacing.md : 0)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(background)
            )
            .shadow(
                color: Elevation.floatingShadowColor,
                radius: Elevation.floatingRadius,
                y: Elevation.floatingYOffset
            )
    }
}

public extension View {
    func clickStickScreenBackground() -> some View {
        modifier(ClickStickScreenBackgroundModifier())
    }

    func clickStickCard(
        background: Color = .clickStickCardBackground,
        cornerRadius: CGFloat = CornerRadius.card,
        borderColor: Color? = nil,
        borderWidth: CGFloat = BorderWidth.hairline,
        hasShadow: Bool = false
    ) -> some View {
        modifier(
            ClickStickCardModifier(
                background: background,
                cornerRadius: cornerRadius,
                borderColor: borderColor,
                borderWidth: borderWidth,
                hasShadow: hasShadow
            )
        )
    }

    func clickStickSheetSurface(
        background: Color = .clickStickCardBackground,
        cornerRadius: CGFloat = CornerRadius.sheet,
        hasGrabberPadding: Bool = true
    ) -> some View {
        modifier(
            ClickStickSheetSurfaceModifier(
                background: background,
                cornerRadius: cornerRadius,
                hasGrabberPadding: hasGrabberPadding
            )
        )
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        Text("Card")
            .font(.clickStickTitle)
            .frame(maxWidth: .infinity)
            .padding(Spacing.xl)
            .clickStickCard(hasShadow: true)

        VStack(spacing: Spacing.md) {
            SheetGrabber()
            Text("Sheet surface")
                .font(.clickStickTitle)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xl)
        .clickStickSheetSurface()
    }
    .padding()
    .clickStickScreenBackground()
}
