//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Foundation
import Observation
import os.log

/// Observable wrapper for CSDevice to bridge ClickStickKit to SwiftUI
@Observable
final class DeviceModel: Identifiable {
    private let log = Logger(subsystem: "io.clickstick", category: "DeviceModel")
    private let observer: DeviceObserver

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

    // MARK: - Cached Settings (to avoid keychain I/O during render)

    private(set) var cachedAlias: String?
    private(set) var isKnownDevice: Bool

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
        if let alias = cachedAlias, !alias.isEmpty {
            return alias
        }
        return name
    }

    }

    // MARK: - Initialization

    init(device: CSDevice) {
        self.device = device
        self.observer = DeviceObserver()

        // Initialize from current device state
        self.name = device.name
        self.rssi = device.rssi
        self.connectionState = device.connectionState
        self.features = device.features
        self.needsAuthentication = false
        self.lastError = device.lastError
        self.isConnectable = device.isConnectable
        self.isDemoDevice = device.isDemoDevice

        // Initialize cached settings
        self.cachedAlias = Self.loadCachedAlias(for: device.uuid)
        self.isKnownDevice = Self.checkIsKnownDevice(for: device.uuid, isDemoDevice: device.isDemoDevice)

        observer.owner = self
        device.addObserver(observer)
    }

    deinit {
        device.removeObserver(observer)
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

    // MARK: - Settings Cache

    func refreshSettingsCache() {
        cachedAlias = Self.loadCachedAlias(for: device.uuid)
        isKnownDevice = Self.checkIsKnownDevice(for: device.uuid, isDemoDevice: device.isDemoDevice)
    }

    private static func loadCachedAlias(for uuid: UUID) -> String? {
        guard let settings = try? CSDeviceSettingsManager.loadSettings(for: uuid) else {
            return nil
        }
        return settings.deviceAlias
    }

    private static func checkIsKnownDevice(for uuid: UUID, isDemoDevice: Bool) -> Bool {
        isDemoDevice || CSDeviceSettingsManager.hasSettings(for: uuid)
    }

    // MARK: - CSDeviceObserver

    fileprivate func deviceDidUpdateProperties(_ device: CSDevice) {
        name = device.name
        rssi = device.rssi
        isConnectable = device.isConnectable
    }

    fileprivate func deviceConnectionStateUpdated(_ device: CSDevice) {
        connectionState = device.connectionState
        features = device.features
        lastError = device.lastError
    }

    fileprivate func deviceNeedsAuthentication(_ device: CSDevice) {
        needsAuthentication = true
        connectionState = device.connectionState
    }

    fileprivate func deviceDidFail(_ device: CSDevice, with error: CSError) {
        lastError = error
        connectionState = device.connectionState
        log.error("Device failed: \(error.localizedDescription)")
        NotificationCenter.default.post(
            name: .deviceDidFail,
            object: nil,
            userInfo: ["deviceID": device.uuid, "error": error]
        )
    }

    fileprivate func deviceDidDisconnect(_ device: CSDevice, with error: CSError?) {
        connectionState = .disconnected
        features = []
        if let error {
            lastError = error
        }
    }
}

private final class DeviceObserver: CSDeviceObserver {
    weak var owner: DeviceModel?

    func deviceDidUpdateProperties(_ device: CSDevice) {
        Task { @MainActor in
            owner?.deviceDidUpdateProperties(device)
        }
    }

    func deviceConnectionStateUpdated(_ device: CSDevice) {
        Task { @MainActor in
            owner?.deviceConnectionStateUpdated(device)
        }
    }

    func deviceNeedsAuthentication(_ device: CSDevice) {
        Task { @MainActor in
            owner?.deviceNeedsAuthentication(device)
        }
    }

    func deviceDidFail(_ device: CSDevice, with error: CSError) {
        Task { @MainActor in
            owner?.deviceDidFail(device, with: error)
        }
    }

    func deviceDidDisconnect(_ device: CSDevice, with error: CSError?) {
        Task { @MainActor in
            owner?.deviceDidDisconnect(device, with: error)
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
