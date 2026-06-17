//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import Foundation

/// Target operating system for typing.
///
/// Cosmetic for now — the kit does not yet vary HID output per OS. It exists so the
/// Text Entry screen can show the OS pill from the design; behavior will be wired
/// later (e.g. newline handling, modifier/shortcut differences).
enum TypingOS: String, CaseIterable, Identifiable {
    case windows
    case macOS
    case linux

    var id: String { rawValue }

    var title: String {
        switch self {
        case .windows: String(localized: "Windows", comment: "Target OS")
        case .macOS: String(localized: "macOS", comment: "Target OS")
        case .linux: String(localized: "Linux", comment: "Target OS")
        }
    }
}
