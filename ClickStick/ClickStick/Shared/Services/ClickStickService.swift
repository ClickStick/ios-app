//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Foundation
import Observation
import os.log

@Observable
final class ClickStickService: CSManagerDelegate {
    private let log = Logger(subsystem: "io.clickstick", category: "ClickStickService")
    private let manager: CSManager

    // MARK: - Observable State

    private(set) var devices: [DeviceModel] = []
    private(set) var isScanning: Bool = false
    private(set) var bluetoothError: CSError?

    var isDemoMode: Bool {
        didSet {
            manager.isDemoMode = isDemoMode
            if isDemoMode {
                startScanning()
            }
        }
    }

    // MARK: - Initialization

    init(manager: CSManager = .shared) {
        self.manager = manager
        self.isDemoMode = manager.isDemoMode
        self.manager.delegate = self
    }

    // MARK: - Public API

    func startScanning() {
        log.debug("Starting scan")
        isScanning = true
        bluetoothError = nil
        manager.startScanning()
    }

    func stopScanning() {
        log.debug("Stopping scan")
        isScanning = false
        manager.stopScanning()
    }

    func device(for id: UUID) -> DeviceModel? {
        devices.first { $0.id == id }
    }

    // MARK: - CSManagerDelegate

    func didDiscover(device: CSDevice, in manager: CSManager) {
        log.debug("Discovered device: \(device.uuid)")

        // Check if we already have this device
        if devices.contains(where: { $0.id == device.uuid }) {
            return
        }

        let deviceModel = DeviceModel(device: device)
        devices.append(deviceModel)
    }

    func didFail(with error: CSError, in manager: CSManager) {
        log.error("Manager failed: \(error.localizedDescription)")
        bluetoothError = error
        isScanning = false
    }
}
