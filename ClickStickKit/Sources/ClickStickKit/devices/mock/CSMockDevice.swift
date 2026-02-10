//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import CryptoKit
import Foundation
import os.log

internal final class CSMockDevice: CSDevice {
    private let log = Logger(subsystem: "io.clickstick", category: #file)

    override var isDemoDevice: Bool { true }

    // "Hardware-side" properties of the emulated dongle.
    private var _mockAppAuthKey = CSAppAuthKey.demo
    private var _mockStatus: CSDevice.State = .initSession
    private var _mockStatusData: Data?
    private var _mockCommandData: Data?
    private var _mockDonglePrivateKey: Curve25519.KeyAgreement.PrivateKey?
    private var _mockSessionKey: CSSessionKey?
    private var _mockSeqCounter: CSSequenceCounter = 0

    // MARK: Overrides

    override var _maxOutgoingPacketSize: Int {
        return 226 /// A reasonable default of a non-negotiated BLE 4.2 limit.
    }

    override init(uuid: UUID) {
        super.init(uuid: uuid)
        _name = "ClickStick \(uuid.uuidString.suffix(4)) [demo]"
        _isConnectable = true
    }

    override func _requestRSSIRefresh() {
        let newRSSI = Int.random(in: -65...(-55))
        csManagerDidUpdateProperties(name: _name, rssi: newRSSI, isConnectable: _isConnectable)
        _lastSeen = .now // mock device is always visible
    }

    override func _startConnection() {
        dispatch(after: 0.5) { [self] in
            _setMockStatus(.initSession, notify: false)
            csManagerDidConnect()
        }
    }

    override func _startServiceDiscovery() {
        dispatch(after: 1) { [self] in
            _didDiscoverAllServices()
        }
    }

    /// Returns the latest value from device's status channel, if connected and available.
    override func _readDeviceStatusChannel() -> Data? {
        return _mockStatusData
    }

    override func _requestStatusUpdate() {
        dispatch(after: 0.1) { [self] in
            _didReceiveStatusData(_mockStatusData)
        }
    }

    /// Writes a raw packet to device's command channel, then calls
    /// `_didWriteToCommandChannel()` once the write is confirmed or failed.
    override func _writeToCommandChannel(_ packet: Data) {
        _setMockCommandData(packet)
        dispatch { [self] in
            // emulate a successful write
            _didWriteToCommandChannel(error: nil)
        }
    }

    override func _endConnection() {
        dispatch { [self] in
            csManagerDidDisconnect(with: nil)
        }
    }
}

// MARK: Fake data routines
extension CSMockDevice {
    func _setMockStatus(_ status: CSDevice.State, notify: Bool) {
        let data: Data
        switch status {
        case .initSession:
            // prepare dongle keys and publish the public one
            data = _generateMockSessionData()
        case .busy:
            data = Data([CSDevice.State.busy.rawValue])
        case .idle:
            data = Data([CSDevice.State.idle.rawValue])
        }
        _mockStatus = status
        _mockStatusData = data
        if notify {
            dispatch { [self] in
                _didReceiveStatusData(data)
            }
        }
    }

    func _generateMockSessionData() -> Data {
        let mockPrivateKey = Curve25519.KeyAgreement.PrivateKey()
        self._mockDonglePrivateKey = mockPrivateKey
        let sessionData = CSDeviceSession.make(
            publicKey: mockPrivateKey.publicKey,
            appAuthKey: _mockAppAuthKey)
        return sessionData
    }

    func _setMockCommandData(_ packet: Data?) {
        assert(_connectionState != .disconnected)
        _mockCommandData = packet
        guard let packet else {
            return
        }

        _processMockCommandPacket(packet)
    }

    func _processMockCommandPacket(_ packet: Data) {
        // Expected packet structure (https://clickstick.io/docs/protocol.html#packet-structure):
        // - seq: UInt16, ignored here
        // - encryptedCommand: Data, 0 to maxCommandSize bytes
        // - shortMAC: CSShortMAC, 16 bytes

        // Validate minimum packet size (seq + commandID + MAC)
        let minPacketSize = CSSequenceCounter.byteCount + 1 + CSShortMAC.byteCount
        guard packet.count >= minPacketSize else {
            log.error("Packet too short: \(packet.count) bytes, need at least \(minPacketSize)")
            _increaseMockErrorCounter()
            assertionFailure("Packet too short")
            return
        }
        // Extract components
        let seq = packet.prefix(CSSequenceCounter.byteCount).asBigEndian(CSSequenceCounter.self)!
        let commandData = packet
            .dropFirst(CSSequenceCounter.byteCount)
            .dropLast(CSShortMAC.byteCount)
        let publishedMAC = packet.suffix(CSShortMAC.byteCount)

        let assumingStartSessionCommand = (seq == 0) && (_mockStatus == .initSession)
        let hmacKey: SymmetricKey
        if assumingStartSessionCommand {
            hmacKey = _mockAppAuthKey.key
        } else {
            guard let _mockSessionKey else {
                log.error("Received a packet before establishing a session key, rejecting")
                assertionFailure("Mock session key is nil")
                return
            }
            hmacKey = _mockSessionKey
        }

        let hmacInput = packet.dropLast(CSShortMAC.byteCount)
        let calculatedMAC = Data(HMAC<SHA256>
            .authenticationCode(for: hmacInput, using: hmacKey)
            .prefix(CSShortMAC.byteCount))
        guard publishedMAC == calculatedMAC else {
            log.error("Incorrect MAC in command packet, ignoring command.")
            _increaseMockErrorCounter()
            assertionFailure("Incorrect MAC in outgoing packet")
            return
        }
        // TODO: check that seq matches expected value, otherwise increase error counter

        let mockCommand: CSCommand
        if assumingStartSessionCommand {
            // START_SESSION commands are plain-text
            guard let command = _parseMockCommand(from: commandData) else {
                log.error("Failed to parse command, ignoring it.")
                _increaseMockErrorCounter()
                assertionFailure()
                return
            }
            mockCommand = command
        } else {
            guard let command = _decryptMockCommand(commandData, seq: seq) else {
                log.error("Failed to decrypt command, ignoring it.")
                _increaseMockErrorCounter()
                assertionFailure()
                return
            }
            mockCommand = command
        }
        dispatch(after: 0.1) { [self] in
            _performMockCommand(mockCommand)
        }
    }

    /// Increases mock device's error counter and eventually triggers a cool-off and session restart.
    func _increaseMockErrorCounter() {
        // TODO: implement this
    }

    func _decryptMockCommand(_ encryptedCommand: Data, seq: CSSequenceCounter) -> CSCommand? {
        let sessionKey: CSSessionKey
        if _mockStatus == .initSession {
            // In this status, we expect only START_SESSION command, with seq = 0 and all-zero session key.
            // The encryption is completely useless in this case, which exposes mobilePublicKey.
            // This is intended, the derived session key won't be exposed.
            // https://clickstick.io/docs/commands.html#start-session
            guard seq == 0 else {
                log.error("In initSession state, received a command with seq != 0, rejecting it.")
                assertionFailure()
                return nil
            }
            sessionKey = .zeros
        } else {
            guard let _mockSessionKey else {
                log.error("Received a command before session was set up, rejecting it.")
                return nil
            }
            sessionKey = _mockSessionKey
        }

        // Calculate IV := SHA256(sessionKey || seq), truncated to first 16 bytes
        // https://clickstick.io/docs/protocol.html#packet-structure
        var ivInput = Data()
        ivInput.append(contentsOf: sessionKey.withUnsafeBytes { Array($0) })
        let seqBytes = Data(from: seq.bigEndian)
        ivInput.append(contentsOf: seqBytes)
        let ivData = Data(SHA256.hash(data: ivInput).prefix(16))

        // The START_SESSION command reuses the IV and has all-zero key,
        // it is essentially in plaintext mode — this is expected.

        guard let decryptedData = try? CryptoHelper.decrypt(encryptedCommand, key: sessionKey, iv: ivData)
        else {
            log.error("Failed to decrypt command, rejecting it.")
            return nil
        }

        guard let parsedCommand = _parseMockCommand(from: decryptedData) else {
            log.error("Failed to parse decrypted command, rejecting it.")
            return nil
        }
        return parsedCommand
    }

    func _parseMockCommand(from plaintextCommandPacket: Data) -> CSCommand? {
        guard let commandID = plaintextCommandPacket.first else {
            log.error("Command packet is empty.")
            return nil
        }
        switch commandID {
        case CSStartSessionCommand.commandID: // 0x00
            return CSStartSessionCommand.fromMockPacket(plaintextCommandPacket)
        case CSCancelCommand.commandID: // 0x01
            return CSCancelCommand.fromMockPacket(plaintextCommandPacket)
        case CSPauseCommand.commandID: // 0x02
            return CSPauseCommand.fromMockPacket(plaintextCommandPacket)
        case CSTypeCommand.commandID: // 0x10
            return CSTypeCommand.fromMockPacket(plaintextCommandPacket)
        case CSMouseCommand.commandID: // 0x20
            return CSMouseCommand.fromMockPacket(plaintextCommandPacket)
        default:
            log.error("Unknown command ID: \(commandID) - rejecting command")
            return nil
        }
    }

    func _performMockCommand(_ command: CSCommand) {
        _setMockStatus(.busy, notify: true)
        switch command {
        case let startSessionCommand as CSStartSessionCommand:
            log.trace("Mock dongle will START_SESSION")
            if let sessionKey = _deriveMockSessionKey(mobilePublicKey: startSessionCommand.publicKey) {
                log.debug("Mock session key derived successfully")
                _mockSessionKey = sessionKey
                _mockSeqCounter = 1
                _setMockStatus(.idle, notify: true)
            } else {
                _mockSessionKey = nil
                log.debug("Will re-init session after a cool-off period")
                dispatch(after: 0.5) { [self] in // with a small delay as a cool-off
                    _setMockStatus(.initSession, notify: true)
                }
            }
        case is CSCancelCommand:
            if _mockStatus == .initSession {
                log.warning("Received Cancel command in initSession mode, rejecting it.")
                assertionFailure()
                return
            }
            // Mock device does not have a queue, so go to .idle state immediately
            log.trace("Mock dongle will CANCEL all commands")
            _setMockStatus(.idle, notify: true)
        case let pauseCommand as CSPauseCommand:
            if _mockStatus == .initSession {
                log.warning("Received Pause command in initSession mode, rejecting it.")
                assertionFailure()
                return
            }
            log.trace("Mock dongle will PAUSE for \(pauseCommand.timeout) seconds")
            dispatch(after: pauseCommand.timeout) { [self] in
                _setMockStatus(.idle, notify: true)
            }
        case let typeCommand as CSTypeCommand:
            if _mockStatus == .initSession {
                log.warning("Received TYPE command in initSession mode, rejecting it.")
                assertionFailure()
                return
            }
            let typingDelay: TimeInterval = 0.1 * Double(typeCommand.keyCodes.count)
            log.trace("Mock dongle will TYPE for \(typingDelay) seconds")
            dispatch(after: typingDelay) { [self] in
                _setMockStatus(.idle, notify: true)
            }
        case let mouseCommand as CSMouseCommand:
            if _mockStatus == .initSession {
                log.warning("Received MOUSE command in initSession mode, rejecting it.")
                assertionFailure()
                return
            }
            let hidDelay: TimeInterval = 0.05 * Double(mouseCommand.events.count)
            log.trace("Mock dongle will MOUSE for \(hidDelay) seconds")
            dispatch(after: hidDelay) { [self] in
                _setMockStatus(.idle, notify: true)
            }
        default:
            log.error("Unexpected command type for mock device: \(type(of: command))")
            assertionFailure("Unexpected command type in mock device")
        }
    }

    /// Calculates the (dongle side) `_mockSessionKey`, based on mobile public key
    /// received via a `START_SESSION` command.
    func _deriveMockSessionKey(mobilePublicKey: Curve25519.KeyAgreement.PublicKey) -> CSSessionKey? {
        // After receiving mobilePublicKey, the dongle computes:
        // sharedSecret := ECDH(dongleSecretKey, mobilePublicKey)
        // sessionKey := HKDF(sharedSecret, appAuthKey)
        // seq := 0
        guard let _mockDonglePrivateKey else {
            assertionFailure("Dongle private key must be generated by now")
            return nil
        }
        return CSDeviceSession.deriveSessionKey(
            localPrivateKey: _mockDonglePrivateKey,
            remotePublicKey: mobilePublicKey,
            appAuthKey: _mockAppAuthKey
        )
    }
}

// MARK: Helpers
extension CSMockDevice {
    private func dispatch(after delay: TimeInterval = 0.0, _ block: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: block)
    }
}
