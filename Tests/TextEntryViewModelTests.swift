import Testing
@testable import ClickStick
import ClickStickKit
import Foundation

@MainActor
struct TextEntryViewModelTests {

    private final class MockTextDevice: TextSendingDevice {
        let displayName = "ClickStick Test"
        var isConnected: Bool
        var sendError: Error?
        var textEntryKeyboardLayout: CSKeyboardLayout
        var textEntryTargetOS: CSTypingOS
        private(set) var sendCallCount = 0
        private(set) var lastSentLayout: CSKeyboardLayout?
        private(set) var lastSentTargetOS: CSTypingOS?
        private(set) var lastSavedLayout: CSKeyboardLayout?
        private(set) var lastSavedTargetOS: CSTypingOS?

        init(
            isConnected: Bool = true,
            sendError: Error? = nil,
            textEntryKeyboardLayout: CSKeyboardLayout = .usQWERTY,
            textEntryTargetOS: CSTypingOS = .windows
        ) {
            self.isConnected = isConnected
            self.sendError = sendError
            self.textEntryKeyboardLayout = textEntryKeyboardLayout
            self.textEntryTargetOS = textEntryTargetOS
        }

        func saveTextEntryPreferences(layout: CSKeyboardLayout, targetOS: CSTypingOS) {
            textEntryKeyboardLayout = layout
            textEntryTargetOS = targetOS
            lastSavedLayout = layout
            lastSavedTargetOS = targetOS
        }

        func sendText(_ text: String, layout: CSKeyboardLayout, targetOS: CSTypingOS) async throws {
            sendCallCount += 1
            lastSentLayout = layout
            lastSentTargetOS = targetOS
            if let sendError {
                throw sendError
            }
        }

        func sendText(
            _ text: String,
            layout: CSKeyboardLayout,
            targetOS: CSTypingOS,
            onCharacterProgress: @escaping @MainActor (_ sent: Int, _ total: Int) -> Void
        ) async throws {
            sendCallCount += 1
            lastSentLayout = layout
            lastSentTargetOS = targetOS
            if let sendError {
                throw sendError
            }
            await onCharacterProgress(text.count, text.count)
        }
    }

    @Test
    func loadsPersistedTextEntryPreferences() {
        let device = MockTextDevice(textEntryKeyboardLayout: .deQWERTZ, textEntryTargetOS: .linux)
        let viewModel = TextEntryViewModel(device: device)

        #expect(viewModel.selectedLayout == .deQWERTZ)
        #expect(viewModel.selectedOS == .linux)
        #expect(device.lastSavedLayout == nil)
        #expect(device.lastSavedTargetOS == nil)
    }

    @Test
    func changingSelectionPersistsTextEntryPreferences() {
        let device = MockTextDevice()
        let viewModel = TextEntryViewModel(device: device)

        viewModel.selectedLayout = .frAZERTY_Classic
        viewModel.selectedOS = .macOS

        #expect(device.textEntryKeyboardLayout == .frAZERTY_Classic)
        #expect(device.textEntryTargetOS == .macOS)
        #expect(device.lastSavedLayout == .frAZERTY_Classic)
        #expect(device.lastSavedTargetOS == .macOS)
    }

    @Test
    func sendPassesSelectedLayoutAndTargetOS() async {
        let device = MockTextDevice()
        let viewModel = TextEntryViewModel(device: device)
        viewModel.text = "hello"
        viewModel.selectedLayout = .deQWERTZ
        viewModel.selectedOS = .linux

        viewModel.requestSend()
        await Task.yield()

        #expect(device.sendCallCount == 1)
        #expect(device.lastSentLayout == .deQWERTZ)
        #expect(device.lastSentTargetOS == .linux)
    }

    @Test
    func disconnectedSendRequestsConnectionLost() {
        let device = MockTextDevice(isConnected: false)
        let viewModel = TextEntryViewModel(device: device)
        viewModel.text = "hello"

        viewModel.requestSend()

        #expect(viewModel.showConnectionLost)
        #expect(device.sendCallCount == 0)
    }

    @Test
    func dismissConnectionLostClearsPresentationRequest() {
        let device = MockTextDevice(isConnected: false)
        let viewModel = TextEntryViewModel(device: device)
        viewModel.text = "hello"
        viewModel.requestSend()

        viewModel.dismissConnectionLost()

        #expect(!viewModel.showConnectionLost)
    }

    @Test
    func sendFailureRequestsConnectionLost() async {
        let device = MockTextDevice(sendError: CSError.connectionFailed(error: nil))
        let viewModel = TextEntryViewModel(device: device)
        viewModel.text = "hello"

        viewModel.requestSend()
        await Task.yield()

        #expect(viewModel.showConnectionLost)
        #expect(!viewModel.isSending)
    }
}
