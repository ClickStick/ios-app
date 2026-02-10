//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import CoreBluetooth
import CryptoKit
import Foundation
import os.log

// Inherit `NSObject` to be able to become `CBPeripheralDelegate`.
public class CSDevice: NSObject {
    private let log = Logger(subsystem: "io.clickstick", category: #file)

    // MARK: Public properties

    /// Unique identifier of the device
    public private(set) var uuid: UUID
    /// Bluetooth name of the device
    public var name: String { _name }
    /// Current received signal strength
    public var rssi: Int { _rssi }

    public var isConnectable: Bool { _isConnectable }
    /// True for virtual/mock devices, false for real devices.
    public var isDemoDevice: Bool { false }
    /// Serial number broadcasted by the device
    public var serialNumber: String? { _serialNumber }
    /// Firmware version broadcasted by the device
    public var firmwareVersion: String? { _firmwareVersion }
    /// Time when device was last seen
    public var lastSeen: Date? { _lastSeen }
    public var lastError: CSError? { _lastError }
    /// Features supported by the device. Empty until connected.
    public var features: [CSDeviceFeature] { _features }
    /// State of connection with the device.
    public var connectionState: ConnectionState { _connectionState }
    /// Device's internal state (only when connected)
    public var deviceState: State { _deviceState }

    // MARK: Private/protected properties

    internal var _name: String = "…"
    internal var _rssi: Int = -255
    internal var _isConnectable: Bool = false
    internal var _serialNumber: String?
    internal var _firmwareVersion: String?
    internal var _lastSeen: Date?
    internal var _lastError: CSError?
    internal var _features: [CSDeviceFeature] = []
    internal var _observers = NSHashTable<AnyObject>.weakObjects()

    // States

    internal var _connectionState: ConnectionState = .disconnected {
        didSet {
            _notifyObservers { $0.deviceConnectionStateUpdated(self) }
        }
    }

    /// Mirrors last-seen state of remote device
    internal var _deviceState: State = .idle
    internal var _isDeviceIdle: Bool { _deviceState == .idle }
    private var _rssiRefreshTimer: Timer!

    // Session

    /// App pairing key provided for this device, if any
    internal var _appAuthKey: CSAppAuthKey?
    /// Derived session key, if ready
    internal var _sessionKey: CSSessionKey?
    /// Packet sequence counter
    internal var _seqCounter: CSSequenceCounter = 0

    // Command queue

    /// Maximum packet size that can be sent via the outgoing channel, negotiated with the device.
    internal var _maxOutgoingPacketSize: Int { fatalError("Pure abstract property") }
    /// Maximum supported command size that still fits into `_maxOutgoingPacketSize`.
    internal var _maxCommandSize: Int {
        CSCommand.getMaxCommandSize(forPacketSize: _maxOutgoingPacketSize)
    }
    internal var _commandQueue = [CSCommand]()
    internal var _inFlightCommand: CSCommand? // command just sent to device
    internal var _commandCompletionTimeoutTimer: Timer?

    // MARK: Public API

    /// Starts service discovery for this device.
    /// Then tries to start a session, if `appAuthKey` is provided.
    ///
    /// If the key is wrong or not provided, notifies observers `deviceNeedsAuthentication()`.
    /// After acquiring/updating the auth key key, the observer should call `connect()` again.
    /// In case of errors, notifies observers via `deviceDidFail()`.
    public func connect(appAuthKey: CSAppAuthKey?) {
        switch _connectionState {
        case .serviceDiscovery:
            return // already in progress
        case .connectedAuthorized:
            assertionFailure("Called connect() while already connected and authorized; ignoring.")
            return
        case .disconnected, .connectedUnauthorized:
            break
        }
        log.debug("Will connect to \(self.uuid)")
        _features = []
        _lastError = nil
        self._appAuthKey = appAuthKey
        _connectionState = .serviceDiscovery
        _startConnection()
    }

    /// Switches the device to `.disconnected` state and erases session keys.
    public func disconnect() {
        assert(_connectionState == .connectedAuthorized || _connectionState == .connectedUnauthorized)
        log.debug("Will disconnect from \(self.uuid)")
        _features = []
        _lastError = nil
        _sessionKey = nil
        _endConnection()
    }

    // MARK: - Internal API

    init(uuid: UUID) {
        self.uuid = uuid
        super.init()
        _scheduleRSSIRefresh()
    }

    deinit {
        _rssiRefreshTimer.invalidate()
    }

    // MARK: Lower-level read/write and connection management

    /// Requests an RSSI refresh from CSManager.
    func _requestRSSIRefresh() {
        fatalError("Pure abstract method")
    }

    /// Initiates radio connection to device
    func _startConnection() {
        fatalError("Pure abstract method")
    }

    /// Initiates communication channels (when radio connection established).
    func _startServiceDiscovery() {
        fatalError("Pure abstract method")
    }

    func _didFailServiceDiscovery(_ error: CSError) {
        log.debug("Did fail service discovery. Device \(self.uuid): \(error)")
        // Fail in-flight command — safer than stalling indefinitely.
        _finalizeInFlightCommandWithError(error, proceed: false)
        _handleConnectionFailure(with: error)
    }

    /// Called once communication channels are established.
    func _didDiscoverAllServices() {
        log.info("Device characteristics discovered, not authorized yet")
        _connectionState = .connectedUnauthorized
        _lastError = nil
        // Initiate processing of device status
        _requestStatusUpdate()
//        _didReceiveStatusData(_readDeviceStatusChannel())
    }

    /// Called whenever device's status channel updates its value.
    /// Note: `data` might be empty or malformed.
    func _didReceiveStatusData(_ data: Data?) {
        guard let data, let stateByte = data.first else {
            log.error("Incoming data is empty, ignoring it")
            return
        }
        guard let newState = CSDevice.State(rawValue: stateByte) else {
            log.error("Unexpected device state: \(stateByte), ignoring it")
            return
        }

        let oldState = _deviceState
        // TODO: fails if uncommented; real device depends on second startSession() call?
//        if newState == oldState {
//            return
//        }
        self._deviceState = newState
        log.debug("State: \(oldState) -> \(newState)")
        switch (oldState, newState) {
        case (.busy, .idle):
            if _inFlightCommand != nil {
                _finalizeInFlightCommandWithSuccess()
            }
            _maybeScheduleNextCommand()
        case (_, .initSession):
            if _inFlightCommand != nil {
                _finalizeInFlightCommandWithSuccess()
            }
            _connectionState = .connectedUnauthorized
            _startSession()
            _maybeScheduleNextCommand()
        case (_, .idle):
            _maybeScheduleNextCommand()
        case (_, .busy):
            // Device is processing a command, wait until it becomes idle
            break
        }
    }

    /// Fetches the value from device's status channel, if connected and available.
    /// *NB*: notifications are limited to 20 bytes; so call `_requestStatusUpdate` beforehand.
    func _readDeviceStatusChannel() -> Data? {
        fatalError("Pure abstract method")
    }

    /// Asks BLE layer to read value of the status channel.
    /// The result will arrive asynchronously to `_didReceiveStatusData()`
    func _requestStatusUpdate() {
        fatalError("Pure abstract method")
    }

    /// Writes a raw packet to device's command channel, then calls
    /// `_didWriteToCommandChannel()` once the write is confirmed or failed.
    func _writeToCommandChannel(_ packet: Data) {
        fatalError("Pure abstract method")
    }

    /// Called once `_writeToCommandChannel` is acknowledged by BLE layer.
    /// - Parameter error: non-nil if writing failed.
    func _didWriteToCommandChannel(error: CSError?) {
        if let error {
            _finalizeInFlightCommandWithError(error, proceed: false)
        } else {
            // Write acknowledged, keep waiting for device to leave the BUSY state.
        }
    }

    /// Unified sink for all errors
    func _handleConnectionFailure(with error: CSError) {
        _features = []
        _lastError = error
        _sessionKey = nil
        _connectionState = .disconnected
        _notifyObservers { $0.deviceDidFail(self, with: error) }
    }

    /// Stops radio connection to device.
    func _endConnection() {
        fatalError("Pure abstract method")
    }

    // MARK: Higher-level session management

    func _startSession() {
        assert(_deviceState == .initSession)
        guard let _appAuthKey else {
            log.info("Device needs auth key, informing observers")
            _notifyObservers { $0.deviceNeedsAuthentication(self) }
            return
        }
        guard let sessionData = _readDeviceStatusChannel() else {
            log.error("Cannot start session, no status data")
            assertionFailure()
            return
        }

        guard let remotePublicKey = CSDeviceSession.parse(sessionData: sessionData, appAuthKey: _appAuthKey)
        else {
            log.error("Failed to parse session data (likely wrong auth key), requesting re-authentication")
            // Clear invalid key and request authentication
            self._appAuthKey = nil
            _notifyObservers { $0.deviceNeedsAuthentication(self) }
            return
        }

        let localPrivateKey = Curve25519.KeyAgreement.PrivateKey()
        guard let sessionKey = CSDeviceSession.deriveSessionKey(
            localPrivateKey: localPrivateKey,
            remotePublicKey: remotePublicKey,
            appAuthKey: _appAuthKey)
        else {
            log.error("Failed to derive a session key, aborting")
            disconnect()
            return
        }
        self._sessionKey = sessionKey

        let startSessionCommand = CSStartSessionCommand(
            publicKey: localPrivateKey.publicKey,
            maxCommandSize: _maxCommandSize,
            completion: { [weak self] result in
                guard let self else { return }
                switch result {
                case .success:
                    _didStartSession()
                case .failure(let csError):
                    _handleConnectionFailure(with: csError)
                }
            }
        )
        _enqueueCommand(startSessionCommand)
    }

    func _didStartSession() {
        log.info("Device connected, authorized")
        _features = [.textEntry, .mouse]
        _seqCounter = 1
        _connectionState = .connectedAuthorized
    }
}

// MARK: Command queue
extension CSDevice {
    /// Adds the given command to the sending queue,
    func _enqueueCommand(_ command: CSCommand) {
        if command.attributes.contains(.highPriority) {
            _commandQueue.insert(command, at: 0) // priority to the front
        } else {
            _commandQueue.append(command)
        }
        _maybeScheduleNextCommand()
    }

    func _maybeScheduleNextCommand() {
        guard // _isDeviceIdle,
              _inFlightCommand == nil, // not already waiting
              !_commandQueue.isEmpty   // got something to send
        else {
            return
        }

        let nextCommand = _commandQueue.removeFirst()
        _send(nextCommand)
    }

    /// Encrypts the command, updates the sequence counter, sends the packet
    func _send(_ command: CSCommand) {
        _inFlightCommand = command
        guard let _sessionKey else {
            log.error("Sending failed: session key is nil")
            let csError = CSError.commandError(.internalError("Tried to send with no session key"))
            _finalizeInFlightCommandWithError(csError, proceed: false)
            return
        }
        guard let _appAuthKey else {
            log.error("Sending failed: app auth key is nil")
            let csError = CSError.commandError(.internalError("Tried to send with no app auth key"))
            _finalizeInFlightCommandWithError(csError, proceed: false)
            return
        }

        // TODO: add local processing, such as clearing the queue for Cancel command
        if command.attributes.contains(.resetsSequenceCounter) {
            _seqCounter = 0
        }

        do {
            let packet = try command.toPacket(
                seq: _seqCounter,
                sessionKey: _sessionKey,
                appAuthKey: _appAuthKey
            )
            _writeToCommandChannel(packet)
            _startCommandCompletionTimeout(command.timeout)
        } catch {
            log.error("Failed to encrypt command packet, cancelling. \(error)")
            let csError = CSError.commandError(.cryptographyError(error))
            _finalizeInFlightCommandWithError(csError, proceed: false)
        }
    }

    /// 
    func _startCommandCompletionTimeout(_ timeout: TimeInterval) {
        // TODO: enable after debug
//        _commandCompletionTimeoutTimer?.invalidate()
//        _commandCompletionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) {
//            [weak self] _ in
//            guard let self else { return }
//
//            if let currentCommand = _inFlightCommand {
//                log.error("Command \(currentCommand) timed out")
//                _finalizeInFlightCommandWithError(.commandError(.timeout), proceed: false)
//            }
//        }
    }

    func _cancelCommandCompletionTimeout() {
        _commandCompletionTimeoutTimer?.invalidate()
        _commandCompletionTimeoutTimer = nil
    }

    /// Runs the success completion of the in-flight command.
    func _finalizeInFlightCommandWithSuccess() {
        _cancelCommandCompletionTimeout()
        if let finishedCommand = _inFlightCommand {
            _inFlightCommand = nil
            finishedCommand.completedWithSuccess()
        }
    }

    /// Runs the error completion of the in-flight command.
    /// - Parameters:
    ///   - error: error encountered while sending the command
    ///   - proceed: `true` for minor errors: attempt sending the next command;
    ///              `false` if cannot recover, clears the queue.
    func _finalizeInFlightCommandWithError(_ error: CSError, proceed: Bool) {
        _cancelCommandCompletionTimeout()
        if let failedCommand = _inFlightCommand {
            _inFlightCommand = nil
            failedCommand.completedWithError(error)
        }
        if proceed {
            _maybeScheduleNextCommand()
        } else {
            _commandQueue.forEach {
                $0.completedWithError(error)
            }
            _commandQueue.removeAll()
            // TODO: check if there is something else to do
        }
    }
}

// MARK: Helpers
extension CSDevice {
    private func _scheduleRSSIRefresh() {
        // We are in background queue, timer won't run here — so we explicitly move it to the main one.
        DispatchQueue.main.async {
            self._rssiRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
                [weak self] _ in
                self?._requestRSSIRefresh()
            }
        }
    }
}
