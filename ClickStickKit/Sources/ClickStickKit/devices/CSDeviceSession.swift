//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import Foundation
import CryptoKit
import os.log

private let log = Logger(subsystem: "io.clickstick", category: #file)

final class CSDeviceSession {
    private static let protocolVersion: UInt8 = 1
    private static let keySize = 32
    private static let macSize = CSShortMAC.byteCount

    /// Parses session parameters from raw data of the `INIT_SESSION` state:
    /// https://clickstick.io/docs/protocol.html#state-init-session
    /// Returns the received and validated public key,
    /// or `nil` if data is malformed or MAC is invalid.
    static func parse(
        sessionData: Data,
        appAuthKey: CSAppAuthKey
    ) -> Curve25519.KeyAgreement.PublicKey? {
        // Must have at least 1 (state) + 1 (version) + 32 (public key) + 16 (MAC) = 50 bytes
        let expectedSize = 1 + 1 + Self.keySize + Self.macSize
        guard sessionData.count == expectedSize else {
            log.error("Session data size mismatch: \(sessionData.count) instead of \(expectedSize) bytes. Aborting…")
            return nil
        }
        guard sessionData.first == CSDevice.State.initSession.rawValue else {
            log.error("Unexpected device state, aborting")
            return nil
        }

        // Parsing session data
        let versionStart = sessionData.startIndex + 1
        let pubKeyStart = versionStart + 1
        let pubKeyEnd = pubKeyStart + Self.keySize
        let macStart = pubKeyEnd
        let macEnd = macStart + Self.macSize

        let protocolVersion = sessionData[versionStart]
        let publicKeyData = sessionData[pubKeyStart..<pubKeyEnd]
        let publishedMAC = sessionData[macStart..<macEnd]

        // Sanity checks
        guard protocolVersion == Self.protocolVersion else {
            assertionFailure()
            log.error("Unexpected protocol version (\(protocolVersion)), aborting")
            return nil
        }

        let remotePublicKey: Curve25519.KeyAgreement.PublicKey
        do {
            remotePublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: publicKeyData)
        } catch {
            log.error("Malformed device public key, aborting. Error: \(error)")
            return nil
        }

        // Compute HMAC-SHA256 over (version || incomingPublicKey), truncate to 16 bytes
        var hmacInput = Data()
        hmacInput.append(protocolVersion)
        hmacInput.append(contentsOf: publicKeyData)
        let computedMAC = Data(HMAC<SHA256>
            .authenticationCode(for: hmacInput, using: appAuthKey.key)
            .prefix(Self.macSize))

        guard publishedMAC == computedMAC else {
            log.error("Session parameters: MAC verification failed. Possible device impersonation.")
            return nil
        }
        return remotePublicKey
    }

    static func make(
        publicKey: Curve25519.KeyAgreement.PublicKey,
        appAuthKey: CSAppAuthKey
    ) -> Data {
        // TODO: remove after debug
        publicKey.rawRepresentation.withUnsafeBytes { log.debug("Mobile public key: \(Data($0).hexString)") }

        var sessionData = Data()
        // skip status byte for now
        sessionData.append(Self.protocolVersion)
        sessionData.append(publicKey.rawRepresentation)
        let shortMAC = HMAC<SHA256>
            .authenticationCode(for: sessionData, using: appAuthKey.key)
            .prefix(CSShortMAC.byteCount)
        sessionData.append(Data(shortMAC))
        // prepend the status byte
        sessionData.insert(CSDevice.State.initSession.rawValue, at: 0)
        return sessionData
    }

    /// Calculates local session key based on locally generated private key,
    /// a public key received from the remote party, and pre-shared appAuthKey.
    /// https://clickstick.io/docs/protocol.html#session-start
    ///
    /// This function works both for mobile side and mock "hardware side" of CSMockDevice,
    /// just by swapping the meaning of "local" and "remote".
    /// - Returns: generated session key: `HKDF(ECDH(localPrivateKey, remotePublicKey), appAuthKey)`,
    ///     or `nil` in case of errors.
    static func deriveSessionKey(
        localPrivateKey: Curve25519.KeyAgreement.PrivateKey,
        remotePublicKey: Curve25519.KeyAgreement.PublicKey,
        appAuthKey: CSAppAuthKey
    ) -> CSSessionKey? {
        // After receiving remotePublicKey, we compute:
        //   sharedSecret := ECDH(dongleSecretKey, mobilePublicKey)
        //   sessionKey := HKDF(sharedSecret, appAuthKey)
        do {
            let sharedSecret = try localPrivateKey.sharedSecretFromKeyAgreement(with: remotePublicKey)
            let appAuthKeyData = appAuthKey.key.withUnsafeBytes { Array($0) }
            let sessionKey = sharedSecret.hkdfDerivedSymmetricKey(
                using: SHA256.self,
                salt: appAuthKeyData,
                sharedInfo: Data(),
                outputByteCount: CSSessionKey.byteCount)

            // TODO: remove logging after debug
            let mobilePublicKey = localPrivateKey.publicKey
            appAuthKeyData.withUnsafeBytes { log.debug("App auth key: \(Data($0).hexString)") }
            mobilePublicKey.rawRepresentation.withUnsafeBytes { log.debug("Mobile public key: \(Data($0).hexString)") }
            remotePublicKey.rawRepresentation.withUnsafeBytes { log.debug("Dongle public key: \(Data($0).hexString)") }
            sharedSecret.withUnsafeBytes { log.debug("Shared secret: \(Data($0).hexString)") }
            sessionKey.withUnsafeBytes { log.debug("Session key: \(Data($0).hexString)") }

            return sessionKey
        } catch {
            log.error("Failed to session key: \(error)")
            assertionFailure()
            return nil
        }
    }
}
