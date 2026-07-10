//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

struct CircularToolbarButtonStyle: ButtonStyle {
    enum Role {
        case prominent // filled accent-blue circle, white icon (Add / Send)
        case neutral   // light circle, primary icon (Settings)
    }

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    var role: Role = .prominent
    var diameter: CGFloat = 36

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: diameter, height: diameter)
            .background(buttonBackground)
            .overlay { buttonBorder }
            .contentShape(Circle())
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeInOut(duration: 0.15), value: isEnabled)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }

    @ViewBuilder
    private var buttonBackground: some View {
        switch role {
        case .prominent:
            Circle().fill(isEnabled ? Color.accentBlue : Color.accentBlue.opacity(0.4))
        case .neutral:
            Circle()
                .fill(neutralFill)
                .shadow(color: neutralShadowColor, radius: colorScheme == .dark ? 10 : 16, y: colorScheme == .dark ? 6 : 8)
        }
    }

    @ViewBuilder
    private var buttonBorder: some View {
        if case .neutral = role {
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: neutralBorderColors,
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
    }

    private var neutralFill: Color {
        colorScheme == .dark
            ? Color(red: 18 / 255, green: 18 / 255, blue: 20 / 255)
            : .white
    }

    private var neutralBorderColors: [Color] {
        colorScheme == .dark
            ? [.white.opacity(0.32), .white.opacity(0.06)]
            : [.white.opacity(0.95), .white.opacity(0.18)]
    }

    private var neutralShadowColor: Color {
        colorScheme == .dark ? .black.opacity(0.28) : .black.opacity(0.08)
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
