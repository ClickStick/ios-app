//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

/// Primitive design values that should stay stable across components.
public enum Spacing {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 20
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
}

public enum CornerRadius {
    public static let small: CGFloat = 8
    public static let medium: CGFloat = 12
    public static let large: CGFloat = 16
    public static let extraLarge: CGFloat = 20
}

public enum Motion {
    public static let quick: Double = 0.1
    public static let regular: Double = 0.2
}

public enum OpacityLevel {
    public static let subtleFill: Double = 0.1
    public static let accentFill: Double = 0.15
    public static let subtleBorder: Double = 0.3
    public static let pressed: Double = 0.85
    public static let disabled: Double = 0.5
}

public extension LinearGradient {
    static let clickStickGradient = LinearGradient(
        colors: [.clickStickBlue, .clickStickTeal],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

public extension Color {
    static let clickStickBlue = Color("ClickStickBlue", bundle: .module)
    static let clickStickTeal = Color("ClickStickTeal", bundle: .module)
    static let clickStickGreen = Color("ClickStickGreen", bundle: .module)
    static let clickStickOrange = Color("ClickStickOrange", bundle: .module)
}
