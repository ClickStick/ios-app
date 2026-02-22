import Testing
@testable import ClickStick
import ClickStickKit
import Foundation

@MainActor
struct DeepLinkTypeViewModelTests {

    private final class EmptyManager: CSManaging {
        var isDemoMode: Bool = false
        weak var delegate: CSManagerDelegate?

        func startScanning() {}
        func stopScanning() {}

        func knownDevices() -> [CSDevice] {
            return [CSDevice]()
        }
    }

    private func makeRequest(
        text: String = "secret",
        layout: CSKeyboardLayout? = .usQWERTY,
        deviceIdentifier: String? = nil,
        sourceApp: String? = nil,
        successURL: URL? = nil,
        errorURL: URL? = nil,
        cancelURL: URL? = nil
    ) -> TypeRequest {
        TypeRequest(
            text: text,
            layout: layout,
            deviceIdentifier: deviceIdentifier,
            sourceApp: sourceApp,
            successURL: successURL,
            errorURL: errorURL,
            cancelURL: cancelURL
        )
    }

    private func makeDemoService() -> ClickStickService {
        let service = ClickStickService()
        service.isDemoMode = true
        return service
    }

    @Test
    func selectsDeviceByUUIDIdentifier() {
        let service = makeDemoService()
        guard let device = service.devices.first else {
            Issue.record("Expected at least one demo device")
            return
        }

        let viewModel = DeepLinkTypeViewModel(
            request: makeRequest(deviceIdentifier: device.id.uuidString),
            service: service,
            deepLinkHandler: DeepLinkHandler(urlOpener: MockURLOpener()),
            premiumService: PremiumService(autoSyncStoreKit: false)
        )

        #expect(viewModel.selectedDeviceID == device.id)
    }

    @Test
    func selectsDeviceByAliasIdentifier() {
        let service = makeDemoService()
        guard let device = service.devices.first else {
            Issue.record("Expected at least one demo device")
            return
        }

        let viewModel = DeepLinkTypeViewModel(
            request: makeRequest(deviceIdentifier: device.displayName),
            service: service,
            deepLinkHandler: DeepLinkHandler(urlOpener: MockURLOpener()),
            premiumService: PremiumService(autoSyncStoreKit: false)
        )

        #expect(viewModel.selectedDeviceID == device.id)
    }

    @Test
    func fallsBackToFirstKnownDeviceWhenIdentifierDoesNotMatch() {
        let service = makeDemoService()
        guard let firstDevice = service.devices.first else {
            Issue.record("Expected at least one demo device")
            return
        }

        let viewModel = DeepLinkTypeViewModel(
            request: makeRequest(deviceIdentifier: "device-that-does-not-exist"),
            service: service,
            deepLinkHandler: DeepLinkHandler(urlOpener: MockURLOpener()),
            premiumService: PremiumService(autoSyncStoreKit: false)
        )

        #expect(viewModel.selectedDeviceID == firstDevice.id)
    }

    @Test
    func sourceAppMetadataIsExposed() {
        let emptyService = ClickStickService(manager: EmptyManager())
        let viewModel = DeepLinkTypeViewModel(
            request: makeRequest(sourceApp: "KeePassium"),
            service: emptyService,
            deepLinkHandler: DeepLinkHandler(urlOpener: MockURLOpener()),
            premiumService: PremiumService(autoSyncStoreKit: false)
        )

        #expect(viewModel.hasKnownSourceApp)
        #expect(viewModel.sourceAppName == "KeePassium")
    }

    @Test
    func cancelCallsCancelURL() {
        let opener = MockURLOpener()
        let handler = DeepLinkHandler(urlOpener: opener)
        let cancelURL = URL(string: "myapp://cancelled")!
        let emptyService = ClickStickService(manager: EmptyManager())
        let viewModel = DeepLinkTypeViewModel(
            request: makeRequest(cancelURL: cancelURL),
            service: emptyService,
            deepLinkHandler: handler,
            premiumService: PremiumService(autoSyncStoreKit: false)
        )

        viewModel.cancel()

        #expect(opener.openedURL == cancelURL)
    }

    @Test
    func sendTextWithoutDeviceReturnsFalse() async {
        let opener = MockURLOpener()
        let handler = DeepLinkHandler(urlOpener: opener)
        let emptyService = ClickStickService(manager: EmptyManager())
        let viewModel = DeepLinkTypeViewModel(
            request: makeRequest(successURL: URL(string: "myapp://success")!),
            service: emptyService,
            deepLinkHandler: handler,
            premiumService: PremiumService(autoSyncStoreKit: false)
        )

        let success = await viewModel.sendText()

        #expect(!success)
        #expect(!viewModel.isSending)
        #expect(opener.openedURL == nil)
    }
}
