//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import SwiftUI

/// Feature tabs displayed in the device detail view.
enum DeviceFeatureTab: String, CaseIterable, Identifiable {
    case textEntry = "Text Entry"
    case snippets = "Snippets"
    case mouse = "Touchpad"

    var id: String { rawValue }

    var localizedTitle: LocalizedStringKey {
        switch self {
        case .textEntry: "Text Entry"
        case .snippets: "Snippets"
        case .mouse: "Touchpad"
        }
    }

    var icon: String {
        switch self {
        case .textEntry: "character.cursor.ibeam"
        case .snippets: "list.bullet"
        case .mouse: "rectangle.and.hand.point.up.left"
        }
    }

    var feature: CSDeviceFeature? {
        switch self {
        case .textEntry: .textEntry
        case .snippets: nil
        case .mouse: .mouse
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .textEntry: String(localized: "Text Entry mode", comment: "Accessibility label")
        case .snippets: String(localized: "Snippets mode", comment: "Accessibility label")
        case .mouse: String(localized: "Touchpad mode", comment: "Accessibility label")
        }
    }
}
