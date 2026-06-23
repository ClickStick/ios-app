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
        private(set) var sendCallCount = 0

        init(isConnected: Bool = true, sendError: Error? = nil) {
            self.isConnected = isConnected
            self.sendError = sendError
        }

        func sendText(_ text: String, layout: CSKeyboardLayout) async throws {
            sendCallCount += 1
            if let sendError {
                throw sendError
            }
        }

        func sendText(
            _ text: String,
            layout: CSKeyboardLayout,
            onCharacterProgress: @escaping @MainActor (_ sent: Int, _ total: Int) -> Void
        ) async throws {
            sendCallCount += 1
            if let sendError {
                throw sendError
            }
            await onCharacterProgress(text.count, text.count)
        }
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
