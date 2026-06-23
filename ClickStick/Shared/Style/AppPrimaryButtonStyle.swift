//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

// App-local primary button: full-width blue pill.
struct AppPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    var fill: Color = .accentBlue

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(isEnabled ? Color.white : Color.white.opacity(0.5))
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 999)
                    .fill(isEnabled ? fill : Color(uiColor: .systemGray3))
            )
            .contentShape(RoundedRectangle(cornerRadius: 999))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.1), value: isEnabled)
    }
}

/// Circular icon button for the navigation bar. Draws its own solid fill (matching the
/// figma circles) rather than relying on the system glass toolbar button, so its color
/// and state transitions are fully under our control — the native `.borderedProminent`
/// glass button animates its enable/disable through UIKit's nav bar, which SwiftUI can't
/// drive. Pair with `appHiddenSharedToolbarBackground()` so iOS 26 doesn't draw its glass
/// capsule behind the circle.
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
    /// Hides the iOS 26 shared glass background behind toolbar items so a custom button
    /// fill (e.g. `CircularToolbarButtonStyle`) isn't double-styled by the system capsule.
    @ToolbarContentBuilder
    func appHiddenSharedToolbarBackground() -> some ToolbarContent {
        if #available(iOS 26.0, macCatalyst 26.0, *) {
            self.sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}
