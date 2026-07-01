//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Foundation
import Observation
import os.log

struct ShareExtensionDeviceChangeToken: Equatable {
    let id: UUID
    let state: DeviceUIState
    let isConnectable: Bool
    let connectionState: CSDevice.ConnectionState
}

/// Drives the Share Extension UI: device discovery/selection and sending the shared text.
/// Reuses the main app's `ClickStickService` so manager/device synchronization stays identical.
@Observable
@MainActor
final class ShareExtensionViewModel {
    enum Phase: Equatable {
        case input
        case sending(sent: Int, total: Int)
        case sent
        case connectionLost
    }

    private let log = Logger(subsystem: "io.clickstick", category: "ShareExtensionViewModel")
    private let service: ClickStickService

    // MARK: - State

    let text: String

    var selectedLayout: CSKeyboardLayout {
        didSet { persistPreferencesIfNeeded() }
    }
    var selectedOS: CSTypingOS {
        didSet { persistPreferencesIfNeeded() }
    }

    private(set) var phase: Phase = .input
    private(set) var selectedDeviceID: UUID?
    private(set) var selectedDevice: DeviceModel? = nil

    private var sendTask: Task<Void, Never>?
    private var persistsPreferences = false
    private var didRequestTeardown = false

    // MARK: - Init

    init(sharedText: String, manager: CSManaging = CSManager.shared) {
        self.text = sharedText
        self.service = ClickStickService(manager: manager)
        self.selectedLayout = .fromSystemLocale()
        self.selectedOS = .windows

        autoSelectDevice()
        applyPreferencesFromSelectedDevice()
        persistsPreferences = true
    }

    isolated deinit {
        sendTask?.cancel()
    }

    // MARK: - Derived

    /// Known (paired) devices, sorted by display name.
    var devices: [DeviceModel] {
        service.devices
            .filter { $0.isKnownDevice }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    var characterCount: Int { text.count }

    /// Send is only possible with a connected device and non-empty text, while in the input phase.
    var canSend: Bool {
        guard case .input = phase else { return false }
        guard let device = selectedDevice, device.isConnected else { return false }
        return !text.isEmpty
    }

    // MARK: - Lifecycle

    func onAppear() {
        performWhileActive {
            service.startScanning()
            connectSelectedDeviceIfNeeded()
        }
    }

    func onDisappear() {
        tearDown()
    }

    func tearDown() {
        guard !didRequestTeardown else { return }
        didRequestTeardown = true

        sendTask?.cancel()
        sendTask = nil
        disconnectActiveDevices()
        service.stopScanning()
    }

    private func performWhileActive(_ operation: () -> Void) {
        guard !didRequestTeardown else { return }
        operation()
    }

    private var devicesToDisconnectOnTeardown: [DeviceModel] {
        var devices = service.devices
        if let selectedDevice, !devices.contains(where: { $0.id == selectedDevice.id }) {
            devices.append(selectedDevice)
        }
        return devices
    }

    private func disconnectActiveDevices() {
        for device in devicesToDisconnectOnTeardown where device.connectionState != .disconnected {
            device.disconnect()
        }
    }

    // MARK: - Device selection

    func select(_ device: DeviceModel) {
        performWhileActive {
            selectedDeviceID = device.id
            selectedDevice = device
            applyPreferencesFromSelectedDevice()
            connectSelectedDeviceIfNeeded()
        }
    }

    private func autoSelectDevice() {
        if let connected = devices.first(where: { $0.isConnected }) {
            selectedDeviceID = connected.id
            selectedDevice = connected
        } else if let first = devices.first {
            selectedDeviceID = first.id
            selectedDevice = first
        } else {
            selectedDeviceID = nil
            selectedDevice = nil
        }
    }

    var deviceListChangeToken: [ShareExtensionDeviceChangeToken] {
        devices.map {
            ShareExtensionDeviceChangeToken(
                id: $0.id,
                state: $0.uiState,
                isConnectable: $0.isConnectable,
                connectionState: $0.connectionState
            )
        }
    }

    func devicesDidChange() {
        performWhileActive {
            if let id = selectedDeviceID {
                selectedDevice = devices.first { $0.id == id }
            }
            if selectedDevice == nil {
                autoSelectDevice()
                applyPreferencesFromSelectedDevice()
            }
            connectSelectedDeviceIfNeeded()
        }
    }

    private func connectSelectedDeviceIfNeeded() {
        guard let device = selectedDevice else { return }
        switch device.uiState {
        case .available, .weakSignal:
            device.connect()
        default:
            break
        }
    }

    // MARK: - Sending

    func send() {
        performWhileActive {
            guard canSend, let device = selectedDevice else { return }
            let total = text.count
            guard total > 0 else { return }

            phase = .sending(sent: 0, total: total)
            log.info("Sending \(total) characters via Share Extension")

            sendTask = Task { [weak self] in
                guard let self else { return }
                do {
                    try await device.sendText(text, layout: selectedLayout, targetOS: selectedOS) { sent, total in
                        if case .sending = self.phase {
                            self.phase = .sending(sent: sent, total: total)
                        }
                    }
                    self.phase = .sent
                } catch is CancellationError {
                    self.phase = .input
                } catch {
                    self.log.error("Share Extension send failed: \(error.localizedDescription)")
                    self.phase = .connectionLost
                }
                self.sendTask = nil
            }
        }
    }

    func cancelSending() {
        sendTask?.cancel()
        sendTask = nil
        phase = .input
    }

    func dismissConnectionLost() {
        phase = .input
    }

    func retryAfterConnectionLost() {
        phase = .input
        connectSelectedDeviceIfNeeded()
    }

    // MARK: - Preferences

    private func applyPreferencesFromSelectedDevice() {
        guard let device = selectedDevice else { return }
        persistsPreferences = false
        selectedLayout = device.textEntryKeyboardLayout
        selectedOS = device.textEntryTargetOS
        persistsPreferences = true
    }

    private func persistPreferencesIfNeeded() {
        guard persistsPreferences else { return }
        selectedDevice?.saveTextEntryPreferences(layout: selectedLayout, targetOS: selectedOS)
    }
}
