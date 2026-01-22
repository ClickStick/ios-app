//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import SwiftUI

/// Feature tabs displayed in the device detail view
/// As per basic.txt: "show stick's functions as tabs in the secondary panel, then everything is one tap away"
enum DeviceFeatureTab: String, CaseIterable, Identifiable {
    case textEntry = "Text Entry"
    case mouse = "Touchpad"

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .textEntry: String(localized: "Text Entry", comment: "Tab title")
        case .mouse: String(localized: "Touchpad", comment: "Tab title")
        }
    }

    var icon: String {
        switch self {
        case .textEntry: "character.cursor.ibeam"
        case .mouse: "rectangle.and.hand.point.up.left"
        }
    }

    var feature: CSDeviceFeature {
        switch self {
        case .textEntry: .textEntry
        case .mouse: .mouse
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .textEntry: String(localized: "Text Entry mode", comment: "Accessibility label")
        case .mouse: String(localized: "Touchpad mode", comment: "Accessibility label")
        }
    }
}
