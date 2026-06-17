//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import Foundation

enum OnboardingStorage {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let isDemoModeEnabled = "isDemoModeEnabled"
}

enum OnboardingCompletionAction {
    case addDevice
    case demoMode
}
