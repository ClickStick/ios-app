//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import Foundation

enum AppDeepLink: Equatable {
    case addDevice
    case sendText(SendTextDeepLink)

    init?(url: URL) {
        guard url.scheme?.caseInsensitiveCompare("clickstick") == .orderedSame else { return nil }

        let host = url.host?.nilIfEmpty
        let pathCommand = url.pathComponents.dropFirst().first?.nilIfEmpty
        let command = if host?.caseInsensitiveCompare("x-callback-url") == .orderedSame {
            pathCommand
        } else {
            host ?? pathCommand
        }

        switch command?.lowercased() {
        case "add-device":
            self = .addDevice
        case "send-text":
            guard let link = SendTextDeepLink(url: url) else { return nil }
            self = .sendText(link)
        default:
            return nil
        }
    }
}

struct SendTextDeepLink: Equatable {
    let deviceID: UUID?
    let text: String
    let callback: SendTextCallback

    init(deviceID: UUID?, text: String, callback: SendTextCallback = SendTextCallback()) {
        self.deviceID = deviceID
        self.text = text
        self.callback = callback
    }

    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let queryItems = components.queryItems ?? []

        guard let text = queryItems.value(for: "text"), !text.isEmpty else { return nil }

        let deviceID: UUID?
        if let device = queryItems.value(for: "device"), !device.isEmpty {
            guard let uuid = UUID(uuidString: device) else { return nil }
            deviceID = uuid
        } else {
            deviceID = nil
        }

        self.init(
            deviceID: deviceID,
            text: text,
            callback: SendTextCallback(
                source: queryItems.value(for: "x-source"),
                success: queryItems.urlValue(for: "x-success"),
                error: queryItems.urlValue(for: "x-error"),
                cancel: queryItems.urlValue(for: "x-cancel")
            )
        )
    }

    var pendingRequest: PendingSendTextRequest {
        PendingSendTextRequest(deviceID: deviceID, text: text, callback: callback)
    }
}

struct SendTextCallback: Equatable {
    var source: String?
    var success: URL?
    var error: URL?
    var cancel: URL?

    init(source: String? = nil, success: URL? = nil, error: URL? = nil, cancel: URL? = nil) {
        self.source = source
        self.success = success
        self.error = error
        self.cancel = cancel
    }
}

struct PendingSendTextRequest: Identifiable, Equatable {
    let id: UUID
    let deviceID: UUID?
    let text: String
    let callback: SendTextCallback
    let isReadyForSelectedDevice: Bool

    init(
        id: UUID = UUID(),
        deviceID: UUID?,
        text: String,
        callback: SendTextCallback,
        isReadyForSelectedDevice: Bool = false
    ) {
        self.id = id
        self.deviceID = deviceID
        self.text = text
        self.callback = callback
        self.isReadyForSelectedDevice = isReadyForSelectedDevice
    }

    func readyForSelectedDevice() -> PendingSendTextRequest {
        PendingSendTextRequest(
            id: id,
            deviceID: deviceID,
            text: text,
            callback: callback,
            isReadyForSelectedDevice: true
        )
    }
}

private extension [URLQueryItem] {
    func value(for name: String) -> String? {
        first(where: { $0.name == name })?.value
    }

    func urlValue(for name: String) -> URL? {
        guard let string = value(for: name) else { return nil }
        // URLComponents decodes query values once. Some external launch paths (notably
        // Simulator/open-url handoff) can deliver already-escaped callback URLs as escaped
        // again, so if the singly-decoded string doesn't parse as a usable URL, try one more
        // decode pass. Unlike free-text values, a URL either parses into something meaningful
        // or it doesn't, so this can't silently corrupt a value the way blindly re-decoding
        // arbitrary text could.
        return callbackURL(from: string) ?? string.removingPercentEncoding.flatMap(callbackURL(from:))
    }

    private func callbackURL(from string: String) -> URL? {
        guard let url = URL(string: string),
              let scheme = url.scheme?.nilIfEmpty,
              scheme.caseInsensitiveCompare("file") != .orderedSame else { return nil }
        return url
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
