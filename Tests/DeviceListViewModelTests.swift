import Testing
@testable import ClickStick
import ClickStickKit
import Foundation

@MainActor
struct DeviceListViewModelTests {

    private final class MockManager: CSManaging {
        var isDemoMode: Bool = false
        weak var delegate: CSManagerDelegate?

        private(set) var startScanningCallCount = 0
        private(set) var stopScanningCallCount = 0

        func startScanning() {
            startScanningCallCount += 1
        }

        func stopScanning() {
            stopScanningCallCount += 1
        }

        func knownDevices() -> [CSDevice] {
            return [CSDevice]()
        }
    }

    private func setPersistedFlags(hasShownWelcome: Bool, hasDismissedDemoPrompt: Bool) {
        UserDefaults.standard.set(hasShownWelcome, forKey: DeviceListViewModel.hasShownWelcome)
        UserDefaults.standard.set(hasDismissedDemoPrompt, forKey: DeviceListViewModel.hasDismissedDemoPrompt)
    }

    @Test
    func dismissWelcomePersistsFlag() {
        setPersistedFlags(hasShownWelcome: false, hasDismissedDemoPrompt: true)
        let service = ClickStickService(manager: MockManager())
        let viewModel = DeviceListViewModel(service: service, urlOpener: URLOpener())

        viewModel.dismissWelcome()

        #expect(viewModel.hasShownWelcome)
        #expect(UserDefaults.standard.bool(forKey: DeviceListViewModel.hasShownWelcome))
    }

    @Test
    func enableDemoModeDismissesPromptAndUpdatesService() {
        setPersistedFlags(hasShownWelcome: true, hasDismissedDemoPrompt: false)
        let manager = MockManager()
        let service = ClickStickService(manager: manager)
        let viewModel = DeviceListViewModel(service: service, urlOpener: URLOpener())

        viewModel.enableDemoMode()

        #expect(viewModel.hasDismissedDemoPrompt)
        #expect(service.isDemoMode)
        #expect(manager.isDemoMode)
    }

    @Test
    func toggleScanningStartsThenStops() {
        setPersistedFlags(hasShownWelcome: true, hasDismissedDemoPrompt: true)
        let manager = MockManager()
        let service = ClickStickService(manager: manager)
        let viewModel = DeviceListViewModel(service: service, urlOpener: URLOpener())

        viewModel.toggleScanning()
        #expect(viewModel.isScanning)
        #expect(manager.startScanningCallCount == 1)

        viewModel.toggleScanning()
        #expect(!viewModel.isScanning)
        #expect(manager.stopScanningCallCount == 1)
    }

    @Test
    func onboardingCompleteInDemoModeHasNoAnnouncementsAndIsEmpty() {
        setPersistedFlags(hasShownWelcome: true, hasDismissedDemoPrompt: true)
        let manager = MockManager()
        manager.isDemoMode = true
        let service = ClickStickService(manager: manager)
        let viewModel = DeviceListViewModel(service: service, urlOpener: URLOpener())

        #expect(!viewModel.hasAnnouncements)
        #expect(viewModel.isEmpty)
    }

    @Test
    func bluetoothErrorTriggersAnnouncements() {
        setPersistedFlags(hasShownWelcome: true, hasDismissedDemoPrompt: true)
        let service = ClickStickService(manager: MockManager())
        let viewModel = DeviceListViewModel(service: service, urlOpener: URLOpener())

        service.didFail(with: .bluetoothUnavailable(reason: .poweredOff), in: CSManager.shared)

        #expect(viewModel.hasAnnouncements)
        #expect(!viewModel.isEmpty)
    }
}
