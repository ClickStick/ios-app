//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

public struct PillChip: View {
    private let title: String
    private let systemImage: String?
    private let tint: Color
    private let isSelected: Bool

    public init(
        _ title: String,
        systemImage: String? = nil,
        tint: Color = .clickStickBlue,
        isSelected: Bool = false
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.isSelected = isSelected
    }

    public var body: some View {
        HStack(spacing: Spacing.xxs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
            }

            Text(title)
                .font(.clickStickCallout)
                .lineLimit(1)
        }
        .foregroundStyle(isSelected ? tint : Color.primary)
        .padding(.horizontal, Spacing.sm)
        .frame(minHeight: ComponentSize.compactButtonHeight)
        .background(
            Capsule(style: .continuous)
                .fill(isSelected ? tint.opacity(OpacityLevel.tintedFill) : Color.clickStickMutedFill)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(isSelected ? tint.opacity(OpacityLevel.subtleBorder) : .clear, lineWidth: BorderWidth.hairline)
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HStack(spacing: Spacing.xs) {
        PillChip("US-QWERTY", systemImage: "keyboard", isSelected: true)
        PillChip("Windows", systemImage: "desktopcomputer")
    }
    .padding()
    .background(Color.clickStickGroupedBackground)
}
