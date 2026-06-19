//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Foundation
import Observation

@Observable
@MainActor
final class TextEntryViewModel {
    /// Sends longer than this show the "Sending…" progress sheet; shorter sends
    /// just flash a "Sent" toast. Arbitrary threshold — tuned for feel, not a limit.
    private static let progressSheetThreshold = 50

    // MARK: - Progress sheet state

    enum ProgressState: Equatable {
        case sending(sent: Int, total: Int)
        case sent
        case stopped(sent: Int, total: Int)
    }

    // MARK: - Dependencies

    private let device: any TextSendingDevice

    // MARK: - Input

    var text: String = ""
    var selectedLayout: CSKeyboardLayout = .usQWERTY
    var selectedOS: TypingOS = .windows

    // MARK: - Output state

    private(set) var isSending: Bool = false
    /// Non-nil while the progress sheet should be presented (long sends).
    private(set) var progress: ProgressState?
    /// Drives the unsupported-characters confirmation sheet (set on Send attempt).
    private(set) var unsupportedPrompt: [Character]?
    /// Drives the "Connection lost" sheet.
    var showConnectionLost: Bool = false
    /// Drives the brief "Sent to …" toast (short sends).
    private(set) var showSentToast: Bool = false

    private var sendTask: Task<Void, Never>?
    private var lastSendSkippedUnsupportedCharacters = false

    // MARK: - Initialization

    init(device: any TextSendingDevice) {
        self.device = device
        self.selectedLayout = CSKeyboardLayout.fromSystemLocale()
    }

    // MARK: - Derived

    var deviceName: String { device.displayName }
    var isConnected: Bool { device.isConnected }
    var isEmpty: Bool { text.isEmpty }
    var characterCount: Int { text.count }

    var canSend: Bool { !isEmpty && !isSending }

    /// Characters in the current text the selected layout cannot type.
    var unsupportedCharacters: [Character] {
        selectedLayout.unsupportedCharacters(in: text)
    }

    var hasUnsupportedCharacters: Bool { !unsupportedCharacters.isEmpty }

    /// Inline warning under the text card, e.g. "US - QWERTY can't type: Щ".
    var inlineUnsupportedMessage: String? {
        guard hasUnsupportedCharacters else { return nil }
        let characters = unsupportedCharacters.map(String.init).joined(separator: " ")
        return String(localized: "\(selectedLayout.description) can't type: \(characters)",
                      comment: "Inline unsupported characters warning")
    }

    /// Body for the unsupported-characters sheet.
    var unsupportedPromptMessage: String? {
        guard let unsupportedPrompt, !unsupportedPrompt.isEmpty else { return nil }
        let characters = unsupportedPrompt.map(String.init).joined(separator: " ")
        let layoutName = selectedLayout.description.replacingOccurrences(of: " - ", with: "-")
        return String(localized: "\(characters) can't be typed with \(layoutName). They will be skipped.",
                      comment: "Unsupported characters sheet message")
    }

    // MARK: - Actions

    func clearText() {
        text = ""
    }

    /// Entry point for the header send button.
    func requestSend() {
        guard canSend else { return }
        if hasUnsupportedCharacters {
            unsupportedPrompt = unsupportedCharacters
            return
        }
        performSend()
    }

    func sendAnyway() {
        unsupportedPrompt = nil
        performSend(skipUnsupportedCharacters: true)
    }

    func dismissUnsupportedPrompt() {
        unsupportedPrompt = nil
    }

    func cancelSend() {
        if case .sending(let sent, let total) = progress {
            progress = .stopped(sent: sent, total: total)
        }
        sendTask?.cancel()
        sendTask = nil
        isSending = false
    }

    func dismissProgressSheet() {
        progress = nil
    }

    func dismissConnectionLost() {
        showConnectionLost = false
    }

    func retryAfterConnectionLost() {
        guard canSend else { return }
        showConnectionLost = false
        performSend(skipUnsupportedCharacters: lastSendSkippedUnsupportedCharacters)
    }

    // MARK: - Send

    private func performSend(skipUnsupportedCharacters: Bool = false) {
        guard !isSending else { return }
        guard isConnected else {
            showConnectionLost = true
            return
        }

        let textToSend = skipUnsupportedCharacters ? typableText(from: text) : text
        let total = textToSend.count
        guard total > 0 else { return }

        lastSendSkippedUnsupportedCharacters = skipUnsupportedCharacters
        let showsSheet = total > Self.progressSheetThreshold
        isSending = true
        progress = showsSheet ? .sending(sent: 0, total: total) : nil

        sendTask = Task { [weak self] in
            guard let self else { return }
            do {
                if showsSheet {
                    try await device.sendText(textToSend, layout: selectedLayout) { sent, total in
                        // Only advance while actively sending; ignore late callbacks after stop.
                        if case .sending = self.progress {
                            self.progress = .sending(sent: sent, total: total)
                        }
                    }
                } else {
                    try await device.sendText(textToSend, layout: selectedLayout)
                }
                handleSendSuccess(showsSheet: showsSheet)
            } catch is CancellationError {
                // cancelSend() already transitioned `progress` to `.stopped`.
                isSending = false
            } catch {
                isSending = false
                progress = nil
                showConnectionLost = true
            }
            sendTask = nil
        }
    }

    private func typableText(from text: String) -> String {
        String(text.filter { selectedLayout.canType(String($0)) })
    }

    private func handleSendSuccess(showsSheet: Bool) {
        isSending = false
        text = ""
        if showsSheet {
            progress = .sent
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(1.2))
                guard let self, case .sent = self.progress else { return }
                self.progress = nil
            }
        } else {
            flashSentToast()
        }
    }

    private func flashSentToast() {
        showSentToast = true
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.showSentToast = false
        }
    }

#if DEBUG
    func configureForPreview(
        text: String = "",
        isToastVisible: Bool = false,
        progress: ProgressState? = nil,
        isConnectionLost: Bool = false,
        presentsSheets: Bool = true
    ) {
        self.selectedLayout = .usQWERTY
        self.selectedOS = .windows
        self.text = text
        self.showSentToast = isToastVisible
        self.progress = presentsSheets ? progress : nil
        self.showConnectionLost = presentsSheets && isConnectionLost
        self.unsupportedPrompt = nil
        if presentsSheets, progress == nil, !isConnectionLost, hasUnsupportedCharacters {
            unsupportedPrompt = unsupportedCharacters
        }
    }
#endif
}
