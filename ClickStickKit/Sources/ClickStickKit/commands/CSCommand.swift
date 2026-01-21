//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import CryptoKit
import Foundation
import os.log

private let log = Logger(subsystem: "io.clickstick", category: #file)

public typealias CSCommandCompletion = ((Result<Void, CSError>) -> Void)

class CSCommand: CustomStringConvertible {
    typealias CommandID = UInt8
    class var commandID: CommandID { fatalError("Pure abstract, override this") }

    struct Attributes: OptionSet {
        let rawValue: UInt8

        static let highPriority = Self(rawValue: 0x02)
        static let resetsSequenceCounter = Self(rawValue: 0x01)
    }
    /// Default maximum execution time expected for a simple command
    static let baselineTimeout: TimeInterval = 0.5

    /// Maximum supported size of the command packet, negotiated with the peripheral.
    let maxCommandSize: Int

    /// Command name (for logging)
    let name: String

    /// Defines additional flags of the command
    let attributes: Attributes

    /// Maximum execution time expected for this command
    let timeout: TimeInterval

    /// Raw bytes of this command
    /// https://clickstick.io/docs/commands.html
    let bytes: Data

    /// Callback once the command finishes
    private let completion: CSCommandCompletion?

    var description: String { name }

    init(
        name: String,
        packet: Data,
        attributes: Attributes,
        timeout: TimeInterval = CSCommand.baselineTimeout,
        maxCommandSize: Int,
        completion: CSCommandCompletion?
    ) {
        self.name = name
        self.bytes = packet
        self.attributes = attributes
        self.timeout = timeout
        self.maxCommandSize = maxCommandSize
        self.completion = completion
    }

    /// Returns maximum allowed command size for the given packet size limit.
    static func getMaxCommandSize(forPacketSize packetSize: Int) -> Int {
        // Packet is: seq (2 bytes) + encCommand + MAC (16 bytes)
        // Source: https://clickstick.io/docs/protocol.html#packet-structure
        return packetSize - CSSequenceCounter.byteCount - CSShortMAC.byteCount
    }

    /// Encrypts the command and wraps it into a signed packet:
    /// https://clickstick.io/docs/protocol.html#packet-structure
    /// - Parameters:
    ///   - seq: sequence counter
    ///   - sessionKey: session key
    ///   - appAuthKey: app pairing key
    /// - Returns: ready-to-send packet
    /// - Throws: `CryptoError`
    func toPacket(
        seq: CSSequenceCounter,
        sessionKey: CSSessionKey,
        appAuthKey: CSAppAuthKey
    ) throws -> Data {
        // Packet structure
        // - seq: UInt16, sequence counter
        // - encCommand := encrypt(command, sessionKey, IV)
        //      where IV := SHA256(sessionKey || seq), truncated to first 16 bytes
        // - MAC := HMAC_sessionKey(seq || encCommand)

        // IV := SHA256(sessionKey || seq), truncated to first 16 bytes
        var ivInput = Data()
        ivInput.append(contentsOf: sessionKey.withUnsafeBytes { Array($0) })
        let seqBytes = Data(from: seq.bigEndian)
        ivInput.append(contentsOf: seqBytes)
        let ivData = Data(SHA256.hash(data: ivInput).prefix(16))

        let encCommand = try CryptoHelper.encrypt(self.bytes, key: sessionKey, iv: ivData)

        var packet = Data()
        packet.append(contentsOf: seqBytes)
        packet.append(contentsOf: encCommand)
        let shortMAC = HMAC<SHA256>
            .authenticationCode(for: packet, using: sessionKey)
            .prefix(CSShortMAC.byteCount)
        packet.append(contentsOf: shortMAC)
        return packet
    }

    /// Calls completion handler with `.success`
    func completedWithSuccess() {
        DispatchQueue.main.async { [self] in
            completion?(.success(()))
        }
    }

    /// Calls completion handler with `.failure`
    func completedWithError(_ error: CSError) {
        let name = self.name
        log.error("Command '\(name)' failed with error: \(error)")
        DispatchQueue.main.async { [self] in
            completion?(.failure(error))
        }
    }
}
