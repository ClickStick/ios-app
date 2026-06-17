//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Foundation
import Observation
import os.log

protocol TextSendingDevice: AnyObject {
    var displayName: String { get }
    var isConnected: Bool { get }

    func sendText(_ text: String, layout: CSKeyboardLayout) async throws

    func sendText(
        _ text: String,
        layout: CSKeyboardLayout,
        onCharacterProgress: @escaping @MainActor (_ sent: Int, _ total: Int) -> Void
    ) async throws
}

/// Observable wrapper for CSDevice to bridge ClickStickKit to SwiftUI
@Observable
final class DeviceModel: Identifiable, CSDeviceObserver, TextSendingDevice {
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
    private(set) var lastErrorTimestamp: Date?
    private(set) var isConnectable: Bool
    private(set) var isDemoDevice: Bool

    /// Set when the device's session data failed to validate (bad signature/MAC),
    /// meaning it may have been tampered with. Surfaced as a "Security warning".
    private(set) var isCompromised: Bool = false

    private var lastRSSIUpdate: Date = .distantPast

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

    /// Returns true if the device was seen recently (within 3 seconds)
    var isFresh: Bool {
        guard let lastSeen = device.lastSeen else { return false }
        return Date.now.timeIntervalSince(lastSeen) < 3.0
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

        // Initialize cached settings
        self.cachedAlias = Self.loadCachedAlias(for: device.uuid)
        self.isKnownDevice = Self.checkIsKnownDevice(for: device.uuid, isDemoDevice: device.isDemoDevice)

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
        isCompromised = false
        device.connect(appAuthKey: authKey)
    }

    func connect(with authKey: CSAppAuthKey) {
        needsAuthentication = false
        lastError = nil
        isCompromised = false
        device.connect(appAuthKey: authKey)
    }

    /// Clears the compromise warning (e.g. when the user chooses to re-pair the device).
    func clearCompromiseWarning() {
        isCompromised = false
    }

    func disconnect() {
        guard connectionState != .disconnected else { return }
        device.disconnect()
    }

    func sendText(_ text: String, layout: CSKeyboardLayout) async throws {
        guard isConnected else { throw CSError.connectionFailed(error: nil) }
        try await sendTypeCommands(text: text, layout: layout)
    }

    /// Sends text one character at a time so progress can be reported and the send can be
    /// cancelled. There is no artificial delay — it is paced only by how fast the device
    /// acknowledges each keystroke. Used by the in-app Text Entry screen.
    func sendText(
        _ text: String,
        layout: CSKeyboardLayout,
        onCharacterProgress: @escaping @MainActor (_ sent: Int, _ total: Int) -> Void
    ) async throws {
        guard isConnected else { throw CSError.connectionFailed(error: nil) }
        let characters = Array(text)
        let total = characters.count
        guard total > 0 else { return }

        for (index, character) in characters.enumerated() {
            try Task.checkCancellation()
            try await sendTypeCommands(text: String(character), layout: layout)
            let sent = index + 1
            await MainActor.run { onCharacterProgress(sent, total) }
        }
    }

    private func sendTypeCommands(text: String, layout: CSKeyboardLayout) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            guard isConnected else {
                continuation.resume(throwing: CSError.connectionFailed(error: nil))
                return
            }
            device.sendTypeCommands(text: text, layout: layout) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
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

    func deviceDidUpdateProperties(_ device: CSDevice) {
        name = device.name
        isConnectable = device.isConnectable
        let now = Date.now
        if now.timeIntervalSince(lastRSSIUpdate) >= 0.4 {
            rssi = device.rssi
            lastRSSIUpdate = now
        }
    }

    func deviceConnectionStateUpdated(_ device: CSDevice) {
        connectionState = device.connectionState
        features = device.features
        lastError = device.lastError
        if device.connectionState == .connectedAuthorized {
            isCompromised = false
        }
    }

    func deviceDidDetectTampering(_ device: CSDevice) {
        isCompromised = true
        connectionState = device.connectionState
        log.error("Device may be compromised: \(self.displayName, privacy: .public)")
    }

    func deviceNeedsAuthentication(_ device: CSDevice) {
        needsAuthentication = true
        connectionState = device.connectionState
    }

    func deviceDidFail(_ device: CSDevice, with error: CSError) {
        lastError = error
        lastErrorTimestamp = Date()
        connectionState = device.connectionState
        log.error("Device failed: \(error.localizedDescription)")
    }

    func deviceDidDisconnect(_ device: CSDevice, with error: CSError?) {
        connectionState = .disconnected
        features = []
        if let error {
            lastError = error
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
