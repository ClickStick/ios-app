//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

public struct SegmentedControlContainerModifier: ViewModifier {
    private let cornerRadius: CGFloat

    public init(cornerRadius: CGFloat = CornerRadius.medium) {
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        content
            .padding(Spacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.secondary.opacity(OpacityLevel.subtleFill))
            )
    }
}

public struct SegmentedControlItemModifier: ViewModifier {
    private let isSelected: Bool
    private let tint: Color
    private let cornerRadius: CGFloat

    public init(isSelected: Bool, tint: Color, cornerRadius: CGFloat = CornerRadius.small) {
        self.isSelected = isSelected
        self.tint = tint
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isSelected ? tint : .clear)
            )
    }
}

public extension View {
    func segmentedControlContainer(cornerRadius: CGFloat = CornerRadius.medium) -> some View {
        modifier(SegmentedControlContainerModifier(cornerRadius: cornerRadius))
    }

    func segmentedControlItem(
        isSelected: Bool,
        tint: Color,
        cornerRadius: CGFloat = CornerRadius.small
    ) -> some View {
        modifier(SegmentedControlItemModifier(isSelected: isSelected, tint: tint, cornerRadius: cornerRadius))
    }
}

#Preview {
    HStack(spacing: 4) {
        Text("QWERTY")
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .segmentedControlItem(isSelected: true, tint: .clickStickTeal)
        Text("QWERTZ")
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .segmentedControlItem(isSelected: false, tint: .clickStickTeal)
    }
    .segmentedControlContainer()
    .padding()
}
