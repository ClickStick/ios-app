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

    // MARK: - Public API

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

    #if DEBUG
    func setPreviewScanning(_ isScanning: Bool) {
        self.isScanning = isScanning
    }
    #endif

    // MARK: - CSManagerDelegate

    nonisolated func didDiscover(device: CSDevice, in manager: CSManager) {
        Task { @MainActor in
            log.debug("Discovered device: \(device.uuid)")
            // Clear any previous Bluetooth error since discovery means BT is working
            if bluetoothError != nil {
                bluetoothError = nil
            }
            syncDevicesFromManager()
        }
    }

    nonisolated func didFail(with error: CSError, in manager: CSManager) {
        Task { @MainActor in
            log.error("Manager failed: \(error.localizedDescription)")
            bluetoothError = error
            isScanning = false
        }
    }
}
