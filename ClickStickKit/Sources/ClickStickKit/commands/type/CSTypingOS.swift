//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import Foundation

/// Target operating system for typing.
///
/// The keyboard mapper does not vary HID output per OS yet. The value is kept in
/// the command path now so OS-specific typing behavior can be wired into mappings
/// later without changing app-side selection and persistence again.
public enum CSTypingOS: String, CaseIterable, Codable, Identifiable {
    case windows
    case macOS
    case linux

    public var id: String { rawValue }
}
