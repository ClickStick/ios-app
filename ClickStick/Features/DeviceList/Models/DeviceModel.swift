//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Foundation
import Observation
import os.log

protocol TextSendingDevice: AnyObject {
    var displayName: String { get }
    var isConnected: Bool { get }

    var textEntryKeyboardLayout: CSKeyboardLayout { get }
    var textEntryTargetOS: CSTypingOS { get }

    func saveTextEntryPreferences(layout: CSKeyboardLayout, targetOS: CSTypingOS)

    func sendText(_ text: String, layout: CSKeyboardLayout, targetOS: CSTypingOS) async throws

    func sendText(
        _ text: String,
        layout: CSKeyboardLayout,
        targetOS: CSTypingOS,
        onCharacterProgress: @escaping @MainActor (_ sent: Int, _ total: Int) -> Void
    ) async throws
}

protocol MouseControllingDevice: AnyObject {
    var isConnected: Bool { get }
    func sendMouseMove(dx: Int8, dy: Int8, completion: CSCommandCompletion?)
    func sendMouseClick(button: CSMouseButton, completion: CSCommandCompletion?)
    func sendMouseScroll(vertical: Int8, horizontal: Int8, completion: CSCommandCompletion?)
}

enum DeviceUIState: CustomStringConvertible {
    /// Fully connected and ready for commands.
    case connected
    /// BLE link established, session key being verified.
    case authorizing
    /// Connected but device is requesting new authentication credentials.
    case setupRequired
    /// BLE connection established, discovering services.
    case connecting
    /// Disconnected, advertising at normal signal strength, paired/known device.
    case available
    /// Disconnected, advertising at normal signal strength, new/unpaired device.
    case newDevice
    /// Disconnected, advertising but with weak signal (RSSI ≤ -85 dBm).
    case weakSignal
    /// Disconnected and no longer advertising.
    case outOfRange
    /// Session integrity check failed — device may have been tampered with.
    case compromised
    /// Connection attempt failed with an error.
    case failed(CSError)
    
    var description: String {
        switch self {
        case .connected:
            return String(localized: "Connected", comment: "Device row status")
        case .authorizing:
            return String(localized: "Authorizing...", comment: "Device row status")
        case .setupRequired:
            return String(localized: "Setup required", comment: "Device row status")
        case .connecting:
            return String(localized: "Connecting...", comment: "Device row status")
        case .available:
            return String(localized: "Tap to connect", comment: "Device row status")
        case .newDevice:
            return String(localized: "Tap to set up", comment: "Device row status")
        case .weakSignal:
            return String(localized: "Weak signal", comment: "Device row status")
        case .outOfRange:
            return String(localized: "Out of range", comment: "Device row status")
        case .compromised:
            return String(localized: "Security warning", comment: "Compromised device status")
        case .failed(let error):
            return error.localizedDescription
        }
    }
}

extension DeviceUIState: Equatable {
    static func == (lhs: DeviceUIState, rhs: DeviceUIState) -> Bool {
        switch (lhs, rhs) {
        case (.connected, .connected),
             (.authorizing, .authorizing),
             (.setupRequired, .setupRequired),
             (.connecting, .connecting),
             (.available, .available),
             (.newDevice, .newDevice),
             (.weakSignal, .weakSignal),
             (.outOfRange, .outOfRange),
             (.compromised, .compromised):
            return true
        case (.failed(let l), .failed(let r)):
            return l.localizedDescription == r.localizedDescription
        default:
            return false
        }
    }
}

/// Observable wrapper for CSDevice to bridge ClickStickKit to SwiftUI
@Observable
@MainActor
final class DeviceModel: Identifiable, CSDeviceObserver, TextSendingDevice, MouseControllingDevice {
    private let log = Logger(subsystem: "io.clickstick", category: "DeviceModel")

    // MARK: - Underlying Device

    private(set) var device: CSDevice

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
    /// True while verifying a freshly entered/scanned setup key. A MAC mismatch in
    /// this state means setup failed, not that an already trusted device is compromised.
    private var isSetupAuthenticationAttempt = false

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

    var uiState: DeviceUIState {
        if isCompromised { return .compromised }
        if let error = lastError { return .failed(error) }
        switch connectionState {
        case .connectedAuthorized:
            return .connected
        case .connectedUnauthorized:
            return needsAuthentication ? .setupRequired : .authorizing
        case .serviceDiscovery:
            return .connecting
        case .disconnected:
            guard isConnectable else { return .outOfRange }
            if rssi > -200 && rssi <= -85 { return .weakSignal }
            return isKnownDevice ? .available : .newDevice
        }
    }

    var displayName: String {
        if let alias = cachedAlias, !alias.isEmpty {
            return alias
        }
        if name.isEmpty || name == "?" || name == "…" {
            return "ClickStick \(device.uuid.uuidString.suffix(4).uppercased())"
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

    isolated deinit {
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
        isSetupAuthenticationAttempt = false
        device.connect(appAuthKey: authKey)
    }

    func connect(with authKey: CSAppAuthKey) {
        needsAuthentication = false
        lastError = nil
        isCompromised = false
        isSetupAuthenticationAttempt = true
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

    var textEntryKeyboardLayout: CSKeyboardLayout {
        deviceSettings?.keyboardLayout ?? CSKeyboardLayout.fromSystemLocale()
    }

    var textEntryTargetOS: CSTypingOS {
        deviceSettings?.typingOS ?? .windows
    }

    func saveTextEntryPreferences(layout: CSKeyboardLayout, targetOS: CSTypingOS) {
        guard let settings = deviceSettings else { return }
        settings.keyboardLayout = layout
        settings.typingOS = targetOS
        try? CSDeviceSettingsManager.saveSettings(settings)
    }

    func sendText(_ text: String, layout: CSKeyboardLayout, targetOS: CSTypingOS) async throws {
        guard isConnected else { throw CSError.connectionFailed(error: nil) }
        try await sendTypeCommands(text: text, layout: layout, targetOS: targetOS)
    }

    func sendText(
        _ text: String,
        layout: CSKeyboardLayout,
        targetOS: CSTypingOS,
        onCharacterProgress: @escaping @MainActor (_ sent: Int, _ total: Int) -> Void
    ) async throws {
        guard isConnected else { throw CSError.connectionFailed(error: nil) }
        let characters = Array(text)
        let total = characters.count
        guard total > 0 else { return }

        for (index, character) in characters.enumerated() {
            try Task.checkCancellation()
            try await sendTypeCommands(text: String(character), layout: layout, targetOS: targetOS)
            let sent = index + 1
            await MainActor.run { onCharacterProgress(sent, total) }
        }
    }

    private func sendTypeCommands(text: String, layout: CSKeyboardLayout, targetOS: CSTypingOS) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            guard isConnected else {
                continuation.resume(throwing: CSError.connectionFailed(error: nil))
                return
            }
            device.sendTypeCommands(text: text, layout: layout, targetOS: targetOS) { result in
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

    func replaceDevice(_ newDevice: CSDevice) {
        guard device !== newDevice else { return }

        device.removeObserver(self)
        device = newDevice
        name = newDevice.name
        rssi = newDevice.rssi
        connectionState = newDevice.connectionState
        features = newDevice.features
        needsAuthentication = false
        lastError = newDevice.lastError
        isConnectable = newDevice.isConnectable
        isDemoDevice = newDevice.isDemoDevice
        isCompromised = false
        isSetupAuthenticationAttempt = false
        refreshSettingsCache()
        newDevice.addObserver(self)
    }

    private var deviceSettings: CSDeviceSettings? {
        try? CSDeviceSettingsManager.loadSettings(for: device.uuid)
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
            isSetupAuthenticationAttempt = false
        }
    }

    func deviceDidDetectTampering(_ device: CSDevice) {
        connectionState = device.connectionState

        if isSetupAuthenticationAttempt {
            isSetupAuthenticationAttempt = false
            needsAuthentication = true
            isCompromised = false
            log.error("Device setup authentication failed: \(self.displayName, privacy: .public)")
            return
        }

        isCompromised = true
        log.error("Device may be compromised: \(self.displayName, privacy: .public)")
    }

    func deviceNeedsAuthentication(_ device: CSDevice) {
        isSetupAuthenticationAttempt = false
        needsAuthentication = true
        connectionState = device.connectionState
    }

    func deviceDidFail(_ device: CSDevice, with error: CSError) {
        isSetupAuthenticationAttempt = false
        lastError = error
        lastErrorTimestamp = Date()
        connectionState = device.connectionState
        log.error("Device failed: \(error.localizedDescription)")
    }

    func deviceDidDisconnect(_ device: CSDevice, with error: CSError?) {
        isSetupAuthenticationAttempt = false
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
