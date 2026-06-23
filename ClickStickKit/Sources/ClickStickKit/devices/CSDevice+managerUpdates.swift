//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import Foundation
import os.log

/// Connection status updates called by CSManager
protocol CSManagerUpdateableDevice {
    func csManagerDidUpdateProperties(name: String, rssi: Int, isConnectable: Bool)
    func csManagerDidConnect()
    func csManagerDidFailToConnect(with error: CSError)
    func csManagerDidDisconnect(with error: CSError?)
}

private let log = Logger(subsystem: "io.clickstick", category: #file)
extension CSDevice: CSManagerUpdateableDevice {

    /// Called by `CSManager` after receiving advertisement for this device
    internal func csManagerDidUpdateProperties(name: String, rssi: Int, isConnectable: Bool) {
        self._name = name
        self._rssi = rssi
        self._isConnectable = isConnectable
        self._lastSeen = Date.now
        _notifyObservers { $0.deviceDidUpdateProperties(self) }
    }

    /// Called by `CSManager` once radio connection is established by `_startConnection`.
    internal func csManagerDidConnect() {
        assert(_connectionState == .serviceDiscovery)
        log.debug("Did connect to \(self.uuid)")
        _lastError = nil
        _startServiceDiscovery()
    }

    /// Called by `CSManager` once connection to this device fails.
    internal func csManagerDidFailToConnect(with error: CSError) {
        log.debug("Did fail to connect to \(self.uuid): \(error)")
        _handleConnectionFailure(with: error)
    }

    /// Called by `CSManager` once this device is disconnected.
    internal func csManagerDidDisconnect(with error: CSError?) {
        log.debug("Did disconnect from \(self.uuid)")
        _finalizeInFlightCommandWithError(error ?? CSError.connectionFailed(error: nil), proceed: false)
        _features = []
        _lastError = error
        _connectionState = .disconnected
        _notifyObservers { $0.deviceDidDisconnect(self, with: error) }
    }
}
