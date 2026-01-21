//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import Foundation
import CommonCrypto
import os.log

/// Helper class for command encryption operations.
internal final class CryptoHelper {
    private static let log = Logger(subsystem: "io.clickstick", category: #file)
    private static let expectedIVSize = 16

    /// - Throws: `CryptoError`
    static func encrypt(_ plaintext: Data, key: CSSessionKey, iv: Data) throws -> Data {
        let keyData = key.withUnsafeBytes { Data($0) }
        guard keyData.count == CSSessionKey.byteCount else {
            log.error("Invalid key size: \(keyData.count) bytes, expected \(CSSessionKey.byteCount)")
            assertionFailure("Invalid key size")
            throw CryptoError.cipherInitError(code: 1)
        }

        guard iv.count == expectedIVSize else {
            log.error("Invalid IV size: \(iv.count) bytes, expected \(expectedIVSize)")
            assertionFailure("Invalid IV size")
            throw CryptoError.cipherInitError(code: 2)
        }

        // TODO: implement encryption
        // AES is too bulky with its 16-byte blocks; ChaCha20 would fit better.
        // But for debug/prototyping phase, we'll keep it in plaintext.
        let ciphertext = Data(plaintext)

        return ciphertext
    }
    
    /// - Throws: `CryptoError`
    static func decrypt(_ ciphertext: Data, key: CSSessionKey, iv: Data) throws -> Data {
        let keyData = key.withUnsafeBytes { Data($0) }
        guard keyData.count == CSSessionKey.byteCount else {
            log.error("Invalid key size: \(keyData.count) bytes, expected \(CSSessionKey.byteCount)")
            assertionFailure("Invalid key size")
            throw CryptoError.cipherInitError(code: 1)
        }

        guard iv.count == expectedIVSize else {
            log.error("Invalid IV size: \(iv.count) bytes, expected \(expectedIVSize)")
            assertionFailure("Invalid IV size")
            throw CryptoError.cipherInitError(code: 2)
        }

        // TODO: implement decryption
        let plaintext = Data(ciphertext)

        return plaintext
    }
}
