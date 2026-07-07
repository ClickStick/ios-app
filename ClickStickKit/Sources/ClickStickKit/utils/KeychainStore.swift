//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import Foundation
import os.log
import Security

private let keychainLog = Logger(subsystem: "io.clickstick", category: "KeychainStore")

/// Generic keychain-backed store for `Codable` values.
///
/// Values are stored as `kSecClassGenericPassword` items under a fixed `service`, one item
/// per `account`. This centralizes all `SecItem` query construction so concrete stores (device
/// settings, snippets, …) don't each re-implement the keychain plumbing — they only decide the
/// service name, accessibility, and how accounts map to their model.
public struct KeychainStore {
    /// Keychain service the items are grouped under (`kSecAttrService`).
    public let service: String

    /// Optional keychain access group for sharing items between the app and its extensions.
    public let accessGroup: String?

    /// Optional `kSecAttrAccessible` value applied to newly added items. When `nil`, the item
    /// uses the keychain default (`kSecAttrAccessibleWhenUnlocked`), preserving legacy behavior
    /// for stores that never set it.
    public let accessibility: CFString?

    public init(service: String, accessGroup: String?, accessibility: CFString? = nil) {
        self.service = service
        self.accessGroup = accessGroup
        self.accessibility = accessibility
    }

    // MARK: - Query building

    private func baseQuery(account: String? = nil) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        if let account {
            query[kSecAttrAccount as String] = account
        }
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }

    // MARK: - Operations

    /// Returns true iff an item exists for `account`.
    public func has(account: String) -> Bool {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = false
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    /// Loads and decodes the value stored for `account`, or `nil` if none exists.
    public func load<Value: Decodable>(_ type: Value.Type, account: String) throws -> Value? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { throw KeychainError.invalidData }
            return try JSONDecoder().decode(Value.self, from: data)
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.operationFailed(status)
        }
    }

    /// Loads and decodes every item stored under this service.
    public func loadAll<Value: Decodable>(_ type: Value.Type) throws -> [Value] {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitAll

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            let decoder = JSONDecoder()
            let dataItems: [Data]
            if let items = result as? [Data] {
                dataItems = items
            } else if let data = result as? Data {
                dataItems = [data]
            } else {
                throw KeychainError.invalidData
            }
            // Decode leniently: a single corrupt or legacy-schema item must not blank the whole
            // result. Skip (and log) items that fail to decode rather than aborting the load.
            return dataItems.compactMap { data in
                do {
                    return try decoder.decode(Value.self, from: data)
                } catch {
                    keychainLog.error("Skipping undecodable keychain item in \(service, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    return nil
                }
            }
        case errSecItemNotFound:
            return []
        default:
            throw KeychainError.operationFailed(status)
        }
    }

    /// Encodes and stores `value` for `account`, updating an existing item or adding a new one.
    ///
    /// Attempts the add first rather than checking existence beforehand: `SecItemAdd` is atomic,
    /// so concurrent saves for the same account can't both observe "not found" and both try to add.
    public func save<Value: Encodable>(_ value: Value, account: String) throws {
        let data = try JSONEncoder().encode(value)
        let query = baseQuery(account: account)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        if let accessibility {
            addQuery[kSecAttrAccessible as String] = accessibility
        }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        switch addStatus {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let attributes: [String: Any] = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else { throw KeychainError.operationFailed(updateStatus) }
        default:
            throw KeychainError.operationFailed(addStatus)
        }
    }

    /// Deletes the item stored for `account`. Missing items are treated as success.
    public func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.operationFailed(status)
        }
    }

    /// Deletes every item stored under this service. Missing items are treated as success.
    public func deleteAll() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.operationFailed(status)
        }
    }
}
