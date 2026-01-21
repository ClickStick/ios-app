//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import Foundation

public enum CryptoError: LocalizedError {
    case cipherInitError(code: Int)
    case encryptError(code: Int32)
    case decryptError(code: Int32)
}
