//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Foundation
import Observation
import os.log

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
    /// True when scanning was started solely to rediscover devices for reconnection, so it
    /// can be stopped again if those devices never reappear within `reconnectTimeout`.
    private var didAutoStartScanForReconnect = false
    private var reconnectTimeoutTask: Task<Void, Never>?
    private static let reconnectTimeout: TimeInterval = 10.0

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
            case .connectedAuthorized, .connectedUnauthorized, .serviceDiscovery:
                // Includes `.serviceDiscovery`: a connecting device already holds the BLE
                // link, so it must be released too or the Share Extension can't reach it.
                log.debug("Disconnecting \(device.id) for backgrounding")
                device.disconnect()
            case .disconnected:
                break
            }
        }
        stopScanning()
    }

    /// Resumes scanning and reconnects any devices that were connected before backgrounding.
    /// Reconnection completes asynchronously as scanning rediscovers each peripheral.
    func handleWillEnterForeground() {
        let needsReconnect = !pendingReconnectDeviceIDs.isEmpty
        if shouldResumeScanningOnForeground || needsReconnect {
            didAutoStartScanForReconnect = needsReconnect && !shouldResumeScanningOnForeground && !isScanning
            startScanning()
        }
        reconnectPendingDevicesIfPossible()
        if !pendingReconnectDeviceIDs.isEmpty {
            startReconnectTimeout()
        }
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
        if pendingReconnectDeviceIDs.isEmpty {
            // Every device was rediscovered and reconnected; the give-up timer is no longer
            // needed (we leave scanning as-is — it's governed by the visible screen again).
            reconnectTimeoutTask?.cancel()
            reconnectTimeoutTask = nil
            didAutoStartScanForReconnect = false
        }
    }

    /// Stops waiting on devices that never reappeared, and stops a scan we started only for
    /// reconnection so it doesn't keep draining the radio with nothing left to find.
    private func startReconnectTimeout() {
        reconnectTimeoutTask?.cancel()
        reconnectTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.reconnectTimeout))
            guard let self, !Task.isCancelled else { return }
            self.reconnectTimeoutTask = nil
            guard !self.pendingReconnectDeviceIDs.isEmpty else { return }
            self.log.debug("Reconnect timed out for \(self.pendingReconnectDeviceIDs.count) device(s)")
            self.pendingReconnectDeviceIDs.removeAll()
            if self.didAutoStartScanForReconnect {
                self.stopScanning()
            }
            self.didAutoStartScanForReconnect = false
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
