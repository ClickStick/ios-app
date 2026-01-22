//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import Foundation
import SwiftUI

/// Keys for UserDefaults/AppStorage
enum AppStorageKey {
    /// Whether the welcome announcement has been dismissed
    static let hasShownWelcome = "hasShownWelcome"

    /// Whether the demo mode prompt has been dismissed
    static let hasDismissedDemoPrompt = "hasDismissedDemoPrompt"

    /// Whether demo mode is enabled
    static let isDemoMode = "isDemoMode"
}
