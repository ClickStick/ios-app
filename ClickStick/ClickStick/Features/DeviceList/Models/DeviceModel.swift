//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Foundation
import Observation
import os.log

/// Observable wrapper for CSDevice to bridge ClickStickKit to SwiftUI
@Observable
final class DeviceModel: Identifiable, CSDeviceObserver {
    private let log = Logger(subsystem: "io.clickstick", category: "DeviceModel")

    // MARK: - Underlying Device

    let device: CSDevice

    // MARK: - Observable State (mirrored from CSDevice)

    private(set) var name: String
    private(set) var rssi: Int
    private(set) var connectionState: CSDevice.ConnectionState
    private(set) var features: [CSDeviceFeature]
    private(set) var needsAuthentication: Bool
    private(set) var lastError: CSError?
    private(set) var isConnectable: Bool
    private(set) var isDemoDevice: Bool

    // MARK: - Identifiable

    var id: UUID { device.uuid }

    // MARK: - Computed Properties

    var isConnected: Bool {
        connectionState == .connectedAuthorized
    }

    var isConnecting: Bool {
        connectionState == .serviceDiscovery || connectionState == .connectedUnauthorized
    }

    var displayName: String {
        // Check for saved alias in settings
        if let settings = try? CSDeviceSettingsManager.loadSettings(for: device.uuid),
           let alias = settings.deviceAlias, !alias.isEmpty {
            return alias
        }
        return name
    }

    var signalStrength: SignalStrength {
        SignalStrength(rssi: rssi)
    }

    // MARK: - Initialization

    init(device: CSDevice) {
        self.device = device

        // Initialize from current device state
        self.name = device.name
        self.rssi = device.rssi
        self.connectionState = device.connectionState
        self.features = device.features
        self.needsAuthentication = false
        self.lastError = device.lastError
        self.isConnectable = device.isConnectable
        self.isDemoDevice = device.isDemoDevice

        // Register as observer
        device.addObserver(self)
    }

    deinit {
        device.removeObserver(self)
    }

    // MARK: - Public API

    func connect() {
        guard connectionState == .disconnected else { return }

        // Try to load auth key from keychain
        let authKey: CSAppAuthKey?
        if let settings = try? CSDeviceSettingsManager.loadSettings(for: device.uuid) {
            authKey = settings.appAuthKey
        } else if device.isDemoDevice {
            authKey = .demo
        } else {
            authKey = nil
        }

        needsAuthentication = false
        lastError = nil
        device.connect(appAuthKey: authKey)
    }

    func connect(with authKey: CSAppAuthKey) {
        needsAuthentication = false
        lastError = nil
        device.connect(appAuthKey: authKey)
    }

    func disconnect() {
        guard connectionState != .disconnected else { return }
        device.disconnect()
    }

    func sendText(_ text: String, layout: CSKeyboardLayout, completion: CSCommandCompletion? = nil) {
        guard isConnected else { return }
        device.sendTypeCommands(text: text, layout: layout, completion: completion)
    }

    func sendMouseClick(button: CSMouseButton, completion: CSCommandCompletion? = nil) {
        guard isConnected else { return }
        device.sendMouseClick(button: button, completion: completion)
    }

    func sendMouseMove(dx: Int8, dy: Int8, completion: CSCommandCompletion? = nil) {
        guard isConnected else { return }
        device.sendMouseMove(dx: dx, dy: dy, completion: completion)
    }

    func sendMouseScroll(vertical: Int8, horizontal: Int8, completion: CSCommandCompletion? = nil) {
        guard isConnected else { return }
        device.sendMouseScroll(vertical: vertical, horizontal: horizontal, completion: completion)
    }

    // MARK: - CSDeviceObserver

    func deviceDidUpdateProperties(_ device: CSDevice) {
        name = device.name
        rssi = device.rssi
        isConnectable = device.isConnectable
    }

    func deviceConnectionStateUpdated(_ device: CSDevice) {
        connectionState = device.connectionState
        features = device.features
        lastError = device.lastError
    }

    func deviceNeedsAuthentication(_ device: CSDevice) {
        needsAuthentication = true
        connectionState = device.connectionState
    }

    func deviceDidFail(_ device: CSDevice, with error: CSError) {
        lastError = error
        connectionState = device.connectionState
        log.error("Device failed: \(error.localizedDescription)")
        NotificationCenter.default.post(
            name: .deviceDidFail,
            object: nil,
            userInfo: ["deviceID": device.uuid, "error": error]
        )
    }

    func deviceDidDisconnect(_ device: CSDevice, with error: CSError?) {
        connectionState = .disconnected
        features = []
        if let error {
            lastError = error
        }
    }
}

// MARK: - Signal Strength

extension DeviceModel {
    enum SignalStrength: Int, CaseIterable {
        case excellent
        case good
        case fair
        case weak
        case none

        init(rssi: Int) {
            switch rssi {
            case -50...0:
                self = .excellent
            case -60..<(-50):
                self = .good
            case -70..<(-60):
                self = .fair
            case -80..<(-70):
                self = .weak
            default:
                self = .none
            }
        }

        var iconName: String {
            switch self {
            case .excellent: "wifi"
            case .good: "wifi"
            case .fair: "wifi"
            case .weak: "wifi.exclamationmark"
            case .none: "wifi.slash"
            }
        }

        var barsCount: Int {
            switch self {
            case .excellent: 4
            case .good: 3
            case .fair: 2
            case .weak: 1
            case .none: 0
            }
        }
    }
}

// MARK: - Hashable/Equatable

extension DeviceModel: Hashable {
    static func == (lhs: DeviceModel, rhs: DeviceModel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension Notification.Name {
    static let deviceDidFail = Notification.Name("deviceDidFail")
}
