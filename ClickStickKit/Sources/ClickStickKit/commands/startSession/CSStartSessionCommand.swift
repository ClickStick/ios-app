//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import Foundation
import CryptoKit
import os.log

private let log = Logger(subsystem: "io.clickstick", category: #file)

final class CSStartSessionCommand: CSCommand {
    override class var commandID: CommandID { 0x00 }
    private static let keySize = 32

    var publicKey: Curve25519.KeyAgreement.PublicKey

    /// Completes session initialization by providing local public ECDH key to the dongle.
    init(
        publicKey: Curve25519.KeyAgreement.PublicKey,
        maxCommandSize: Int,
        completion: CSCommandCompletion?
    ) {
        self.publicKey = publicKey
        let keyBytes = publicKey.rawRepresentation
        assert(keyBytes.count == Self.keySize, "Unexpected key size")
        var sessionData = Data(capacity: 1 + keyBytes.count)
        sessionData.append(Self.commandID)
        sessionData.append(contentsOf: keyBytes)

        assert(sessionData.count <= maxCommandSize, "Command packet too large")
        let attributes: CSCommand.Attributes = [.resetsSequenceCounter]
        super.init(
            name: "START_SESSION",
            packet: sessionData,
            attributes: attributes,
            maxCommandSize: maxCommandSize,
            completion: completion
        )
    }

    /// Parses a plain-text command packet into a CSStartSessionCommand instance.
    /// In case of error, returns `nil`.
    /// For mock/demo devices only.
    internal static func fromMockPacket(_ packet: Data) -> Self? {
        let expectedSize = 1 + Self.keySize
        guard packet.count == expectedSize else {
            log.error("Unexpected packet size: \(packet.count) instead of \(expectedSize) bytes")
            return nil
        }
        guard packet.first == Self.commandID else {
            assertionFailure("Wrong command ID")
            return nil
        }
        let publicKeyData = packet.dropFirst()
        do {
            let publicKey = try Curve25519.KeyAgreement.PublicKey(
                rawRepresentation: Array(publicKeyData)
            )
            return Self(publicKey: publicKey, maxCommandSize: expectedSize, completion: nil)
        } catch {
            assertionFailure("Failed to create mobile public key")
            return nil
        }
    }

    /// Wraps the command into a signed packet.
    /// Unlike other commands, command data is not encrypted and
    /// MAC is based of appAuthKey; sessionKey is unknown here.
    /// https://clickstick.io/docs/commands.html#start-session
    /// - Parameters:
    ///   - seq: sequence counter (must be zero)
    ///   - sessionKey: session key, ignored
    ///   - appAuthKey: app pairing key
    /// - Returns: ready-to-send packet
    /// - Throws: `CryptoError`
    override func toPacket(
        seq: CSSequenceCounter,
        sessionKey: CSSessionKey,
        appAuthKey: CSAppAuthKey
    ) throws -> Data {
        // START_SESSION packet structure
        // - seq: UInt16, always zero
        // - command
        //   - commandID: UInt8 = 0x00
        //   - mobilePublicKey: 32 bytes
        // - MAC  := HMAC_appAuthKey(seq || command)

        assert(seq == 0, "CSStartSessionCommand expects seq = 0")
        var packet = Data()
        packet.append(contentsOf: Data(from: seq.bigEndian))
        packet.append(self.bytes)
        let shortMAC = HMAC<SHA256>
            .authenticationCode(for: packet, using: appAuthKey.key)
            .prefix(CSShortMAC.byteCount)
        packet.append(contentsOf: shortMAC)
        return packet
    }
}
