//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Foundation
import Observation
import os.log

private let snippetsLog = Logger(subsystem: "io.clickstick", category: "SnippetsViewModel")

/// What the snippet editor sheet is currently editing.
enum SnippetEditorTarget: Identifiable {
    case new
    case edit(Snippet)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let snippet): snippet.id.uuidString
        }
    }

    var snippet: Snippet? {
        switch self {
        case .new: nil
        case .edit(let snippet): snippet
        }
    }
}

/// Owns the list of snippets for a device and drives create/edit/delete and the editor sheet.
@Observable
@MainActor
final class SnippetsViewModel {
    let deviceName: String

    private(set) var snippets: [Snippet] = []
    var editorTarget: SnippetEditorTarget?
    /// The snippet currently being typed to the device, if any (drives the row's run spinner).
    private(set) var runningSnippetID: UUID?
    /// Success/failure feedback mirroring text entry: a "Sent to <device>" toast and the shared
    /// connection-lost sheet (presented by DeviceDetailView).
    private let toastTimer = SentToastTimer()
    var showSentToast: Bool { toastTimer.isVisible }
    var showConnectionLost = false
    var alertError: AlertError?
    var isShowingUnsupportedPrompt = false
    private(set) var unsupportedPromptMessage: String?

    private let store: any SnippetStoring
    private let device: SnippetRunningDevice?
    private var runTask: Task<Void, Never>?
    private var unsupportedSnippet: Snippet?

    init(device: SnippetRunningDevice, store: (any SnippetStoring)? = nil) {
        self.deviceName = device.displayName
        self.device = device
        self.store = store ?? SnippetStore()
        reload()
    }

    isolated deinit {
        runTask?.cancel()
        toastTimer.cancel()
    }

    func reload() {
        do {
            snippets = try store.loadAll()
        } catch {
            snippetsLog.error("Snippet load failed: \(error.localizedDescription, privacy: .public)")
            alertError = AlertError(title: String(localized: "Snippets Error", comment: "Snippet storage error title"), error: error)
        }
    }

    // MARK: - Editing

    func startNewSnippet() {
        editorTarget = .new
    }

    func edit(_ snippet: Snippet) {
        editorTarget = .edit(snippet)
    }

    func commit(_ snippet: Snippet) {
        do {
            try store.save(snippet)
            editorTarget = nil
            upsert(snippet)
        } catch {
            snippetsLog.error("Snippet save failed: \(error.localizedDescription, privacy: .public)")
            alertError = AlertError(title: String(localized: "Snippets Error", comment: "Snippet storage error title"), error: error)
        }
    }

    func delete(_ snippet: Snippet) {
        do {
            try store.delete(snippet)
            snippets.removeAll { $0.id == snippet.id }
        } catch {
            snippetsLog.error("Snippet delete failed: \(error.localizedDescription, privacy: .public)")
            alertError = AlertError(title: String(localized: "Snippets Error", comment: "Snippet storage error title"), error: error)
        }
    }

    /// Inserts or replaces a snippet in the in-memory list, keeping the store's creation order.
    private func upsert(_ snippet: Snippet) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index] = snippet
        } else {
            let insertionIndex = snippets.firstIndex { $0.createdAt > snippet.createdAt } ?? snippets.count
            snippets.insert(snippet, at: insertionIndex)
        }
    }

    /// Types a snippet's content to the device, one token at a time.
    func run(_ snippet: Snippet) {
        guard let device, runningSnippetID == nil else { return }
        guard device.isConnected else {
            showConnectionLost = true
            return
        }
        guard validateTypableText(in: snippet, on: device) else { return }
        startRun(snippet, on: device)
    }

    func dismissConnectionLost() {
        showConnectionLost = false
    }

    func dismissUnsupportedPrompt() {
        isShowingUnsupportedPrompt = false
        unsupportedPromptMessage = nil
        unsupportedSnippet = nil
    }

    func editUnsupportedSnippet() {
        guard let unsupportedSnippet else {
            dismissUnsupportedPrompt()
            return
        }
        dismissUnsupportedPrompt()
        edit(unsupportedSnippet)
    }

    private func validateTypableText(in snippet: Snippet, on device: SnippetRunningDevice) -> Bool {
        let unsupportedCharacters = SnippetRunner.unsupportedCharacters(in: snippet, layout: device.textEntryKeyboardLayout)
        guard !unsupportedCharacters.isEmpty else { return true }

        let characters = unsupportedCharacters.map(String.init).joined(separator: " ")
        let layoutName = device.textEntryKeyboardLayout.description.replacing(" - ", with: "-")
        unsupportedPromptMessage = String(
            localized: "\(characters) can't be typed with \(layoutName). Edit the snippet or change the keyboard layout in Text Entry.",
            comment: "Snippet unsupported characters sheet message"
        )
        unsupportedSnippet = snippet
        isShowingUnsupportedPrompt = true
        return false
    }

    private func startRun(_ snippet: Snippet, on device: SnippetRunningDevice) {
        runningSnippetID = snippet.id
        runTask = Task { [weak self] in
            guard let self else { return }
            defer { self.runningSnippetID = nil }
            do {
                try await SnippetRunner.run(snippet, on: device)
                self.toastTimer.flash()
            } catch is CancellationError {
                // Ignore: run was superseded or the view model went away.
            } catch {
                snippetsLog.error("Snippet run failed: \(error.localizedDescription, privacy: .public)")
                if let csError = error as? CSError, case .connectionFailed = csError {
                    self.showConnectionLost = true
                } else {
                    self.alertError = AlertError(title: String(localized: "Snippets Error", comment: "Snippet storage error title"), error: error)
                }
            }
        }
    }

#if DEBUG
    /// Preview-only initializer backed by an in-memory list instead of the SQLite database.
    init(previewSnippets: [Snippet], deviceName: String = "ClickStick 9F8C") {
        self.deviceName = deviceName
        self.store = InMemorySnippetStore(snippets: previewSnippets)
        self.device = nil
        reload()
    }
#endif
}
