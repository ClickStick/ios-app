//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Foundation

/// Represents a deep link action that can be invoked via x-callback-url
enum DeepLinkAction: Sendable {
    case type(TypeRequest)
    // Future: case click(ClickRequest)
    // Future: case webauthn(WebAuthnRequest)
}

/// Request to type text on a connected device
struct TypeRequest: Sendable, Identifiable {
    let id = UUID()
    let text: String
    let layout: CSKeyboardLayout?
    let deviceIdentifier: String?  // UUID or alias
    let sourceApp: String?
    let successURL: URL?
    let errorURL: URL?
    let cancelURL: URL?

    /// Effective layout to use (falls back to system locale detection)
    var effectiveLayout: CSKeyboardLayout {
        layout ?? CSKeyboardLayout.fromSystemLocale()
    }
}

/// Error codes for x-callback-url error responses
enum DeepLinkErrorCode: String, Sendable {
    case invalidURL = "invalid_url"
    case missingText = "missing_text"
    case emptyText = "empty_text"
    case decodingFailed = "decoding_failed"
    case noDevice = "no_device"
    case deviceNotFound = "device_not_found"
    case notConnected = "not_connected"
    case typingFailed = "typing_failed"
    case cancelled = "cancelled"

    var message: String {
        switch self {
        case .invalidURL:
            String(localized: "Invalid request URL", comment: "Deep link error")
        case .missingText:
            String(localized: "Missing text parameter", comment: "Deep link error")
        case .emptyText:
            String(localized: "Text cannot be empty", comment: "Deep link error")
        case .decodingFailed:
            String(localized: "Could not decode text", comment: "Deep link error")
        case .noDevice:
            String(localized: "No ClickStick devices found", comment: "Deep link error")
        case .deviceNotFound:
            String(localized: "Specified device not found", comment: "Deep link error")
        case .notConnected:
            String(localized: "Device not connected", comment: "Deep link error")
        case .typingFailed:
            String(localized: "Failed to send text", comment: "Deep link error")
        case .cancelled:
            String(localized: "User cancelled", comment: "Deep link error")
        }
    }
}
