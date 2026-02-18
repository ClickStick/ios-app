//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Foundation
import Observation
import os.log

/// ViewModel for handling Share Extension text typing
@Observable
@MainActor
final class ShareExtensionViewModel: TypeTextViewModel, CSManagerDelegate {
    private let log = Logger(subsystem: "io.clickstick", category: "ShareExtensionViewModel")

    // MARK: - Dependencies

    private let manager: CSManager
    private let premiumService: PremiumService

    // MARK: - TypeTextViewModel Conformance

    let text: String
    var selectedLayout: CSKeyboardLayout
    var selectedDeviceID: UUID?
    var isTextVisible: Bool = false
    var isSending: Bool = false
    var connectionError: String?

    // MARK: - Additional State

    var isScanning: Bool = false

    // MARK: - Device Management

    private var deviceModels: [UUID: DeviceModel] = [:]

    // MARK: - Computed Properties

    /// Available devices (only known/paired devices)
    var devices: [DeviceModel] {
        deviceModels.values
            .filter { $0.isKnownDevice }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    /// Whether there are no known devices
    var hasNoDevices: Bool {
        devices.isEmpty
    }

    // MARK: - Initialization

    init(sharedText: String, manager: CSManager = .shared) {
        self.text = sharedText
        self.manager = manager
        self.premiumService = PremiumService(autoSyncStoreKit: false)
        self.selectedLayout = CSKeyboardLayout.fromSystemLocale()

        manager.delegate = self
        syncDevicesFromManager()
        autoSelectDevice()
    }

    // MARK: - Device Sync

    private func syncDevicesFromManager() {
        let knownDevices = manager.knownDevices()

        for device in knownDevices {
            if deviceModels[device.uuid] == nil {
                deviceModels[device.uuid] = DeviceModel(device: device)
            }
        }

        // Remove devices that are no longer known
        let knownUUIDs = Set(knownDevices.map { $0.uuid })
        for uuid in deviceModels.keys where !knownUUIDs.contains(uuid) {
            deviceModels.removeValue(forKey: uuid)
        }
    }

    private func autoSelectDevice() {
        // First, try to select a connected device
        if let connectedDevice = devices.first(where: { $0.isConnected }) {
            selectedDeviceID = connectedDevice.id
            return
        }

        // Otherwise, select the first known device
        if let firstDevice = devices.first {
            selectedDeviceID = firstDevice.id
        }
    }

    // MARK: - Actions

    /// Start scanning for devices
    func startScanning() {
        log.debug("Starting BLE scan")
        isScanning = true
        manager.startScanning()
    }

    /// Stop scanning for devices
    func stopScanning() {
        log.debug("Stopping BLE scan")
        isScanning = false
        manager.stopScanning()
    }

    /// Connect to the selected device
    func connectDevice() {
        guard let device = selectedDevice, !device.isConnected else { return }
        connectionError = nil
        log.info("Connecting to device: \(device.displayName)")
        device.connect()
    }

    /// Send the text to the device
    func sendText() async -> Bool {
        guard let device = selectedDevice, canType else { return false }

        isSending = true
        let byteCount = text.utf8.count
        let decision = premiumService.makeSendDecision(for: byteCount)
        log.info("Sending \(self.characterCount) characters via Share Extension (premium: \(self.premiumService.isPremium))")

        do {
            try await device.sendText(text, layout: selectedLayout, speed: decision.speed)
            premiumService.recordCompletedSend(decision)
            log.info("Share Extension text sent successfully")
            isSending = false
            return true
        } catch {
            log.error("Share Extension text failed: \(error.localizedDescription)")
            connectionError = error.localizedDescription
            isSending = false
            return false
        }
    }

    // MARK: - CSManagerDelegate

    nonisolated func didDiscover(device: CSDevice, in manager: CSManager) {
        Task { @MainActor in
            log.debug("Discovered device: \(device.uuid)")
            syncDevicesFromManager()

            // Auto-select if we don't have a selection yet
            if selectedDeviceID == nil {
                autoSelectDevice()
            }
        }
    }

    nonisolated func didFail(with error: CSError, in manager: CSManager) {
        Task { @MainActor in
            log.error("Manager failed: \(error.localizedDescription)")
            connectionError = error.localizedDescription
            isScanning = false
        }
    }
}

// MARK: - CSKeyboardLayout Extension

extension CSKeyboardLayout {
    /// Attempts to detect the appropriate keyboard layout from the system locale
    static func fromSystemLocale() -> CSKeyboardLayout {
        guard let languageCode = Locale.current.language.languageCode?.identifier else {
            return .usQWERTY
        }

        switch languageCode {
        case "de":
            return .deQWERTZ
        case "fr":
            return .frAZERTY_Classic
        default:
            return .usQWERTY
        }
    }
}
