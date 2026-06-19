//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import Foundation

/// A saved device loaded from persisted settings before CoreBluetooth discovers
/// its peripheral. It lets the app show paired devices immediately as out of range.
internal final class CSStoredDevice: CSDevice {
    override internal var _maxOutgoingPacketSize: Int { 20 }

    init(settings: CSDeviceSettings) {
        super.init(uuid: settings.deviceUUID)
        if let alias = settings.deviceAlias, !alias.isEmpty {
            _name = alias
        } else {
            _name = "ClickStick \(settings.deviceUUID.uuidString.suffix(4))"
        }
        _rssi = -255
        _isConnectable = false
    }

    override func _requestRSSIRefresh() {
        // Stored placeholders are not backed by a peripheral yet.
    }

    override func _startConnection() {
        _handleConnectionFailure(with: .connectionFailed(error: nil))
    }

    override func _startServiceDiscovery() {
        _handleConnectionFailure(with: .connectionFailed(error: nil))
    }

    override func _readDeviceStatusChannel() -> Data? {
        nil
    }

    override func _requestStatusUpdate() {
        // Stored placeholders cannot read BLE status.
    }

    override func _writeToCommandChannel(_ packet: Data) {
        _didWriteToCommandChannel(error: .connectionFailed(error: nil))
    }

    override func _endConnection() {
        _handleConnectionFailure(with: .connectionFailed(error: nil))
    }
}
