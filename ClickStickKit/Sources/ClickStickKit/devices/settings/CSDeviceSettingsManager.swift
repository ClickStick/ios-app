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
    
    /// Keychain access group for sharing between app and extensions.
    /// Format: $(AppIdentifierPrefix)io.clickstick.app
    /// This is set at runtime via `configure(accessGroup:)` to allow sharing keychain items.
    private static var keychainAccessGroup: String?
    
    /// Configure the keychain access group for sharing between app and extensions.
    /// Call this early in app/extension initialization.
    /// - Parameter accessGroup: The keychain access group (e.g., "TEAM_ID.io.clickstick.app")
    public static func configure(accessGroup: String?) {
        keychainAccessGroup = accessGroup
    }
    
    /// Returns base query attributes including access group if configured
    private static func baseQueryAttributes(for deviceUUID: UUID) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: deviceUUID.uuidString
        ]
        if let accessGroup = keychainAccessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
    
    /// Returns base query attributes for service-level operations
    private static func baseServiceQueryAttributes() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService
        ]
        if let accessGroup = keychainAccessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
    
    // MARK: - Keychain Operations

    /// Returns true iff there are settings saved for this device.
    public static func hasSettings(for deviceUUID: UUID) -> Bool {
        var query = baseQueryAttributes(for: deviceUUID)
        query[kSecReturnData as String] = false
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Loads device settings from the keychain
    /// - Parameter deviceUUID: The unique identifier for the device
    /// - Returns: CSDeviceSettings instance loaded from keychain, or nil if not found
    /// - Throws: KeychainError if the operation fails
    public static func loadSettings(for deviceUUID: UUID) throws -> CSDeviceSettings? {
        var query = baseQueryAttributes(for: deviceUUID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        
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
        
        let query = baseQueryAttributes(for: settings.deviceUUID)
        
        // Check if item exists
        var result: AnyObject?
        let checkStatus = SecItemCopyMatching(query as CFDictionary, &result)
        
        if checkStatus == errSecSuccess {
            // Update existing item
            let updateAttributes: [String: Any] = [
                kSecValueData as String: data
            ]
            
            let status = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
            if status != errSecSuccess {
                throw KeychainError.operationFailed(status)
            }
        } else if checkStatus == errSecItemNotFound {
            // Add new item
            var addQuery = query
            addQuery[kSecValueData as String] = data
            
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
        let query = baseQueryAttributes(for: deviceUUID)
        
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.operationFailed(status)
        }
    }

    /// Deletes all the settings for all the devices from the keychain.
    /// - Throws: KeychainError if the operation fails
    public static func deleteAllSettings() throws {
        let query = baseServiceQueryAttributes()

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
