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
    }

    private let log = Logger(subsystem: "io.clickstick", category: "ShareExtensionViewModel")
    private let service: ClickStickService?

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

    private var previewDevices: [DeviceModel]?
    private var sendTask: Task<Void, Never>?
    private var persistsPreferences = false
    private var autoScans = true

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
        (previewDevices ?? service?.devices ?? [])
            .filter { $0.isKnownDevice }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    var selectedDevice: DeviceModel? {
        guard let id = selectedDeviceID else { return nil }
        return devices.first { $0.id == id }
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
        guard autoScans else { return }
        service?.startScanning()
        connectSelectedDeviceIfNeeded()
    }

    func onDisappear() {
        service?.stopScanning()
    }

    // MARK: - Device selection

    func select(_ device: DeviceModel) {
        selectedDeviceID = device.id
        applyPreferencesFromSelectedDevice()
        connectSelectedDeviceIfNeeded()
    }

    private func autoSelectDevice() {
        if let connected = devices.first(where: { $0.isConnected }) {
            selectedDeviceID = connected.id
        } else {
            selectedDeviceID = devices.first?.id
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
        if selectedDevice == nil {
            autoSelectDevice()
            applyPreferencesFromSelectedDevice()
        }
        connectSelectedDeviceIfNeeded()
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
                self.phase = .input
            }
            self.sendTask = nil
        }
    }

    func cancelSending() {
        sendTask?.cancel()
        sendTask = nil
        phase = .input
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

#if DEBUG
    /// Preview-only initializer: injects a device and phase without touching `CSManager`.
    init(
        previewText: String,
        device: DeviceModel?,
        phase: Phase = .input,
        layout: CSKeyboardLayout = .usQWERTY,
        targetOS: CSTypingOS = .windows
    ) {
        self.text = previewText
        self.service = nil
        self.selectedLayout = layout
        self.selectedOS = targetOS
        self.autoScans = false
        self.previewDevices = device.map { [$0] } ?? []
        self.selectedDeviceID = device?.id
        self.phase = phase
    }
#endif
}
