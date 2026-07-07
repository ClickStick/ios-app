//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import Foundation
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

    /// Shared keychain access group, exposed for code that needs to align with the same
    /// app/extension configuration set via `configure(accessGroup:)`.
    public static var accessGroup: String? { keychainAccessGroup }

    /// The keychain-backed store for device settings. Rebuilt per access so it always reflects
    /// the access group configured at runtime. Accessibility is left at the keychain default to
    /// preserve compatibility with items saved by earlier app versions.
    private static var store: KeychainStore {
        KeychainStore(service: keychainService, accessGroup: keychainAccessGroup)
    }

    // MARK: - Keychain Operations

    /// Returns true iff there are settings saved for this device.
    public static func hasSettings(for deviceUUID: UUID) -> Bool {
        store.has(account: deviceUUID.uuidString)
    }

    /// Loads device settings from the keychain
    /// - Parameter deviceUUID: The unique identifier for the device
    /// - Returns: CSDeviceSettings instance loaded from keychain, or nil if not found
    /// - Throws: KeychainError if the operation fails
    public static func loadSettings(for deviceUUID: UUID) throws -> CSDeviceSettings? {
        try store.load(CSDeviceSettings.self, account: deviceUUID.uuidString)
    }

    /// Loads settings for all saved devices from the keychain.
    /// - Returns: All saved device settings, or an empty array if none exist.
    /// - Throws: KeychainError if the operation fails.
    public static func loadAllSettings() throws -> [CSDeviceSettings] {
        try store.loadAll(CSDeviceSettings.self)
    }

    /// Saves device settings to the keychain
    /// - Parameter settings: The CSDeviceSettings instance to save
    /// - Throws: KeychainError if the operation fails
    public static func saveSettings(_ settings: CSDeviceSettings) throws {
        try store.save(settings, account: settings.deviceUUID.uuidString)
    }

    /// Deletes device settings from the keychain
    /// - Parameter deviceUUID: The unique identifier for the device
    /// - Throws: KeychainError if the operation fails
    public static func deleteSettings(for deviceUUID: UUID) throws {
        try store.delete(account: deviceUUID.uuidString)
    }

    /// Deletes all the settings for all the devices from the keychain.
    /// - Throws: KeychainError if the operation fails
    public static func deleteAllSettings() throws {
        try store.deleteAll()
    }
}
