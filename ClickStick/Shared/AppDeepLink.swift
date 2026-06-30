//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import Foundation

enum AppDeepLink: Equatable {
    case addDevice

    init?(url: URL) {
        guard url.scheme?.caseInsensitiveCompare("clickstick") == .orderedSame else { return nil }

        let command = url.host?.nilIfEmpty
            ?? url.pathComponents.dropFirst().first?.nilIfEmpty

        switch command?.lowercased() {
        case "add-device":
            self = .addDevice
        default:
            return nil
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
