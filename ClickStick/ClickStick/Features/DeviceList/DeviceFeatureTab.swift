//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit

enum DeviceFeatureTab: String, CaseIterable, Identifiable {
    case textEntry = "Text Entry"
    case mouse = "Touchpad"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .textEntry: "keyboard"
        case .mouse: "computermouse"
        }
    }

    var feature: CSDeviceFeature {
        switch self {
        case .textEntry: .textEntry
        case .mouse: .mouse
        }
    }
}
