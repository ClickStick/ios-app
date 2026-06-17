//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

public struct FloatingTabBarItem<ID: Hashable>: Identifiable {
    public let id: ID
    public let title: String
    public let systemImage: String
    public let badge: String?

    public init(id: ID, title: String, systemImage: String, badge: String? = nil) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.badge = badge
    }
}

public struct FloatingTabBar<ID: Hashable>: View {
    private let items: [FloatingTabBarItem<ID>]
    @Binding private var selection: ID

    public init(items: [FloatingTabBarItem<ID>], selection: Binding<ID>) {
        self.items = items
        self._selection = selection
    }

    public var body: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach(items) { item in
                tabButton(for: item)
            }
        }
        .padding(Spacing.xs)
        .frame(minHeight: ComponentSize.tabBarHeight)
        .background(
            Capsule(style: .continuous)
                .fill(Color.clickStickGlassFill)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.clickStickSeparator.opacity(OpacityLevel.subtleBorder), lineWidth: BorderWidth.hairline)
        )
        .shadow(color: Elevation.floatingShadowColor, radius: Elevation.floatingRadius, y: Elevation.floatingYOffset)
    }

    private func tabButton(for item: FloatingTabBarItem<ID>) -> some View {
        let isSelected = selection == item.id

        return Button {
            selection = item.id
        } label: {
            VStack(spacing: Spacing.xxs) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: item.systemImage)
                        .font(.system(size: IconSize.tab, weight: isSelected ? .semibold : .regular))
                        .frame(height: IconSize.medium)

                    if let badge = item.badge {
                        Text(badge)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.xxs)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Capsule().fill(Color.clickStickDestructive))
                            .offset(x: Spacing.sm, y: -Spacing.xxs)
                    }
                }

                Text(item.title)
                    .font(.clickStickTabLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? Color.clickStickBlue : Color.secondary)
            .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumHitTarget)
            .padding(.horizontal, Spacing.xs)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? Color.clickStickBlue.opacity(OpacityLevel.tintedFill) : .clear)
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue(isSelected ? Text("Selected") : Text(""))
    }
}

#Preview {
    FloatingTabBar(
        items: [
            FloatingTabBarItem(id: "text", title: "Text Entry", systemImage: "keyboard"),
            FloatingTabBarItem(id: "snippets", title: "Snippets", systemImage: "square.text.square"),
            FloatingTabBarItem(id: "touchpad", title: "Touchpad", systemImage: "trackpad")
        ],
        selection: .constant("text")
    )
    .padding()
    .background(Color.clickStickGroupedBackground)
}
