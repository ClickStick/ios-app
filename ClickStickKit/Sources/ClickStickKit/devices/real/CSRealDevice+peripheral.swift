//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import CoreBluetooth
import CryptoKit
import Foundation

// MARK: - CBPeripheralDelegate
extension CSRealDevice: CBPeripheralDelegate {
    public func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        _name = peripheral.name ?? "?"
        _notifyObservers { $0.deviceDidUpdateProperties(self) }
    }

    public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: (any Error)?) {
        _rssi = RSSI.intValue
        _notifyObservers { $0.deviceDidUpdateProperties(self) }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        assert(_connectionState == .serviceDiscovery)
        if let error {
            _didFailServiceDiscovery(.peripheralError(error))
            return
        }

        _lastError = nil
        guard let services = peripheral.services else {
            log.warning("Discovered services are nil for peripheral \(peripheral.identifier)")
            assertionFailure()
            return
        }

        for service in services {
            switch service.uuid {
            case CSUUID.deviceInformationService:
                peripheral.discoverCharacteristics(
                    [CSUUID.serialNumberCharacteristic, CSUUID.firmwareRevisionCharacteristic],
                    for: service
                )
            case CSUUID.clickStickService:
                peripheral.discoverCharacteristics(
                    [CSUUID.commandCharacteristic, CSUUID.statusCharacteristic],
                    for: service
                )
            default:
                log.warning("Discovered unexpected service \(service.uuid), ignoring")
                return
            }
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        assert(_connectionState == .serviceDiscovery)
        if let error {
            _didFailServiceDiscovery(.peripheralError(error))
            return
        }

        _lastError = nil
        guard let characteristics = service.characteristics,
              characteristics.count > 0
        else {
            log.error("Discovered characteristics are nil for service \(service.uuid) of peripheral \(peripheral.identifier)")
            assertionFailure()
            return
        }
        for characteristic in characteristics {
            switch characteristic.uuid {
            case CSUUID.serialNumberCharacteristic:
                assert(_serialNumberCharacteristic == nil, "serialNumberCharacteristic was already discovered")
                self._serialNumberCharacteristic = characteristic
            case CSUUID.firmwareRevisionCharacteristic:
                assert(_firmwareVersionCharacteristic == nil, "firmwareVersionCharacteristic was already discovered")
                self._firmwareVersionCharacteristic = characteristic
            case CSUUID.commandCharacteristic:
                assert(_commandCharacteristic == nil, "commandCharacteristic was already discovered")
                self._commandCharacteristic = characteristic
            case CSUUID.statusCharacteristic:
                assert(_statusCharacteristic == nil, "statusCharacteristic was already discovered")
                self._statusCharacteristic = characteristic
            default:
                // Not a big deal, so just log
                log.warning("Discovered unexpected characteristic \(characteristic.uuid), ignoring")
            }
        }
        if _areAllCharacteristicsSet() {
            peripheral.setNotifyValue(true, for: _statusCharacteristic!)
            _didDiscoverAllServices()
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        assert(_connectionState != .disconnected)
        if let error {
            log.error("Failed to read characteristic, ignoring. Characteristic UUID: \(characteristic.uuid): \(error)")
            return
        }

        _lastError = nil
        switch characteristic.uuid {
        case CSUUID.statusCharacteristic:
            if let value = characteristic.value,
               value.first == CSDevice.State.initSession.rawValue,
               value.count < 50 { // TODO: prettify
                // TODO: perhaps redundant?
                peripheral.readValue(for: characteristic)
                return
            }
            _didReceiveStatusData(characteristic.value)
        case CSUUID.serialNumberCharacteristic:
            if let data = characteristic.value {
                _serialNumber = String(data: data, encoding: .utf8)
            } else {
                _serialNumber = nil
            }
            _notifyObservers { $0.deviceDidUpdateProperties(self) }
        case CSUUID.firmwareRevisionCharacteristic:
            if let data = characteristic.value {
                _firmwareVersion = String(data: data, encoding: .utf8)
            } else {
                _firmwareVersion = nil
            }
            _notifyObservers { $0.deviceDidUpdateProperties(self) }
        default:
            // Handle other characteristics here, if needed
            break
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        guard characteristic.uuid == CSUUID.commandCharacteristic else {
            assertionFailure("Written to an unexpected characteristic, ignoring")
            return
        }
        if let error {
            _didWriteToCommandChannel(error: .peripheralError(error))
        } else {
            _didWriteToCommandChannel(error: nil)
        }

    }
}

// MARK: Peripheral helpers
extension CSRealDevice {
    internal func _areAllCharacteristicsSet() -> Bool {
        return _serialNumberCharacteristic != nil
            && _firmwareVersionCharacteristic != nil
            && _commandCharacteristic != nil
            && _statusCharacteristic != nil
    }
}
