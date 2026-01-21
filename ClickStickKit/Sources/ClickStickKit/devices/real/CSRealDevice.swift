//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import CoreBluetooth
import Foundation
import os.log

internal final class CSRealDevice: CSDevice {
    let log = Logger(subsystem: "io.clickstick", category: #file)

    // MARK: Private/protected Properties

    internal unowned var _manager: CSManager
    internal let _peripheral: CBPeripheral

    internal var _serialNumberCharacteristic: CBCharacteristic?
    internal var _firmwareVersionCharacteristic: CBCharacteristic?
    internal var _commandCharacteristic: CBCharacteristic?
    internal var _statusCharacteristic: CBCharacteristic?

    /// Maximum outgoing packet size, as negotiated with the device.
    override internal var _maxOutgoingPacketSize: Int {
        _peripheral.maximumWriteValueLength(for: .withResponse)
    }

    // MARK: Internal API

    init(peripheral: CBPeripheral, manager: CSManager) {
        self._peripheral = peripheral
        self._manager = manager
        super.init(uuid: _peripheral.identifier)

        self._peripheral.delegate = self
    }

    // MARK: - CSDevice overrides

    override func _startConnection() {
        _manager.withCentralManager { centralManager in
            centralManager.connect(_peripheral, options: nil)
        }
    }

    override func _startServiceDiscovery() {
        _resetCharacteristics()
        _peripheral.discoverServices([
            CSUUID.deviceInformationService,
            CSUUID.clickStickService
        ])
    }

    /// Returns the latest value of device's status channel, if connected and available.
    override func _readDeviceStatusChannel() -> Data? {
        return _statusCharacteristic?.value
    }

    override func _requestStatusUpdate() {
        guard let _statusCharacteristic else {
            log.warning("Requested status update before service discovery completed")
            assertionFailure()
            return
        }
        _peripheral.readValue(for: _statusCharacteristic)
    }

    /// Writes a raw packet to device's command channel.
    /// `_didWriteToCommandChannel()` once the write is confirmed or failed.
    override func _writeToCommandChannel(_ packet: Data) {
        assert(packet.count <= _maxOutgoingPacketSize, "Outgoing packet too large")
        guard let _commandCharacteristic else {
            log.error("Failed to write command channel, the characteristic is nil")
            assertionFailure()
            return
        }
        _peripheral.writeValue(packet, for: _commandCharacteristic, type: .withResponse)
    }

    override func _endConnection() {
        _manager.withCentralManager { centralManager in
            centralManager.cancelPeripheralConnection(_peripheral)
        }
    }

    override func _requestRSSIRefresh() {
        guard _peripheral.state == .connected else { // `readRSSI()` won't work when disconnected
            return
        }
        _peripheral.readRSSI()
    }

    func _resetCharacteristics() {
        _serialNumberCharacteristic = nil
        _firmwareVersionCharacteristic = nil
        _commandCharacteristic = nil
        _statusCharacteristic = nil
    }
}
