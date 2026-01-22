//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import SwiftUI

struct KeyboardLayoutPicker: View {
    @Binding var selection: CSKeyboardLayout

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keyboard Layout")
                .font(.headline)

            Picker("Keyboard Layout", selection: $selection) {
                ForEach(CSKeyboardLayout.allCases, id: \.self) { layout in
                    Text(layout.description)
                        .tag(layout)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Select keyboard layout")
        }
    }
}

// MARK: - Layout Detection Extension

extension CSKeyboardLayout {
    /// Attempts to detect the appropriate keyboard layout from the system locale
    static func fromSystemLocale() -> CSKeyboardLayout {
        guard let languageCode = Locale.current.language.languageCode?.identifier else {
            return .usQWERTY
        }

        switch languageCode {
        case "de":
            return .deQWERTZ
        case "fr":
            return .frAZERTY_Classic
        default:
            return .usQWERTY
        }
    }
}

#Preview {
    KeyboardLayoutPicker(selection: .constant(.usQWERTY))
        .padding()
}
