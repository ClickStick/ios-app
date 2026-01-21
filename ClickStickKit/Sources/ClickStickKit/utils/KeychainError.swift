//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import Foundation

public enum KeychainError: Error, LocalizedError {
    case operationFailed(OSStatus)
    case invalidData
    
    public var errorDescription: String? {
        switch self {
        case .operationFailed(let status):
            return "Keychain operation failed with status: \(status)"
        case .invalidData:
            return "Invalid data format in keychain"
        }
    }
}
