//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Foundation

extension CSTypingOS {
    var title: String {
        switch self {
        case .windows: String(localized: "Windows", comment: "Target OS")
        case .macOS: String(localized: "macOS", comment: "Target OS")
        case .linux: String(localized: "Linux", comment: "Target OS")
        }
    }
}
