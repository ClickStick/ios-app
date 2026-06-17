//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

public struct SegmentedControlContainerModifier: ViewModifier {
    private let cornerRadius: CGFloat

    public init(cornerRadius: CGFloat = CornerRadius.control) {
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        content
            .padding(Spacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.clickStickMutedFill)
            )
    }
}

public struct SegmentedControlItemModifier: ViewModifier {
    private let isSelected: Bool
    private let tint: Color
    private let cornerRadius: CGFloat

    public init(isSelected: Bool, tint: Color, cornerRadius: CGFloat = CornerRadius.medium) {
        self.isSelected = isSelected
        self.tint = tint
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        content
            .foregroundStyle(isSelected ? tint : Color.secondary)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isSelected ? Color.clickStickCardBackground : .clear)
            )
            .shadow(
                color: isSelected ? Elevation.cardShadowColor : .clear,
                radius: isSelected ? 4 : 0,
                y: isSelected ? 1 : 0
            )
    }
}

public extension View {
    func segmentedControlContainer(cornerRadius: CGFloat = CornerRadius.control) -> some View {
        modifier(SegmentedControlContainerModifier(cornerRadius: cornerRadius))
    }

    func segmentedControlItem(
        isSelected: Bool,
        tint: Color,
        cornerRadius: CGFloat = CornerRadius.medium
    ) -> some View {
        modifier(SegmentedControlItemModifier(isSelected: isSelected, tint: tint, cornerRadius: cornerRadius))
    }
}

#Preview {
    HStack(spacing: Spacing.xxs) {
        Text("QWERTY")
            .font(.clickStickCallout)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .segmentedControlItem(isSelected: true, tint: .clickStickBlue)
        Text("QWERTZ")
            .font(.clickStickCallout)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .segmentedControlItem(isSelected: false, tint: .clickStickBlue)
    }
    .segmentedControlContainer()
    .padding()
    .background(Color.clickStickGroupedBackground)
}
