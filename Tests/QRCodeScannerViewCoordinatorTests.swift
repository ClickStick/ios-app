import Testing
@testable import ClickStick

@MainActor
struct QRCodeScannerViewCoordinatorTests {

    enum TestError: Error {
        case startFailed
    }

    @Test
    func startRunsOnlyOnceWhileRunning() throws {
        let coordinator = QRCodeScannerView.Coordinator(onScan: { _ in })
        var startCallCount = 0

        try coordinator.startScannerIfNeeded {
            startCallCount += 1
        }
        try coordinator.startScannerIfNeeded {
            startCallCount += 1
        }

        #expect(startCallCount == 1)
        #expect(coordinator.isScannerRunning)
    }

    @Test
    func stopRunsOnlyWhenRunning() throws {
        let coordinator = QRCodeScannerView.Coordinator(onScan: { _ in })
        var stopCallCount = 0

        coordinator.stopScannerIfRunning {
            stopCallCount += 1
        }
        try coordinator.startScannerIfNeeded {}
        coordinator.stopScannerIfRunning {
            stopCallCount += 1
        }
        coordinator.stopScannerIfRunning {
            stopCallCount += 1
        }

        #expect(stopCallCount == 1)
        #expect(!coordinator.isScannerRunning)
    }

    @Test
    func failedStartDoesNotMarkScannerAsRunning() {
        let coordinator = QRCodeScannerView.Coordinator(onScan: { _ in })

        #expect(throws: TestError.startFailed) {
            try coordinator.startScannerIfNeeded {
                throw TestError.startFailed
            }
        }
        #expect(!coordinator.isScannerRunning)
    }
}
