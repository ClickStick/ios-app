//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import Foundation
import CryptoKit
import Security

/// Manages keychain operations for CSDeviceSettings
public class CSDeviceSettingsManager {
    
    // MARK: - Keychain Configuration
    
    private static let keychainService = "io.clickstick.deviceSettings"
    
    // MARK: - Keychain Operations

    /// Returns true iff there are settings saved for this device.
    public static func hasSettings(for deviceUUID: UUID) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: deviceUUID.uuidString,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Loads device settings from the keychain
    /// - Parameter deviceUUID: The unique identifier for the device
    /// - Returns: CSDeviceSettings instance loaded from keychain, or nil if not found
    /// - Throws: KeychainError if the operation fails
    public static func loadSettings(for deviceUUID: UUID) throws -> CSDeviceSettings? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: deviceUUID.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.invalidData
            }
            return try deserializeSettings(from: data, deviceUUID: deviceUUID)
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.operationFailed(status)
        }
    }
    
    /// Saves device settings to the keychain
    /// - Parameter settings: The CSDeviceSettings instance to save
    /// - Throws: KeychainError if the operation fails
    public static func saveSettings(_ settings: CSDeviceSettings) throws {
        let data = try serializeSettings(settings)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: settings.deviceUUID.uuidString
        ]
        
        // Check if item exists
        var result: AnyObject?
        let checkStatus = SecItemCopyMatching(query as CFDictionary, &result)
        
        if checkStatus == errSecSuccess {
            // Update existing item
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
                kSecAttrAccount as String: settings.deviceUUID.uuidString
            ]
            
            let updateAttributes: [String: Any] = [
                kSecValueData as String: data
            ]
            
            let status = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
            if status != errSecSuccess {
                throw KeychainError.operationFailed(status)
            }
        } else if checkStatus == errSecItemNotFound {
            // Add new item
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
                kSecAttrAccount as String: settings.deviceUUID.uuidString,
                kSecValueData as String: data
            ]
            
            let status = SecItemAdd(addQuery as CFDictionary, nil)
            if status != errSecSuccess {
                throw KeychainError.operationFailed(status)
            }
        } else {
            throw KeychainError.operationFailed(checkStatus)
        }
    }
    
    /// Deletes device settings from the keychain
    /// - Parameter deviceUUID: The unique identifier for the device
    /// - Throws: KeychainError if the operation fails
    public static func deleteSettings(for deviceUUID: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: deviceUUID.uuidString
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.operationFailed(status)
        }
    }

    /// Deletes all the settings for all the devices from the keychain.
    /// - Throws: KeychainError if the operation fails
    public static func deleteAllSettings() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.operationFailed(status)
        }
    }

    // MARK: - Serialization
    
    private static func serializeSettings(_ settings: CSDeviceSettings) throws -> Data {
        return try JSONEncoder().encode(settings)
    }
    
    private static func deserializeSettings(from data: Data, deviceUUID: UUID) throws -> CSDeviceSettings {
        let decoder = JSONDecoder()
        return try decoder.decode(CSDeviceSettings.self, from: data)
    }
}
