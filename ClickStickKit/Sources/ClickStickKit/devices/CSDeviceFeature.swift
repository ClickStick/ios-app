//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import Foundation

public enum CSDeviceFeature: CustomStringConvertible {
    case textEntry
    case mouse

    public var description: String {
        switch self {
        case .textEntry:
            return "Text Entry"
        case .mouse:
            return "Touchpad"
        }
    }
}
