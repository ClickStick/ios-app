import Testing
@testable import ClickStick
import ClickStickKit
import Foundation

@MainActor
struct SnippetStoreTests {
    @Test func inMemoryStoreSavesAndReloads() throws {
        let store = InMemorySnippetStore()
        let tokens = Self.allTokenKinds
        let snippet = Snippet(name: "Test", icon: .network, tokens: tokens)

        try store.save(snippet)

        let loaded = try store.loadAll()
        #expect(loaded.count == 1)
        #expect(loaded.first?.name == "Test")
        #expect(loaded.first?.tokens == tokens)
    }

    @Test func sqliteStorePersistsAcrossInstances() throws {
        let databaseURL = try Self.makeTemporaryDatabaseURL()
        defer { try? FileManager.default.removeItem(at: databaseURL.deletingLastPathComponent()) }
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let snippet = Snippet(
            name: "Database Login",
            icon: .network,
            tokens: Self.allTokenKinds,
            createdAt: createdAt
        )

        try SnippetStore(databaseURL: databaseURL).save(snippet)
        let loaded = try SnippetStore(databaseURL: databaseURL).loadAll()

        #expect(FileManager.default.fileExists(atPath: databaseURL.path))
        #expect(loaded == [snippet])
    }

    @Test func sqliteStoreIsSharedAcrossDevices() throws {
        let databaseURL = try Self.makeTemporaryDatabaseURL()
        defer { try? FileManager.default.removeItem(at: databaseURL.deletingLastPathComponent()) }
        let firstSnippet = Snippet(name: "First", tokens: [.text("one")])
        let secondSnippet = Snippet(name: "Second", tokens: [.text("two")])

        // Snippets are shared: saving from two separate store instances (as two devices'
        // view models would) lands in the same underlying list.
        try SnippetStore(databaseURL: databaseURL).save(firstSnippet)
        try SnippetStore(databaseURL: databaseURL).save(secondSnippet)

        let loaded = try SnippetStore(databaseURL: databaseURL).loadAll()
        #expect(loaded.count == 2)
        #expect(loaded.map(\.id) == [firstSnippet.id, secondSnippet.id])
    }

    @Test func sqliteStoreDeletesAllSnippets() throws {
        let databaseURL = try Self.makeTemporaryDatabaseURL()
        defer { try? FileManager.default.removeItem(at: databaseURL.deletingLastPathComponent()) }

        try SnippetStore(databaseURL: databaseURL).save(Snippet(name: "First", tokens: [.text("one")]))
        try SnippetStore(databaseURL: databaseURL).save(Snippet(name: "Second", tokens: [.text("two")]))

        try SnippetStore(databaseURL: databaseURL).deleteAll()

        #expect(try SnippetStore(databaseURL: databaseURL).loadAll().isEmpty)
    }

    @Test func viewModelCommitShowsSnippet() {
        let device = RecordingSnippetDevice()
        let store = InMemorySnippetStore()
        let vm = SnippetsViewModel(device: device, store: store)
        let snippet = Snippet(name: "A", tokens: [.text("x")])

        vm.commit(snippet)

        #expect(vm.snippets.count == 1)
        vm.delete(snippet)
        #expect(vm.snippets.isEmpty)
    }

    @Test func viewModelSurfacesStorageFailures() {
        let device = RecordingSnippetDevice()
        let vm = SnippetsViewModel(device: device, store: FailingSnippetStore())
        let snippet = Snippet(name: "A", tokens: [.text("x")])

        vm.commit(snippet)

        #expect(vm.alertError != nil)
        #expect(vm.snippets.isEmpty)
    }

    private static var allTokenKinds: [SnippetToken] {
        [
            .text("admin@company.local"), .tab, .enter, .cursor(.left), .functionKey(10), .delay(seconds: 3)
        ]
    }

    private static func makeTemporaryDatabaseURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SnippetStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("snippets.sqlite", isDirectory: false)
    }
}

@MainActor
struct SnippetRunnerTests {
    @Test func runsTokensInOrder() async throws {
        let device = RecordingSnippetDevice()
        device.isConnected = true
        let snippet = Snippet(name: "Login", tokens: [
            .text("admin"), .tab, .text("pw"), .enter, .cursor(.down), .functionKey(5), .delay(seconds: 2)
        ])

        try await SnippetRunner.run(snippet, on: device) { seconds in
            await device.recordDelay(seconds: seconds)
        }

        #expect(device.calls == [
            "text:admin",
            "key:tab",
            "text:pw",
            "key:enter",
            "key:cursor(down)",
            "key:function(5)",
            "delay:2"
        ])
    }

    @Test func reportsUnsupportedCharactersBeforeRunning() {
        let snippet = Snippet(name: "Unsupported", tokens: [.text("admin Щ"), .tab, .text("Ω")])

        let unsupported = SnippetRunner.unsupportedCharacters(in: snippet, layout: .usQWERTY)

        #expect(unsupported.map(String.init) == ["Щ", "Ω"])
    }

    @Test func viewModelBlocksUnsupportedSnippet() {
        let device = RecordingSnippetDevice()
        device.isConnected = true
        device.textEntryKeyboardLayout = .usQWERTY
        let vm = SnippetsViewModel(device: device, store: InMemorySnippetStore())
        let snippet = Snippet(name: "Unsupported", tokens: [.text("admin Щ")])

        vm.run(snippet)

        #expect(vm.isShowingUnsupportedPrompt)
        #expect(vm.runningSnippetID == nil)
        #expect(device.calls.isEmpty)
    }
}

private enum TestStorageError: Error {
    case failed
}

private final class FailingSnippetStore: SnippetStoring {
    func loadAll() throws -> [Snippet] { [] }
    func save(_ snippet: Snippet) throws { throw TestStorageError.failed }
    func delete(_ snippet: Snippet) throws { throw TestStorageError.failed }
    func deleteAll() throws { throw TestStorageError.failed }
}

/// Records the calls SnippetRunner makes so execution order/mapping can be asserted without hardware.
@MainActor
final class RecordingSnippetDevice: SnippetRunningDevice {
    let id = UUID()
    let displayName = "Recorder"
    var isConnected = false
    var textEntryKeyboardLayout = CSKeyboardLayout.usQWERTY
    var textEntryTargetOS = CSTypingOS.windows

    private(set) var calls: [String] = []

    func sendText(_ text: String, layout: CSKeyboardLayout, targetOS: CSTypingOS) async throws {
        calls.append("text:\(text)")
    }

    func sendText(
        _ text: String,
        layout: CSKeyboardLayout,
        targetOS: CSTypingOS,
        onCharacterProgress: @escaping @MainActor (_ sent: Int, _ total: Int) -> Void
    ) async throws {
        calls.append("text:\(text)")
    }

    func saveTextEntryPreferences(layout: CSKeyboardLayout, targetOS: CSTypingOS) {
        textEntryKeyboardLayout = layout
        textEntryTargetOS = targetOS
    }

    func sendSpecialKey(_ key: CSSpecialKey) async throws {
        switch key {
        case .tab: calls.append("key:tab")
        case .enter: calls.append("key:enter")
        case .cursor(let cursorKey): calls.append("key:cursor(\(cursorKey))")
        case .function(let number): calls.append("key:function(\(number))")
        }
    }

    func recordDelay(seconds: Int) {
        calls.append("delay:\(seconds)")
    }
}
