//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import DesignSystem
import SwiftUI

struct KeyboardLayoutPicker: View {
    @Binding var selection: CSKeyboardLayout

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "globe")
                    .foregroundStyle(Color.clickStickTeal)
                Text("Keyboard Layout")
                    .font(.headline)
            }
            .accessibilityAddTraits(.isHeader)

            // Custom styled picker
            HStack(spacing: Spacing.xxs) {
                ForEach(CSKeyboardLayout.allCases, id: \.self) { layout in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selection = layout
                        }
                    } label: {
                        Text(layout.description)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(selection == layout ? .white : .primary)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .frame(maxWidth: .infinity)
                            .segmentedControlItem(isSelected: selection == layout, tint: .clickStickTeal)
                    }
                    .buttonStyle(.plain)
                }
            }
            .segmentedControlContainer()
            .accessibilityLabel("Select keyboard layout")
            .accessibilityHint("Choose the keyboard layout of the target computer")
            .accessibilityValue(selection.description)

            Text("Select the keyboard layout of the target computer")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}


#Preview {
    KeyboardLayoutPicker(selection: .constant(.usQWERTY))
        .padding()
}
