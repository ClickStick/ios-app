//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import Foundation

/// A cursor-movement key.
public enum CSCursorKey: Equatable {
    case left
    case right
    case up
    case down
    case home
    case end
}

/// A single non-text key that can be sent to the dongle (used by snippets to insert Tab, Enter,
/// cursor movement, and function keys between text runs).
public enum CSSpecialKey: Equatable {
    case tab
    case enter
    case cursor(CSCursorKey)
    /// A function key, `number` in 1...12.
    case function(_ number: Int)

    /// The HID keyboard usage code for this key, or `nil` if out of range.
    var keyCode: KeyCode? {
        switch self {
        case .tab:
            return .tab
        case .enter:
            return .enter
        case .cursor(let key):
            switch key {
            case .left: return KeyCode(0x50)  // Keyboard Left Arrow
            case .right: return KeyCode(0x4F) // Keyboard Right Arrow
            case .up: return KeyCode(0x52)    // Keyboard Up Arrow
            case .down: return KeyCode(0x51)  // Keyboard Down Arrow
            case .home: return KeyCode(0x4A)  // Keyboard Home
            case .end: return KeyCode(0x4D)   // Keyboard End
            }
        case .function(let number):
            guard (1...12).contains(number) else { return nil }
            return KeyCode(UInt8(0x3A + number - 1)) // F1 = 0x3A … F12 = 0x45
        }
    }
}

extension CSDevice {
    /// Sends a single special key press to the dongle.
    public func sendSpecialKey(_ key: CSSpecialKey, completion: CSCommandCompletion?) {
        guard let keyCode = key.keyCode else {
            completion?(.failure(CSError.commandError(.internalError("Special key out of range: \(key)"))))
            return
        }
        let command = CSTypeCommand(
            keyCodes: [keyCode],
            maxCommandSize: _maxCommandSize,
            completion: completion
        )
        _enqueueCommand(command)
    }
}
