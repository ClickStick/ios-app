//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Foundation
import Observation
import os.log

/// Drives the Share Extension UI: device discovery/selection and sending the shared text.
/// Reuses `DeviceModel` (shared with the main app target) on top of `CSManager`.
@Observable
@MainActor
final class ShareExtensionViewModel: CSManagerDelegate {
    enum Phase: Equatable {
        case input
        case sending(sent: Int, total: Int)
        case sent
    }

    private let log = Logger(subsystem: "io.clickstick", category: "ShareExtensionViewModel")
    private let manager: CSManager

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

    private var deviceModels: [UUID: DeviceModel] = [:]
    private var sendTask: Task<Void, Never>?
    private var persistsPreferences = false
    private var autoScans = true

    // MARK: - Init

    init(sharedText: String, manager: CSManager = .shared) {
        self.text = sharedText
        self.manager = manager
        self.selectedLayout = .fromSystemLocale()
        self.selectedOS = .windows

        manager.delegate = self
        syncDevicesFromManager()
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
        deviceModels.values
            .filter { $0.isKnownDevice }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    var selectedDevice: DeviceModel? {
        guard let id = selectedDeviceID else { return nil }
        return deviceModels[id]
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
        manager.delegate = self
        manager.startScanning()
        connectSelectedDeviceIfNeeded()
    }

    func onDisappear() {
        manager.stopScanning()
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

    private func connectSelectedDeviceIfNeeded() {
        guard let device = selectedDevice, !device.isConnected, device.uiState != .outOfRange else { return }
        device.connect()
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

    // MARK: - Manager sync

    private func syncDevicesFromManager() {
        let knownDevices = manager.knownDevices()
        for device in knownDevices where deviceModels[device.uuid] == nil {
            deviceModels[device.uuid] = DeviceModel(device: device)
        }
        let knownUUIDs = Set(knownDevices.map(\.uuid))
        for uuid in deviceModels.keys where !knownUUIDs.contains(uuid) {
            deviceModels.removeValue(forKey: uuid)
        }
    }

    // MARK: - CSManagerDelegate

    nonisolated func didDiscover(device: CSDevice, in manager: CSManager) {
        Task { @MainActor in
            syncDevicesFromManager()
            if selectedDeviceID == nil {
                autoSelectDevice()
                applyPreferencesFromSelectedDevice()
            }
            connectSelectedDeviceIfNeeded()
        }
    }

    nonisolated func didFail(with error: CSError, in manager: CSManager) {
        Task { @MainActor in
            self.log.error("Manager failed: \(error.localizedDescription)")
        }
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
        self.manager = .shared
        self.selectedLayout = layout
        self.selectedOS = targetOS
        self.autoScans = false
        if let device {
            self.deviceModels = [device.id: device]
            self.selectedDeviceID = device.id
        }
        self.phase = phase
    }
#endif
}
