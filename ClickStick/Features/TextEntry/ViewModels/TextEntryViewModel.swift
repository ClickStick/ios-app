//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Foundation
import Observation

@Observable
@MainActor
final class TextEntryViewModel {
    private static let progressSheetThreshold = 50

    // MARK: - Progress sheet state

    enum ProgressState: Equatable, Identifiable {
        case sending(sent: Int, total: Int)
        case sent
        case stopped(sent: Int, total: Int)

        var id: String { "progress" }
    }

    // MARK: - Dependencies

    private let device: any TextSendingDevice
    private let urlOpener: (any URLOpening)?

    // MARK: - Input

    var text: String = ""
    var selectedLayout: CSKeyboardLayout = .usQWERTY {
        didSet { persistTextEntryPreferencesIfNeeded() }
    }
    var selectedOS: CSTypingOS = .windows {
        didSet { persistTextEntryPreferencesIfNeeded() }
    }

    // MARK: - Output state

    private(set) var isSending: Bool = false
    var progress: ProgressState?
    var isShowingUnsupportedPrompt: Bool = false
    var showConnectionLost: Bool = false
    private let toastTimer = SentToastTimer()
    var showSentToast: Bool { toastTimer.isVisible }

    private var sendTask: Task<Void, Never>?
    private var dismissProgressTask: Task<Void, Never>?
    private var persistsSelectionChanges = true
    private var sendTextCallback: SendTextCallback?

    // MARK: - Initialization

    init(device: any TextSendingDevice, urlOpener: (any URLOpening)? = nil) {
        self.device = device
        self.urlOpener = urlOpener
        updateSelectionWithoutPersisting(
            layout: device.textEntryKeyboardLayout,
            targetOS: device.textEntryTargetOS
        )
    }

    isolated deinit {
        sendTask?.cancel()
        dismissProgressTask?.cancel()
        toastTimer.cancel()
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

    var inlineUnsupportedMessage: String? {
        guard hasUnsupportedCharacters else { return nil }
        let characters = unsupportedCharacters.map(String.init).joined(separator: " ")
        return String(localized: "\(selectedLayout.description) can't type: \(characters)",
                      comment: "Inline unsupported characters warning")
    }

    var unsupportedPromptMessage: String? {
        guard !unsupportedCharacters.isEmpty else { return nil }
        let characters = unsupportedCharacters.map(String.init).joined(separator: " ")
        let layoutName = selectedLayout.description.replacing(" - ", with: "-")
        return String(localized: "\(characters) can't be typed with \(layoutName). They will be skipped.",
                      comment: "Unsupported characters sheet message")
    }

    // MARK: - Actions

    func clearText() {
        text = ""
    }

    func configureForSendTextDeepLink(text: String, callback: SendTextCallback) {
        self.text = text
        sendTextCallback = callback
    }

    /// Entry point for the header send button.
    func requestSend() {
        guard canSend else { return }
        if hasUnsupportedCharacters {
            isShowingUnsupportedPrompt = true
            return
        }
        performSend()
    }

    func sendAnyway() {
        isShowingUnsupportedPrompt = false
        performSend(skipUnsupportedCharacters: true)
    }

    func dismissUnsupportedPrompt() {
        isShowingUnsupportedPrompt = false
    }

    func cancelSend() {
        if case .sending(let sent, let total) = progress {
            progress = .stopped(sent: sent, total: total)
        }
        sendTask?.cancel()
        sendTask = nil
        dismissProgressTask?.cancel()
        dismissProgressTask = nil
        isSending = false
    }

    func dismissProgressSheet() {
        progress = nil
    }

    func dismissConnectionLost() {
        showConnectionLost = false
    }

    // MARK: - Send

    private func performSend(skipUnsupportedCharacters: Bool = false) {
        guard !isSending else { return }
        guard isConnected else {
            showConnectionLost = true
            openErrorCallbackIfNeeded(
                code: "connectionUnavailable",
                message: String(localized: "Device is not connected", comment: "Deep link send-text callback error")
            )
            return
        }

        let textToSend = skipUnsupportedCharacters ? typableText(from: text) : text
        let total = textToSend.count
        guard total > 0 else { return }

        let showsSheet = total > Self.progressSheetThreshold
        isSending = true
        progress = showsSheet ? .sending(sent: 0, total: total) : nil

        sendTask = Task { [weak self] in
            guard let self else { return }
            do {
                if showsSheet {
                    try await device.sendText(textToSend, layout: selectedLayout, targetOS: selectedOS) { sent, total in
                        // Only advance while actively sending; ignore late callbacks after stop.
                        if case .sending = self.progress {
                            self.progress = .sending(sent: sent, total: total)
                        }
                    }
                } else {
                    try await device.sendText(textToSend, layout: selectedLayout, targetOS: selectedOS)
                }
                handleSendSuccess(showsSheet: showsSheet)
            } catch is CancellationError {
                // cancelSend() already transitioned `progress` to `.stopped`.
                isSending = false
            } catch {
                isSending = false
                progress = nil
                showConnectionLost = true
                openErrorCallbackIfNeeded(code: "sendFailed", message: error.localizedDescription)
            }
            sendTask = nil
        }
    }

    private func typableText(from text: String) -> String {
        String(text.filter { selectedLayout.canType(String($0)) })
    }

    private func persistTextEntryPreferencesIfNeeded() {
        guard persistsSelectionChanges else { return }
        device.saveTextEntryPreferences(layout: selectedLayout, targetOS: selectedOS)
    }

    private func updateSelectionWithoutPersisting(layout: CSKeyboardLayout, targetOS: CSTypingOS) {
        persistsSelectionChanges = false
        selectedLayout = layout
        selectedOS = targetOS
        persistsSelectionChanges = true
    }

    private func handleSendSuccess(showsSheet: Bool) {
        isSending = false
        text = ""
        openSuccessCallbackIfNeeded()
        if showsSheet {
            progress = .sent
            dismissProgressTask?.cancel()
            dismissProgressTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(1))
                guard let self, case .sent = self.progress else { return }
                self.progress = nil
                self.dismissProgressTask = nil
            }
        } else {
            toastTimer.flash()
        }
    }

    private func openSuccessCallbackIfNeeded() {
        guard let callback = sendTextCallback else { return }
        sendTextCallback = nil
        guard let url = callback.success else { return }
        openCallback(url, extraQueryItems: [])
    }

    private func openErrorCallbackIfNeeded(code: String, message: String) {
        guard let callback = sendTextCallback,
              let url = callback.error else { return }
        sendTextCallback = nil
        openCallback(url, extraQueryItems: [
            URLQueryItem(name: "errorCode", value: code),
            URLQueryItem(name: "errorMessage", value: message)
        ])
    }

    private func openCallback(_ baseURL: URL, extraQueryItems: [URLQueryItem]) {
        let queryItems = [
            URLQueryItem(name: "x-source", value: "ClickStick"),
            URLQueryItem(name: "device", value: device.id.uuidString)
        ] + extraQueryItems

        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            urlOpener?.open(baseURL, completion: nil)
            return
        }
        components.queryItems = (components.queryItems ?? []) + queryItems
        urlOpener?.open(components.url ?? baseURL, completion: nil)
    }

#if DEBUG
    func configureForPreview(
        text: String = "",
        isSending: Bool = false,
        isToastVisible: Bool = false,
        progress: ProgressState? = nil,
        isConnectionLost: Bool = false,
        presentsSheets: Bool = true
    ) {
        updateSelectionWithoutPersisting(layout: .usQWERTY, targetOS: .windows)
        self.text = text
        self.isSending = isSending
        toastTimer.setVisibleForPreview(isToastVisible)
        self.progress = presentsSheets ? progress : nil
        self.showConnectionLost = presentsSheets && isConnectionLost
        self.isShowingUnsupportedPrompt = presentsSheets && progress == nil && !isConnectionLost && hasUnsupportedCharacters
    }
#endif
}
