import Foundation
import Testing
@testable import ClickStick

struct AppDeepLinkTests {
    @Test
    func parsesAddDeviceHostURL() throws {
        let url = try #require(URL(string: "clickstick://add-device"))

        #expect(AppDeepLink(url: url) == .addDevice)
    }

    @Test
    func parsesAddDevicePathURL() throws {
        let url = try #require(URL(string: "clickstick:///add-device"))

        #expect(AppDeepLink(url: url) == .addDevice)
    }

    @Test
    func parsesSendTextXCallbackURL() throws {
        let deviceID = try #require(UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
        let url = try #require(URL(string: "clickstick://x-callback-url/send-text?device=11111111-2222-3333-4444-555555555555&text=hello%20world"))

        #expect(AppDeepLink(url: url) == .sendText(SendTextDeepLink(deviceID: deviceID, text: "hello world")))
    }

    @Test
    func parsesDoubleEscapedSendTextCallbackURL() throws {
        // Only callback URLs get a second decode pass -- unlike free text, a URL either
        // resolves into something usable or it doesn't, so re-decoding it can't silently
        // corrupt user-entered content the way it would for the "text" field.
        let url = try #require(URL(string: "clickstick://x-callback-url/send-text?text=hello%2520world&x-success=sourceapp%253A%252F%252Fdone"))

        #expect(AppDeepLink(url: url) == .sendText(SendTextDeepLink(
            deviceID: nil,
            text: "hello%20world",
            callback: SendTextCallback(success: try #require(URL(string: "sourceapp://done")))
        )))
    }

    @Test
    func parsesSendTextCallbackParameters() throws {
        let url = try #require(URL(string: "clickstick://x-callback-url/send-text?text=hello&x-source=SourceApp&x-success=sourceapp%3A%2F%2Fx-callback-url%2Fdone&x-error=sourceapp%3A%2F%2Fx-callback-url%2Ferror&x-cancel=sourceapp%3A%2F%2Fx-callback-url%2Fcancel"))

        #expect(AppDeepLink(url: url) == .sendText(SendTextDeepLink(
            deviceID: nil,
            text: "hello",
            callback: SendTextCallback(
                source: "SourceApp",
                success: try #require(URL(string: "sourceapp://x-callback-url/done")),
                error: try #require(URL(string: "sourceapp://x-callback-url/error")),
                cancel: try #require(URL(string: "sourceapp://x-callback-url/cancel"))
            )
        )))
    }

    @Test
    func rejectsInvalidSendTextLinks() throws {
        #expect(AppDeepLink(url: try #require(URL(string: "clickstick://x-callback-url/send-text"))) == nil)
        #expect(AppDeepLink(url: try #require(URL(string: "clickstick://x-callback-url/send-text?text="))) == nil)
        #expect(AppDeepLink(url: try #require(URL(string: "clickstick://x-callback-url/send-text?text=hello&device=not-a-uuid"))) == nil)
    }

    @Test
    func rejectsOtherSchemesAndCommands() throws {
        #expect(AppDeepLink(url: try #require(URL(string: "https://add-device"))) == nil)
        #expect(AppDeepLink(url: try #require(URL(string: "clickstick://unknown"))) == nil)
    }
}
