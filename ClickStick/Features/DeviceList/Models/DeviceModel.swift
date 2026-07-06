//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Foundation
import Observation
import os.log

protocol TextSendingDevice: AnyObject {
    var id: UUID { get }
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

enum DeviceUIState {
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
    
    /// User-facing status copy for the device row / picker (not a debug description).
    var statusDescription: String {
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

    /// True when the most recent disconnect was initiated by the app/user (e.g. backgrounding
    /// or an explicit disconnect) rather than an unexpected link loss. Lets the UI suppress
    /// the "connection lost" prompt for disconnects we asked for.
    private(set) var didDisconnectIntentionally: Bool = false

    /// True when a disconnected device hasn't advertised recently while scanning, so it should
    /// be treated as out of range (e.g. the dongle was unplugged) rather than tap-to-connect.
    private(set) var isStale: Bool = false

    private static let staleInterval: TimeInterval = 3.0

    private var lastRSSIUpdate: Date = .distantPast
    @ObservationIgnored private var staleTask: Task<Void, Never>?
    /// True while verifying a freshly entered/scanned setup key. A MAC mismatch in
    /// this state means setup failed, not that an already trusted device is compromised.
    private var isSetupAuthenticationAttempt = false

    // MARK: - Silent connection retry

    /// Transient BLE connection failures (timeouts, dropped links) are common, so we retry
    /// a few times before surfacing the error — keeping the UI in the connecting state in
    /// the meantime rather than flashing a spurious failure to the user.
    private static let maxConnectionRetries = 2
    private var connectionRetryCount = 0
    /// True from a user/auto-initiated `connect()` until the device is authorized, the
    /// retries are exhausted, or the user disconnects. Drives the connecting UI during retries.
    private var isConnectionAttemptActive = false
    private var retryTask: Task<Void, Never>?

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
            // A silent retry leaves the link momentarily disconnected; keep showing
            // "connecting" so the user doesn't see it bounce back to "tap to connect".
            if isConnectionAttemptActive { return .connecting }
            guard isConnectable, !isStale else { return .outOfRange }
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
        retryTask?.cancel()
        staleTask?.cancel()
        device.removeObserver(self)
    }

    // MARK: - Public API

    func connect() {
        cancelRetries()
        performConnect()
    }

    /// Starts (or silently retries) a connection using the device's stored auth key.
    private func performConnect() {
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

        prepareForNewConnection()
        isConnectionAttemptActive = true
        device.connect(appAuthKey: authKey)
    }

    func connect(with authKey: CSAppAuthKey) {
        // Setup uses a freshly scanned key and must surface failures immediately, so it
        // opts out of silent retries.
        cancelRetries()
        prepareForNewConnection(isSetup: true)
        isConnectionAttemptActive = false
        device.connect(appAuthKey: authKey)
    }

    /// Clears the compromise warning (e.g. when the user chooses to re-pair the device).
    func clearCompromiseWarning() {
        isCompromised = false
    }

    func disconnect() {
        // A user/app-initiated disconnect cancels any in-flight silent retry and is
        // flagged as intentional so the UI doesn't treat it as a lost connection.
        cancelRetries()
        isConnectionAttemptActive = false
        didDisconnectIntentionally = true
        guard connectionState != .disconnected else { return }
        device.disconnect()
    }

    // MARK: - Silent retry helpers

    private func shouldRetryConnection(after error: CSError) -> Bool {
        guard isConnectionAttemptActive else { return false }
        guard connectionRetryCount < Self.maxConnectionRetries else { return false }
        // Only retry transient link failures, not auth/crypto/bluetooth-availability issues.
        guard case .connectionFailed = error else { return false }
        return true
    }

    private func scheduleConnectionRetry() {
        connectionRetryCount += 1
        let attempt = connectionRetryCount
        log.debug("Silent connection retry \(attempt) of \(Self.maxConnectionRetries) for \(self.displayName, privacy: .public)")
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            // Small linear backoff between attempts.
            try? await Task.sleep(for: .seconds(0.5 * Double(attempt)))
            guard let self, !Task.isCancelled else { return }
            self.performConnect()
        }
    }

    private func startStaleTask(after delay: TimeInterval) {
        staleTask?.cancel()
        staleTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            isStale = true
            lastError = nil
        }
    }

    private func cancelStaleTask() {
        staleTask?.cancel()
        staleTask = nil
    }

    // MARK: - Connection Helpers

    /// Cancels any in-flight silent retry and resets the retry counter.
    private func cancelRetries() {
        connectionRetryCount = 0
        retryTask?.cancel()
        retryTask = nil
    }

    /// Resets device state flags in preparation for a connection attempt.
    /// Does not touch the retry infrastructure so silent retries continue to work.
    private func prepareForNewConnection(isSetup: Bool = false) {
        isSetupAuthenticationAttempt = isSetup
        didDisconnectIntentionally = false
        cancelStaleTask()
        isStale = false
        needsAuthentication = false
        lastError = nil
        isCompromised = false
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
        cancelStaleTask()
        if isStale {
            // The device is advertising again — it's back in range, so clear the stale
            // out-of-range state and any connection error left over from when it vanished.
            isStale = false
            lastError = nil
        }
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
            isConnectionAttemptActive = false
            connectionRetryCount = 0
            isCompromised = false
            isSetupAuthenticationAttempt = false
            cancelStaleTask()
            isStale = false
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
        connectionState = device.connectionState
        if shouldRetryConnection(after: error) {
            lastError = nil // suppress; keep the connecting UI while we retry silently
            scheduleConnectionRetry()
            return
        }
        isConnectionAttemptActive = false
        lastError = error
        lastErrorTimestamp = Date()
        log.error("Device failed: \(error.localizedDescription)")
    }

    func deviceDidDisconnect(_ device: CSDevice, with error: CSError?) {
        isSetupAuthenticationAttempt = false
        connectionState = .disconnected
        features = []
        startStaleTask(after: Self.staleInterval)
        if let error, shouldRetryConnection(after: error) {
            lastError = nil // suppress; keep the connecting UI while we retry silently
            scheduleConnectionRetry()
            return
        }
        isConnectionAttemptActive = false
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
