//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import Foundation

/// Manages device-specific settings stored in the keychain
public class CSDeviceSettings: Codable {

    // MARK: - Properties

    /// The device's unique identifier used as the keychain account
    public let deviceUUID: UUID

    /// Optional app authentication key
    public var appAuthKey: CSAppAuthKey

    /// User-defined device alias
    public var deviceAlias: String?

    /// Preferred keyboard layout for text entry on this device.
    public var keyboardLayout: CSKeyboardLayout

    /// Preferred target operating system for text entry on this device.
    public var typingOS: CSTypingOS

    // MARK: - Initialization

    /// Creates a new CSDeviceSettings instance for the specified device
    /// - Parameters
    ///   - deviceUUID: The unique identifier for the device
    ///   - appAuthKey: App authentication key
    public init(deviceUUID: UUID, appAuthKey: CSAppAuthKey) {
        self.deviceUUID = deviceUUID
        self.appAuthKey = appAuthKey
        self.keyboardLayout = CSKeyboardLayout.fromSystemLocale()
        self.typingOS = .windows
    }

    /// Creates a new CSDeviceSettings instance with default values
    /// - Parameters:
    ///   - deviceUUID: The unique identifier for the device
    ///   - appAuthKey: App authentication key
    ///   - deviceName: Optional user-defined device alias
    ///   - keyboardLayout: Preferred keyboard layout for text entry
    ///   - typingOS: Preferred target operating system for text entry
    public init(
        deviceUUID: UUID,
        appAuthKey: CSAppAuthKey,
        deviceAlias: String? = nil,
        keyboardLayout: CSKeyboardLayout = CSKeyboardLayout.fromSystemLocale(),
        typingOS: CSTypingOS = .windows
    ) {
        self.deviceUUID = deviceUUID
        self.appAuthKey = appAuthKey
        self.deviceAlias = deviceAlias
        self.keyboardLayout = keyboardLayout
        self.typingOS = typingOS
    }
}
