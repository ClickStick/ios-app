//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

#if DEBUG
import Foundation

public extension CSDevice {
    /// Display states used to build SwiftUI preview devices.
    enum PreviewState {
        case connected
        case available
        case weakSignal
        case connecting
        case outOfRange
    }

    /// Creates a preview-only device fixed in a given display state.
    /// Intended solely for SwiftUI previews — not for production use.
    static func makePreview(name: String, state: PreviewState) -> CSDevice {
        let device = CSMockDevice(uuid: UUID())
        device._name = name
        switch state {
        case .connected:
            device._connectionState = .connectedAuthorized
            device._isConnectable = true
            device._rssi = -48
        case .available:
            device._connectionState = .disconnected
            device._isConnectable = true
            device._rssi = -55
        case .weakSignal:
            device._connectionState = .disconnected
            device._isConnectable = true
            device._rssi = -92
        case .connecting:
            device._connectionState = .serviceDiscovery
            device._isConnectable = true
            device._rssi = -55
        case .outOfRange:
            device._connectionState = .disconnected
            device._isConnectable = false
            device._rssi = -255
        }
        // Pin the RSSI so the periodic refresh timer can't randomize it away
        // (otherwise e.g. a weak-signal device drifts back to full strength).
        device._pinnedRSSI = device._rssi
        return device
    }
}
#endif
