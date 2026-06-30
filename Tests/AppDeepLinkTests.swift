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
    func rejectsOtherSchemesAndCommands() throws {
        #expect(AppDeepLink(url: try #require(URL(string: "https://add-device"))) == nil)
        #expect(AppDeepLink(url: try #require(URL(string: "clickstick://unknown"))) == nil)
    }
}
