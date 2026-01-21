//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import CoreBluetooth
import Foundation
import os.log

public protocol CSManagerDelegate: AnyObject {
    func didDiscover(device: CSDevice, in manager: CSManager)
    func didFail(with error: CSError, in manager: CSManager)
}

final public class CSManager: NSObject {
    private let log = Logger(subsystem: "io.clickstick", category: #file)

    // MARK: Public properties

    public static let shared = CSManager()
    public var isDemoMode = false {
        didSet {
            includeDemoDevices(isDemoMode)
        }
    }

    public weak var delegate: CSManagerDelegate?

    // MARK: Private properties

    private let bleQueue = DispatchQueue(label: "io.clickstick.CSManager.ble", qos: .default)
    private let delegateQueue = DispatchQueue.main
    private let demoDevices: [CSDevice] = [
        CSMockDevice(uuid: UUID(uuidString: "4321FD5D-D172-4C21-97A1-A48F20C00001")!),
        CSMockDevice(uuid: UUID(uuidString: "331D5219-3F05-48FA-B7F5-B3395DBF0002")!),
    ]

    private var centralManager: CBCentralManager!

    private var devicesByUUID: [UUID: CSDevice] = [:]
    private var discoveredPeripherals: Set<UUID> = []

    // MARK: Initialization

    override init() {
        super.init()
        initCentralManager()
    }

    private func initCentralManager() {
        switch CBCentralManager.authorization {
        case .allowedAlways:
            log.debug("BLE use is allowed")
        case .restricted, .denied:
            log.debug("BLE is forbidden by the user")
        case .notDetermined:
            log.debug("BLE permission is not determined yet")
        @unknown default:
            fatalError("Unexpected BLE permission")
        }
        self.centralManager = CBCentralManager(delegate: self, queue: bleQueue)
    }
}

// MARK: Public API
extension CSManager {
    public func startScanning() {
        if centralManager.isScanning {
            return
        }
        let state = centralManager.state
        guard state == .poweredOn else {
            log.error("Cannot scan, BLE is not powered on")
            return
        }

        devicesByUUID.removeAll()
        discoveredPeripherals.removeAll()
        
        log.debug("Starting a scan")
        includeDemoDevices(isDemoMode) // re-apply demo mode after cleanup
        centralManager.scanForPeripherals(
            withServices: [
                CSUUID.clickStickService
            ],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true] // required for RSSI updates
        )
    }

    public func stopScanning() {
        if centralManager.isScanning {
            centralManager.stopScan()
        }
    }

    public func getDevice(with uuid: UUID) -> CSDevice? {
        return devicesByUUID[uuid]
    }

    public func knownDevices() -> [CSDevice] {
        return Array(devicesByUUID.values)
    }
}

// MARK: - Error notifications
extension CSManager {
    internal func notifyDeviceDiscovered(_ device: CSDevice) {
        delegateQueue.async { [weak self] in
            guard let self else { return }
            self.delegate?.didDiscover(device: device, in: self)
        }
    }

    internal func notifyFailure(_ error: CSError) {
        delegateQueue.async { [weak self] in
            guard let self else { return }
            self.delegate?.didFail(with: error, in: self)
        }
    }
}

// MARK: - Internal API
extension CSManager {
    /// Provider access to `centralManager` from `CSRealDevice`.
    internal func withCentralManager(_ closure: (CBCentralManager) -> Void) {
        closure(centralManager)
    }

    private func includeDemoDevices(_ include: Bool) {
        if include {
            demoDevices.forEach {
                devicesByUUID[$0.uuid] = $0
                notifyDeviceDiscovered($0)
            }
        } else {
            demoDevices.forEach {
                devicesByUUID.removeValue(forKey: $0.uuid)
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension CSManager: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            log.debug("Central manager state: poweredOn")
            startScanning()
            // Ready to work
        case .poweredOff:
            log.debug("Central manager state: poweredOff")
            notifyFailure(.bluetoothUnavailable(reason: .poweredOff))
        case .unsupported:
            log.error("Central manager state: unsupported")
            notifyFailure(.bluetoothUnavailable(reason: .unsupported))
        case .unauthorized:
            log.error("Central manager state: unauthorized")
            notifyFailure(.bluetoothUnavailable(reason: .permissionDenied))
        case .resetting:
            // TODO: Might need to pause scans or reconnects if they were ongoing.
            log.debug("Central manager state: resetting — temporary loss of BLE. Waiting for recovery...")
        case .unknown:
            log.warning("Central manager state: unknown")
            notifyFailure(.bluetoothUnavailable(reason: .unknown))
        @unknown default:
            let description = String(describing: central.state)
            log.warning("Unexpected central manager state: \(description)")
            notifyFailure(.bluetoothUnavailable(reason: .unknown))
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let uuid = peripheral.identifier

        let rssi = RSSI.intValue
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "?"
        let connectableValue = advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber
        let isConnectable = connectableValue != 0

        if let knownDevice = devicesByUUID[uuid] {
            knownDevice.csManagerDidUpdateProperties(name: name, rssi: rssi, isConnectable: isConnectable)
        } else {
            let newDevice = CSRealDevice(peripheral: peripheral, manager: self)
            discoveredPeripherals.insert(uuid)
            devicesByUUID[uuid] = newDevice
            notifyDeviceDiscovered(newDevice)
            newDevice.csManagerDidUpdateProperties(name: name, rssi: rssi, isConnectable: isConnectable)
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        guard let device = devicesByUUID[peripheral.identifier] else {
            assertionFailure("Connected to an undiscovered device?")
            return
        }
        device.csManagerDidConnect()
    }

    public func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        let csError = CSError.connectionFailed(error: error)
        guard let device = devicesByUUID[peripheral.identifier] as? CSRealDevice else {
            assertionFailure("Failed to connect to an undiscovered device?")
            return
        }
        device.csManagerDidFailToConnect(with: csError)
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        let csError = error.map { CSError.connectionFailed(error: $0) }
        guard let device = devicesByUUID[peripheral.identifier] as? CSRealDevice else {
            // Normal when a device gets stuck, user restarts a scan, and then device disconnects on timeout.
            return
        }
        device.csManagerDidDisconnect(with: csError)
    }
}
