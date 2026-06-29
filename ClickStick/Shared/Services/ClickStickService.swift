//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Foundation
import Observation
import os.log
import SwiftUI

@Observable
@MainActor
final class ClickStickService: CSManagerDelegate {
    private let log = Logger(subsystem: "io.clickstick", category: "ClickStickService")
    private let manager: CSManaging

    // MARK: - Observable State

    private(set) var devices: [DeviceModel] = []
    private(set) var isScanning: Bool = false
    private(set) var bluetoothError: CSError?

    var isDemoMode: Bool {
        didSet {
            manager.isDemoMode = isDemoMode
            syncDevicesFromManager()
        }
    }

    // MARK: - Initialization

    init(manager: CSManaging = CSManager.shared) {
        self.manager = manager
        self.isDemoMode = manager.isDemoMode
        self.manager.delegate = self
        syncDevicesFromManager()
    }

    private func syncDevicesFromManager() {
        let knownDevices = manager
            .knownDevices()
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let existingByID = Dictionary(uniqueKeysWithValues: devices.map { ($0.id, $0) })
        devices = knownDevices.map { device in
            if let existing = existingByID[device.uuid] {
                existing.replaceDevice(device)
                return existing
            }
            return DeviceModel(device: device)
        }
    }

    // MARK: - Methods

    func startScanning() {
        guard !isScanning else { return }
        log.debug("Starting scan")
        manager.delegate = self
        isScanning = true
        bluetoothError = nil
        manager.startScanning()
        syncDevicesFromManager()
    }

    func stopScanning() {
        log.debug("Stopping scan")
        isScanning = false
        manager.stopScanning()
    }

    func device(for id: UUID) -> DeviceModel? {
        devices.first { $0.id == id }
    }

    func reloadDevices() {
        syncDevicesFromManager()
    }

    // MARK: - App lifecycle

    /// Devices that were connected (or connecting) when the app left the foreground,
    /// so they can be transparently reconnected once it returns.
    private var pendingReconnectDeviceIDs: Set<UUID> = []
    private var shouldResumeScanningOnForeground = false

    /// Releases all BLE resources when the app leaves the foreground. CoreBluetooth
    /// connections are per-process, so the Share Extension cannot use a peripheral while
    /// the main app still holds it — we must disconnect and stop scanning on backgrounding.
    func handleEnteredBackground() {
        shouldResumeScanningOnForeground = isScanning
        pendingReconnectDeviceIDs = Set(
            devices.filter { $0.isConnected || $0.isConnecting }.map(\.id)
        )

        for device in devices {
            switch device.connectionState {
            case .connectedAuthorized, .connectedUnauthorized:
                log.debug("Disconnecting \(device.id) for backgrounding")
                device.disconnect()
            case .disconnected, .serviceDiscovery:
                break
            }
        }
        stopScanning()
    }

    /// Resumes scanning and reconnects any devices that were connected before backgrounding.
    /// Reconnection completes asynchronously as scanning rediscovers each peripheral.
    func handleWillEnterForeground() {
        if shouldResumeScanningOnForeground || !pendingReconnectDeviceIDs.isEmpty {
            startScanning()
        }
        reconnectPendingDevicesIfPossible()
    }

    /// Reconnects pending devices that scanning has rediscovered and are reachable.
    private func reconnectPendingDevicesIfPossible() {
        guard !pendingReconnectDeviceIDs.isEmpty else { return }
        for device in devices where pendingReconnectDeviceIDs.contains(device.id) {
            guard device.connectionState == .disconnected, device.isConnectable else { continue }
            log.debug("Reconnecting \(device.id) after returning to foreground")
            device.connect()
            pendingReconnectDeviceIDs.remove(device.id)
        }
    }

    #if DEBUG
    func setPreviewScanning(_ isScanning: Bool) {
        self.isScanning = isScanning
    }
    #endif

    // MARK: - CSManagerDelegate

    nonisolated func didDiscover(device: CSDevice, in manager: CSManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            log.debug("Discovered device: \(device.uuid)")
            // Clear any previous Bluetooth error since discovery means BT is working
            if bluetoothError != nil {
                bluetoothError = nil
            }
            syncDevicesFromManager()
            reconnectPendingDevicesIfPossible()
        }
    }

    nonisolated func didFail(with error: CSError, in manager: CSManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            log.error("Manager failed: \(error.localizedDescription)")
            bluetoothError = error
            isScanning = false
        }
    }
}
