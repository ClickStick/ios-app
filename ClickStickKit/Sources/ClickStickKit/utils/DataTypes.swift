//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import Foundation
import CryptoKit

/// Sequence counter in outgoing packets
typealias CSSequenceCounter = UInt16
extension CSSequenceCounter {
    static var byteCount: Int { MemoryLayout<Self>.size }
}

/// HMAC-SHA256 shortened to first 16 bytes
typealias CSShortMAC = Data
extension CSShortMAC {
    static var byteCount: Int { 16 }
}

typealias CSSessionKey = SymmetricKey
extension CSSessionKey {
    static var byteCount: Int { 32 }

    /// Predefined all-zero key for the `START_SESSION` command.
    static let zeros: Self = .init(data: Data(repeating: 0, count: byteCount))
}
