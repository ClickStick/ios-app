//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import Foundation
import SQLite3
import os.log

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
private let snippetStoreLog = Logger(subsystem: "io.clickstick", category: "SnippetStore")

/// Storage abstraction for snippets so view-model tests/previews do not depend on the production
/// SQLite database while production storage can still surface real persistence failures.
protocol SnippetStoring: AnyObject {
    func loadAll() throws -> [Snippet]
    func save(_ snippet: Snippet) throws
    func delete(_ snippet: Snippet) throws
    func deleteAll() throws
}

/// SQLite-backed storage for snippets, shared across every paired device.
///
/// Snippets live in an app-sandboxed SQLite database under Application Support. This keeps the
/// data hidden from iOS Files (the app does not expose its documents directory), allows normal
/// device/app backups, and leaves a straightforward path to SQLCipher later if encrypted-at-rest
/// storage becomes necessary.
final class SnippetStore: SnippetStoring {
    private static let databaseFilename = "snippets.sqlite"
    private static let schemaVersion: Int32 = 1

    private let databaseURL: URL

    init(databaseURL: URL? = nil) {
        self.databaseURL = databaseURL ?? Self.defaultDatabaseURL
    }

    /// Loads all snippets, sorted by creation time (append order).
    func loadAll() throws -> [Snippet] {
        try Self.withDatabase(at: databaseURL) { database in
            let sql = """
                SELECT id, name, icon, tokens_json, created_at
                FROM snippets
                ORDER BY created_at ASC, id ASC;
                """
            let statement = try Self.prepare(sql, in: database)
            defer { sqlite3_finalize(statement) }

            var snippets: [Snippet] = []
            while true {
                let status = sqlite3_step(statement)
                switch status {
                case SQLITE_ROW:
                    do {
                        snippets.append(try Self.decodeSnippetRow(from: statement))
                    } catch {
                        // A corrupt/legacy row should not hide otherwise usable snippets.
                        snippetStoreLog.error("Skipping unreadable snippet row: \(error.localizedDescription, privacy: .public)")
                    }
                case SQLITE_DONE:
                    return snippets
                default:
                    throw SnippetStoreError.sqlite(Self.errorMessage(from: database))
                }
            }
        }
    }

    /// Adds or updates a single snippet.
    func save(_ snippet: Snippet) throws {
        try Self.withDatabase(at: databaseURL) { database in
            let sql = """
                INSERT INTO snippets (id, name, icon, tokens_json, created_at)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    name = excluded.name,
                    icon = excluded.icon,
                    tokens_json = excluded.tokens_json,
                    created_at = excluded.created_at;
                """
            let statement = try Self.prepare(sql, in: database)
            defer { sqlite3_finalize(statement) }

            let tokensData = try JSONEncoder().encode(snippet.tokens)
            try Self.bind(snippet.id.uuidString, to: statement, at: 1, in: database)
            try Self.bind(snippet.name, to: statement, at: 2, in: database)
            try Self.bind(snippet.icon.rawValue, to: statement, at: 3, in: database)
            try Self.bind(tokensData, to: statement, at: 4, in: database)
            try Self.bind(snippet.createdAt.timeIntervalSince1970, to: statement, at: 5, in: database)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw SnippetStoreError.sqlite(Self.errorMessage(from: database))
            }
        }
    }

    /// Deletes a single snippet.
    func delete(_ snippet: Snippet) throws {
        try Self.withDatabase(at: databaseURL) { database in
            let statement = try Self.prepare("DELETE FROM snippets WHERE id = ?;", in: database)
            defer { sqlite3_finalize(statement) }

            try Self.bind(snippet.id.uuidString, to: statement, at: 1, in: database)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw SnippetStoreError.sqlite(Self.errorMessage(from: database))
            }
        }
    }

    /// Deletes every snippet.
    func deleteAll() throws {
        try Self.withDatabase(at: databaseURL) { database in
            try Self.execute("DELETE FROM snippets;", in: database)
        }
    }

    // MARK: - Database lifecycle

    private static var defaultDatabaseURL: URL {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return applicationSupport
            .appendingPathComponent("Snippets", isDirectory: true)
            .appendingPathComponent(databaseFilename, isDirectory: false)
    }

    private static func withDatabase<T>(at databaseURL: URL, perform work: (OpaquePointer) throws -> T) throws -> T {
        try prepareDatabaseLocation(for: databaseURL)

        var database: OpaquePointer?
        let status = sqlite3_open_v2(
            databaseURL.path,
            &database,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard status == SQLITE_OK, let openDatabase = database else {
            let message = database.map(errorMessage) ?? "Unable to open the snippets database."
            if let database {
                sqlite3_close(database)
            }
            throw SnippetStoreError.openFailed(message)
        }
        defer { sqlite3_close(openDatabase) }

        protectDatabaseFile(at: databaseURL)
        sqlite3_busy_timeout(openDatabase, 5_000)
        try migrate(openDatabase)
        return try work(openDatabase)
    }

    private static func prepareDatabaseLocation(for databaseURL: URL) throws {
        let directory = databaseURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

#if os(iOS) && !targetEnvironment(macCatalyst)
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: directory.path
        )
#endif
    }

    private static func protectDatabaseFile(at databaseURL: URL) {
#if os(iOS) && !targetEnvironment(macCatalyst)
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: databaseURL.path
        )
#endif
    }

    private static func migrate(_ database: OpaquePointer) throws {
        try execute(
            """
            CREATE TABLE IF NOT EXISTS snippets (
                id TEXT NOT NULL PRIMARY KEY,
                name TEXT NOT NULL,
                icon TEXT NOT NULL,
                tokens_json BLOB NOT NULL,
                created_at REAL NOT NULL
            );
            CREATE INDEX IF NOT EXISTS snippets_created_at
                ON snippets(created_at, id);
            PRAGMA user_version = \(schemaVersion);
            """,
            in: database
        )
    }

    // MARK: - SQLite helpers

    private static func execute(_ sql: String, in database: OpaquePointer) throws {
        var error: UnsafeMutablePointer<CChar>?
        let status = sqlite3_exec(database, sql, nil, nil, &error)
        guard status == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? errorMessage(from: database)
            sqlite3_free(error)
            throw SnippetStoreError.sqlite(message)
        }
    }

    private static func prepare(_ sql: String, in database: OpaquePointer) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw SnippetStoreError.sqlite(errorMessage(from: database))
        }
        return statement
    }

    private static func bind(_ value: String, to statement: OpaquePointer, at index: Int32, in database: OpaquePointer) throws {
        guard sqlite3_bind_text(statement, index, value, -1, sqliteTransient) == SQLITE_OK else {
            throw SnippetStoreError.sqlite(errorMessage(from: database))
        }
    }

    private static func bind(_ value: Data, to statement: OpaquePointer, at index: Int32, in database: OpaquePointer) throws {
        let status = value.withUnsafeBytes { buffer in
            sqlite3_bind_blob(statement, index, buffer.baseAddress, Int32(value.count), sqliteTransient)
        }
        guard status == SQLITE_OK else {
            throw SnippetStoreError.sqlite(errorMessage(from: database))
        }
    }

    private static func bind(_ value: TimeInterval, to statement: OpaquePointer, at index: Int32, in database: OpaquePointer) throws {
        guard sqlite3_bind_double(statement, index, value) == SQLITE_OK else {
            throw SnippetStoreError.sqlite(errorMessage(from: database))
        }
    }

    private static func decodeSnippetRow(from statement: OpaquePointer) throws -> Snippet {
        guard
            let id = UUID(uuidString: try columnText(statement, index: 0)),
            let icon = SnippetIcon(rawValue: try columnText(statement, index: 2))
        else {
            throw SnippetStoreError.invalidRow
        }

        let name = try columnText(statement, index: 1)
        let tokensData = try columnData(statement, index: 3)
        let tokens = try JSONDecoder().decode([SnippetToken].self, from: tokensData)
        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 4))

        return Snippet(id: id, name: name, icon: icon, tokens: tokens, createdAt: createdAt)
    }

    private static func columnText(_ statement: OpaquePointer, index: Int32) throws -> String {
        guard let value = sqlite3_column_text(statement, index) else {
            throw SnippetStoreError.invalidRow
        }
        return String(cString: value)
    }

    private static func columnData(_ statement: OpaquePointer, index: Int32) throws -> Data {
        let byteCount = sqlite3_column_bytes(statement, index)
        guard byteCount > 0, let bytes = sqlite3_column_blob(statement, index) else {
            throw SnippetStoreError.invalidRow
        }
        return Data(bytes: bytes, count: Int(byteCount))
    }

    private static func errorMessage(from database: OpaquePointer) -> String {
        String(cString: sqlite3_errmsg(database))
    }
}

private enum SnippetStoreError: LocalizedError {
    case openFailed(String)
    case sqlite(String)
    case invalidRow

    var errorDescription: String? {
        switch self {
        case .openFailed(let message):
            "Could not open the snippets database: \(message)"
        case .sqlite(let message):
            "Snippet database error: \(message)"
        case .invalidRow:
            "Snippet database contains an invalid row."
        }
    }
}

/// Mutable in-memory snippet storage used by previews and unit tests.
final class InMemorySnippetStore: SnippetStoring {
    private var snippets: [Snippet]

    init(snippets: [Snippet] = []) {
        self.snippets = snippets
    }

    func loadAll() throws -> [Snippet] {
        snippets.sorted { $0.createdAt < $1.createdAt }
    }

    func save(_ snippet: Snippet) throws {
        snippets.removeAll { $0.id == snippet.id }
        snippets.append(snippet)
    }

    func delete(_ snippet: Snippet) throws {
        snippets.removeAll { $0.id == snippet.id }
    }

    func deleteAll() throws {
        snippets.removeAll()
    }
}
