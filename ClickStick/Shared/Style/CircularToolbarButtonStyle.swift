//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

struct CircularToolbarButtonStyle: ButtonStyle {
    enum Role {
        case prominent // filled accent-blue circle, white icon (Add / Send)
        case neutral   // light circle, primary icon (Settings)
    }

    @Environment(\.isEnabled) private var isEnabled
    var role: Role = .prominent
    var diameter: CGFloat = 36

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(fill))
            .contentShape(Circle())
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeInOut(duration: 0.15), value: isEnabled)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }

    private var fill: Color {
        switch role {
        case .prominent: isEnabled ? .accentBlue : .accentBlue.opacity(0.4)
        case .neutral: .cardBackground
        }
    }

    private var foreground: Color {
        switch role {
        case .prominent: .white
        case .neutral: isEnabled ? .primary : .secondary
        }
    }
}

extension ToolbarContent {
    @ToolbarContentBuilder
    func appHiddenSharedToolbarBackground() -> some ToolbarContent {
        if #available(iOS 26.0, macCatalyst 26.0, *) {
            self.sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}

extension View {
    /// A leading circular chevron button that calls `dismiss`. Used by pushed detail screens
    /// (e.g. the snippet editor's key pickers) that hide the default back button.
    func dismissBackButtonToolbar(dismiss: @escaping () -> Void) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(CircularToolbarButtonStyle(role: .neutral))
                .accessibilityLabel(String(localized: "Back", comment: "Back button accessibility"))
            }
            .appHiddenSharedToolbarBackground()
        }
    }
}
