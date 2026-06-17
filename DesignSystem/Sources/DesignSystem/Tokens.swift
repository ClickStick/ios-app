//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

/// Primitive spacing values used by ClickStick screens and components.
public enum Spacing {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 20
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
    public static let xxxl: CGFloat = 40

    /// Default horizontal inset for phone-sized screens.
    public static let screenHorizontal: CGFloat = 16
}

/// Corner radii from the new iOS-first visual language.
public enum CornerRadius {
    public static let small: CGFloat = 8
    public static let medium: CGFloat = 12
    public static let control: CGFloat = 14
    public static let large: CGFloat = 16
    public static let extraLarge: CGFloat = 20
    public static let card: CGFloat = 24
    public static let sheet: CGFloat = 34
    public static let modal: CGFloat = 40
    public static let pill: CGFloat = 999
}

public enum Motion {
    public static let quick: Double = 0.1
    public static let regular: Double = 0.2
    public static let expressive: Double = 0.35
    public static let radarPulse: Double = 1.8
}

public enum OpacityLevel {
    public static let faintFill: Double = 0.04
    public static let subtleFill: Double = 0.08
    public static let tintedFill: Double = 0.12
    public static let accentFill: Double = 0.15
    public static let glassFill: Double = 0.78
    public static let subtleBorder: Double = 0.2
    public static let border: Double = 0.3
    public static let prominentBorder: Double = 0.45
    public static let scrim: Double = 0.35
    public static let pressed: Double = 0.85
    public static let disabled: Double = 0.5
    public static let disabledFill: Double = 0.28
}

public enum BorderWidth {
    public static let hairline: CGFloat = 0.5
    public static let thin: CGFloat = 1
    public static let regular: CGFloat = 1.5
    public static let thick: CGFloat = 2
}

public enum IconSize {
    public static let small: CGFloat = 16
    public static let inline: CGFloat = 18
    public static let tab: CGFloat = 22
    public static let medium: CGFloat = 28
    public static let header: CGFloat = 32
    public static let large: CGFloat = 40
    public static let row: CGFloat = 44
    public static let extraLarge: CGFloat = 48
    public static let hero: CGFloat = 56
}

public enum ComponentSize {
    public static let buttonHeight: CGFloat = 50
    public static let compactButtonHeight: CGFloat = 38
    public static let iconButton: CGFloat = 44
    public static let largeIconButton: CGFloat = 52
    public static let badgeHeight: CGFloat = 24
    public static let tabBarHeight: CGFloat = 64
    public static let sheetGrabberWidth: CGFloat = 36
    public static let sheetGrabberHeight: CGFloat = 5
    public static let minimumHitTarget: CGFloat = 44
}

/// Semantic fonts matching the Figma text scale while preserving Dynamic Type behavior.
public enum Typography {
    public static let largeTitle = Font.largeTitle.weight(.bold)
    public static let screenTitle = Font.system(.largeTitle, design: .default, weight: .bold)
    public static let title = Font.title2.weight(.bold)
    public static let sectionTitle = Font.title3.weight(.semibold)
    public static let body = Font.body
    public static let bodyEmphasized = Font.body.weight(.semibold)
    public static let callout = Font.callout
    public static let footnote = Font.footnote
    public static let caption = Font.caption
    public static let tabLabel = Font.caption2.weight(.semibold)
}

public extension Font {
    static let clickStickLargeTitle = Typography.largeTitle
    static let clickStickScreenTitle = Typography.screenTitle
    static let clickStickTitle = Typography.title
    static let clickStickSectionTitle = Typography.sectionTitle
    static let clickStickBody = Typography.body
    static let clickStickBodyEmphasized = Typography.bodyEmphasized
    static let clickStickCallout = Typography.callout
    static let clickStickFootnote = Typography.footnote
    static let clickStickCaption = Typography.caption
    static let clickStickTabLabel = Typography.tabLabel
}

public enum Elevation {
    public static let cardShadowColor = Color.black.opacity(0.08)
    public static let floatingShadowColor = Color.black.opacity(0.14)
    public static let cardRadius: CGFloat = 18
    public static let floatingRadius: CGFloat = 24
    public static let cardYOffset: CGFloat = 8
    public static let floatingYOffset: CGFloat = 12
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
    static let clickStickDestructive = Color("ClickStickDestructive", bundle: .module)

    static let clickStickGroupedBackground = Color("ClickStickGroupedBackground", bundle: .module)
    static let clickStickCardBackground = Color("ClickStickCardBackground", bundle: .module)
    static let clickStickElevatedBackground = Color("ClickStickElevatedBackground", bundle: .module)
    static let clickStickMutedFill = Color("ClickStickMutedFill", bundle: .module)
    static let clickStickSeparator = Color("ClickStickSeparator", bundle: .module)
    static let clickStickGlassFill = Color("ClickStickGlassFill", bundle: .module)
}
