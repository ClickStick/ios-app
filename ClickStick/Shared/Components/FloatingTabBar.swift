//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI
import UIKit

struct FloatingTabBarItem<ID: Hashable>: Identifiable {
    let id: ID
    let title: LocalizedStringKey
    let systemImage: String

    init(id: ID, title: LocalizedStringKey, systemImage: String) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
    }
}

struct FloatingTabBar<ID: Hashable>: View {
    @Environment(\.colorScheme) private var colorScheme

    private let items: [FloatingTabBarItem<ID>]
    @Binding private var selection: ID

    init(items: [FloatingTabBarItem<ID>], selection: Binding<ID>) {
        self.items = items
        self._selection = selection
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                FloatingTabBarButton(
                    item: item,
                    isSelected: selection == item.id,
                    selectedFill: selectedFill,
                    action: {
                        if selection != item.id {
                            dismissKeyboard()
                        }
                        selection = item.id
                    }
                )
            }
        }
        .padding(2)
        .frame(height: 52)
        .background(
            Capsule(style: .continuous)
                .fill(barFill)
        )
        .overlay {
            Capsule(style: .continuous)
                .stroke(barStroke, lineWidth: 0.5)
        }
        .shadow(color: shadowColor, radius: 16, y: 6)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private var barFill: Color {
        colorScheme == .dark
            ? Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)
            : Color(red: 240 / 255, green: 239 / 255, blue: 244 / 255)
    }

    private var selectedFill: Color {
        colorScheme == .dark
            ? Color(red: 44 / 255, green: 44 / 255, blue: 46 / 255)
            : Color(red: 223 / 255, green: 222 / 255, blue: 227 / 255)
    }

    private var barStroke: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.32)
            : Color.white.opacity(0.75)
    }

    private var shadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.35)
            : Color.black.opacity(0.05)
    }
}

// MARK: - Tab Button

private struct FloatingTabBarButton<ID: Hashable>: View {
    let item: FloatingTabBarItem<ID>
    let isSelected: Bool
    let selectedFill: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                    .frame(height: 25)
                    .accessibilityHidden(true)

                Text(item.title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? Color.accentBlue : Color.primary)
            .frame(width: 80, height: 44)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? selectedFill : .clear)
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(item.title))
        .accessibilityValue(isSelected ? Text(String(localized: "Selected", comment: "Selected tab accessibility value")) : Text(""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    FloatingTabBar(
        items: [
            FloatingTabBarItem(id: "text", title: "Text Entry", systemImage: "character.cursor.ibeam"),
            FloatingTabBarItem(id: "snippets", title: "Snippets", systemImage: "list.bullet"),
            FloatingTabBarItem(id: "touchpad", title: "Touchpad", systemImage: "rectangle.and.hand.point.up.left")
        ],
        selection: .constant("text")
    )
    .padding()
    .background(Color.groupedBackground)
}
