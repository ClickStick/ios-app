import Testing
@testable import ClickStick
import ClickStickKit

@MainActor
struct ClickStickServiceTests {

    private final class MockManager: CSManaging {
        var isDemoMode: Bool = false
        weak var delegate: CSManagerDelegate?

        private(set) var startScanningCallCount = 0
        private(set) var stopScanningCallCount = 0
        private(set) var knownDevicesCallCount = 0

        func startScanning() {
            startScanningCallCount += 1
        }

        func stopScanning() {
            stopScanningCallCount += 1
        }

        func knownDevices() -> [CSDevice] {
            knownDevicesCallCount += 1
            return [CSDevice]()
        }
    }

    @Test
    func startScanningIsIdempotent() {
        let manager = MockManager()
        let service = ClickStickService(manager: manager)

        service.startScanning()
        service.startScanning()

        #expect(service.isScanning)
        #expect(manager.startScanningCallCount == 1)
    }

    @Test
    func startScanningAfterStopStartsAgain() {
        let manager = MockManager()
        let service = ClickStickService(manager: manager)

        service.startScanning()
        service.stopScanning()
        service.startScanning()

        #expect(service.isScanning)
        #expect(manager.startScanningCallCount == 2)
        #expect(manager.stopScanningCallCount == 1)
    }

    @Test
    func stopScanningSetsStateAndForwardsCall() {
        let manager = MockManager()
        let service = ClickStickService(manager: manager)

        service.startScanning()
        service.stopScanning()

        #expect(!service.isScanning)
        #expect(manager.stopScanningCallCount == 1)
    }

    @Test
    func startScanningClearsPreviousBluetoothError() async {
        let manager = MockManager()
        let service = ClickStickService(manager: manager)

        service.didFail(with: .bluetoothUnavailable(reason: .poweredOff), in: CSManager.shared)
        // Yield so the fire-and-forget Task { @MainActor } in didFail executes
        await Task.yield()
        #expect(service.bluetoothError != nil)

        service.startScanning()

        #expect(service.bluetoothError == nil)
    }

    @Test
    func didFailUpdatesErrorAndStopsScanning() async {
        let manager = MockManager()
        let service = ClickStickService(manager: manager)

        service.startScanning()
        service.didFail(with: .bluetoothUnavailable(reason: .permissionDenied), in: CSManager.shared)
        // Yield so the fire-and-forget Task { @MainActor } in didFail executes
        await Task.yield()

        #expect(!service.isScanning)
        if case .bluetoothUnavailable(let reason)? = service.bluetoothError {
            #expect(reason.description == CSError.BluetoothUnavailableReason.permissionDenied.description)
        } else {
            Issue.record("Expected bluetoothUnavailable(permissionDenied) error")
        }
    }

    @Test
    func isDemoModePropagatesToManager() {
        let manager = MockManager()
        let service = ClickStickService(manager: manager)

        service.isDemoMode = true
        #expect(manager.isDemoMode)

        service.isDemoMode = false
        #expect(!manager.isDemoMode)
    }
}
