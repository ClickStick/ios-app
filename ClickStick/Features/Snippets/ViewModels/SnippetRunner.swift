//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Foundation

/// A device a snippet can be typed to. Adds special-key sending to `TextSendingDevice`.
protocol SnippetRunningDevice: TextSendingDevice {
    var id: UUID { get }

    func sendSpecialKey(_ key: CSSpecialKey) async throws
}

/// Types a snippet's content to a device, one token at a time in order.
enum SnippetRunner {
    typealias DelayHandler = (_ seconds: Int) async throws -> Void

    static func unsupportedCharacters(in snippet: Snippet, layout: CSKeyboardLayout) -> [Character] {
        var seen = Set<Character>()
        var result: [Character] = []
        for token in snippet.tokens {
            guard case .text(let text) = token else { continue }
            for character in layout.unsupportedCharacters(in: text) where seen.insert(character).inserted {
                result.append(character)
            }
        }
        return result
    }

    static func run(
        _ snippet: Snippet,
        on device: SnippetRunningDevice,
        delay: DelayHandler = Self.sleepForDelay(seconds:)
    ) async throws {
        let layout = device.textEntryKeyboardLayout
        let targetOS = device.textEntryTargetOS

        for token in snippet.tokens {
            try Task.checkCancellation()
            switch token {
            case .text(let text):
                try await device.sendText(text, layout: layout, targetOS: targetOS)
            case .tab:
                try await device.sendSpecialKey(.tab)
            case .enter:
                try await device.sendSpecialKey(.enter)
            case .cursor(let key):
                try await device.sendSpecialKey(.cursor(key.csCursorKey))
            case .functionKey(let number):
                try await device.sendSpecialKey(.function(number))
            case .delay(let seconds):
                try await delay(seconds)
            }
        }
    }

    private static func sleepForDelay(seconds: Int) async throws {
        guard seconds > 0 else { return }
        try await Task.sleep(for: .seconds(seconds))
    }
}

private extension CursorKey {
    var csCursorKey: CSCursorKey {
        switch self {
        case .left: .left
        case .right: .right
        case .up: .up
        case .down: .down
        case .home: .home
        case .end: .end
        }
    }
}
