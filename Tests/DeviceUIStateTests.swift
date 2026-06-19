import Testing
@testable import ClickStick
import ClickStickKit
import Foundation

@MainActor
struct DeviceUIStateTests {

    // MARK: - Helpers

    private func model(state: CSDevice.PreviewState, name: String = "Test") -> DeviceModel {
        DeviceModel(device: .makePreview(name: name, state: state))
    }

    // MARK: - Basic Connection States

    @Test
    func connectedDeviceHasConnectedState() {
        let m = model(state: .connected)
        #expect(m.uiState == .connected)
    }

    @Test
    func connectingDeviceHasConnectingState() {
        let m = model(state: .connecting)
        #expect(m.uiState == .connecting)
    }

    @Test
    func weakSignalDeviceHasWeakSignalState() {
        let m = model(state: .weakSignal)
        #expect(m.uiState == .weakSignal)
    }

    @Test
    func outOfRangeDeviceHasOutOfRangeState() {
        let m = model(state: .outOfRange)
        #expect(m.uiState == .outOfRange)
    }

    // MARK: - Compromised

    @Test
    func compromisedDeviceHasCompromisedState() {
        let m = model(state: .outOfRange)
        m.deviceDidDetectTampering(m.device)
        #expect(m.uiState == .compromised)
    }

    @Test
    func compromisedTakesPriorityOverError() {
        let m = model(state: .outOfRange)
        m.deviceDidFail(m.device, with: .connectionFailed(error: nil))
        m.deviceDidDetectTampering(m.device)
        #expect(m.uiState == .compromised)
    }

    // MARK: - Failed

    @Test
    func deviceWithErrorHasFailedState() {
        let m = model(state: .outOfRange)
        m.deviceDidFail(m.device, with: .connectionFailed(error: nil))
        if case .failed = m.uiState {
            // correct
        } else {
            Issue.record("Expected .failed, got \(m.uiState)")
        }
    }

    @Test
    func errorTakesPriorityOverConnectionState() {
        let m = model(state: .outOfRange)
        // outOfRange without error → .outOfRange
        #expect(m.uiState == .outOfRange)
        // add an error → .failed regardless
        m.deviceDidFail(m.device, with: .connectionFailed(error: nil))
        if case .failed = m.uiState {
            // correct
        } else {
            Issue.record("Expected .failed, got \(m.uiState)")
        }
    }

    // MARK: - Disconnected Subcases

    @Test
    func connectableDeviceIsNotOutOfRange() {
        let m = model(state: .available)
        if case .outOfRange = m.uiState {
            Issue.record("Connectable device should not be outOfRange")
        }
    }

    @Test
    func nonConnectableDeviceIsOutOfRange() {
        let m = model(state: .outOfRange)
        #expect(m.uiState == .outOfRange)
    }
}

