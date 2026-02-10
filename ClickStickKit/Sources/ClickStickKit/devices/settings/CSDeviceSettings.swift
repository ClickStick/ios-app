//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import CryptoKit
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

    // MARK: - Initialization

    /// Creates a new CSDeviceSettings instance for the specified device
    /// - Parameters
    ///   - deviceUUID: The unique identifier for the device
    ///   - appAuthKey: App authentication key
    public init(deviceUUID: UUID, appAuthKey: CSAppAuthKey) {
        self.deviceUUID = deviceUUID
        self.appAuthKey = appAuthKey
    }

    /// Creates a new CSDeviceSettings instance with default values
    /// - Parameters:
    ///   - deviceUUID: The unique identifier for the device
    ///   - appAuthKey: App authentication key
    ///   - deviceName: Optional user-defined device alias
    public init(deviceUUID: UUID, appAuthKey: CSAppAuthKey, deviceAlias: String? = nil) {
        self.deviceUUID = deviceUUID
        self.appAuthKey = appAuthKey
        self.deviceAlias = deviceAlias
    }

    // MARK: - Codable

    public enum CodingKeys: String, CodingKey {
        case deviceUUID
        case appAuthKey
        case deviceAlias
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(deviceUUID, forKey: .deviceUUID)
        try container.encode(appAuthKey, forKey: .appAuthKey)
        try container.encodeIfPresent(deviceAlias, forKey: .deviceAlias)
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        deviceUUID = try container.decode(UUID.self, forKey: .deviceUUID)
        appAuthKey = try container.decode(CSAppAuthKey.self, forKey: .appAuthKey)
        deviceAlias = try container.decodeIfPresent(String.self, forKey: .deviceAlias)
    }
}
