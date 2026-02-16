//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import Foundation

enum TypingSpeed {
    case unlimited
    case human(delayPerCharacter: TimeInterval)

    static let defaultHumanDelay: TimeInterval = 1000
}
