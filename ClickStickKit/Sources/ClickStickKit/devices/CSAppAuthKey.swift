//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import Foundation
import CryptoKit
import os.log

private let log = Logger(subsystem: "io.clickstick", category: #file)
final public class CSAppAuthKey: Codable {

    /// Expected size of the  app auth key
    static let size = SymmetricKeySize(bitCount: byteCount * 8)
    static let byteCount = 16

    /// Predefined auth key for mock devices.
    public static let demo = CSAppAuthKey(data: Data(repeating: 0, count: byteCount))!

    /// SymmetricKey derived from the rawData.
    public let key: SymmetricKey

    init?(data: Data) {
        guard data.count == Self.byteCount else {
            log.error("Invalid app auth key data size, rejecting")
            return nil
        }
        self.key = SymmetricKey(data: data)
    }

    /// Returns key as a sequence of hex digits.
    public func toHexString() -> String {
        return key.withUnsafeBytes { Data($0).hexString }
    }

    /// Builds a `CSAppAuthKey` from its hex-formatted representation.
    public static func fromHexString(_ string: String?) -> CSAppAuthKey? {
        guard let string else { return nil }

        let cleanedString = string.replacingOccurrences(of: " ", with: "")
        guard let data = Data(hexString: cleanedString) else {
            return nil
        }

        // Create CSAppAuthKey from the data
        return CSAppAuthKey(data: data)
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case keyData
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let keyData = key.withUnsafeBytes { Data($0) }
        try container.encode(keyData, forKey: .keyData)
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let keyData = try container.decode(Data.self, forKey: .keyData)

        guard let authKey = CSAppAuthKey(data: keyData) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid key data size"
                )
            )
        }
        self.key = authKey.key
    }
}
