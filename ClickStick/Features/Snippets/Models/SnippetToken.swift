//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

/// A cursor-movement key the user can insert from the Cursor selector.
enum CursorKey: String, Codable, CaseIterable, Identifiable {
    case left, right, up, down, home, end

    var id: String { rawValue }

    /// SF Symbol for arrow keys; `nil` for Home/End (shown as text).
    var systemImage: String? {
        switch self {
        case .left: "arrow.left"
        case .right: "arrow.right"
        case .up: "arrow.up"
        case .down: "arrow.down"
        case .home, .end: nil
        }
    }

    /// User-facing label.
    var title: String {
        switch self {
        case .left: String(localized: "Left", comment: "Cursor key")
        case .right: String(localized: "Right", comment: "Cursor key")
        case .up: String(localized: "Up", comment: "Cursor key")
        case .down: String(localized: "Down", comment: "Cursor key")
        case .home: String(localized: "Home", comment: "Cursor key")
        case .end: String(localized: "End", comment: "Cursor key")
        }
    }
}

/// One element of a snippet's content. Content is an ordered list of tokens: literal text runs
/// interleaved with special keys and delays, matching the "type text, then insert keys" model
/// in the snippet editor.
enum SnippetToken: Codable, Equatable, Hashable {
    /// A literal run of text to type.
    case text(String)
    /// Tab key press.
    case tab
    /// Enter/Return key press.
    case enter
    /// A cursor-movement key press.
    case cursor(CursorKey)
    /// A function key press, `number` in 1...12.
    case functionKey(Int)
    /// A pause of `seconds` before continuing.
    case delay(seconds: Int)

    /// Whether this token is an inline "chip" (everything except literal text).
    var isKey: Bool {
        if case .text = self { return false }
        return true
    }

    /// Label shown inside the chip for key tokens (`nil` for text).
    var chipTitle: String? {
        switch self {
        case .text: nil
        case .tab: String(localized: "Tab", comment: "Snippet key chip")
        case .enter: String(localized: "Enter", comment: "Snippet key chip")
        case .cursor(let key): key.title
        case .functionKey(let number): "F\(number)"
        case .delay(let seconds): "\(seconds)s"
        }
    }

    /// SF Symbol shown inside the chip for key tokens (`nil` for text and function keys, which
    /// show only their label).
    var chipSystemImage: String? {
        switch self {
        case .text, .functionKey: nil
        case .tab: "arrow.right.to.line"
        case .enter: "arrow.turn.down.left"
        case .cursor(let key): key.systemImage
        case .delay: "timer"
        }
    }
}
