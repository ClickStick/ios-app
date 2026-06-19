import Testing
@testable import ClickStick
import ClickStickKit
import Foundation

@MainActor
struct MouseViewModelTests {

    private final class MockMouseDevice: MouseControllingDevice {
        var isConnected = true
        private(set) var moveCallCount = 0
        private(set) var scrollCallCount = 0
        private(set) var lastClickButton: CSMouseButton?
        private(set) var clickCallCount = 0

        func sendMouseMove(dx: Int8, dy: Int8, completion: CSCommandCompletion?) {
            moveCallCount += 1
        }

        func sendMouseClick(button: CSMouseButton, completion: CSCommandCompletion?) {
            lastClickButton = button
            clickCallCount += 1
        }

        func sendMouseScroll(vertical: Int8, horizontal: Int8, completion: CSCommandCompletion?) {
            scrollCallCount += 1
        }
    }

    @Test
    func handleMoveDispatchesCommand() {
        let device = MockMouseDevice()
        let viewModel = MouseViewModel(device: device)

        viewModel.handleMove(dx: 5, dy: 3)

        #expect(device.moveCallCount == 1)
    }

    @Test
    func handleScrollDispatchesCommand() {
        let device = MockMouseDevice()
        let viewModel = MouseViewModel(device: device)

        viewModel.handleScroll(vertical: 2, horizontal: 0)

        #expect(device.scrollCallCount == 1)
    }

    @Test
    func handleLeftClickDispatchesLeftButton() {
        let device = MockMouseDevice()
        let viewModel = MouseViewModel(device: device)

        viewModel.handleLeftClick()

        #expect(device.clickCallCount == 1)
        #expect(device.lastClickButton == .left)
    }

    @Test
    func handleRightClickDispatchesRightButton() {
        let device = MockMouseDevice()
        let viewModel = MouseViewModel(device: device)

        viewModel.handleRightClick()

        #expect(device.clickCallCount == 1)
        #expect(device.lastClickButton == .right)
    }

    @Test
    func handleTapDispatchesLeftClick() {
        let device = MockMouseDevice()
        let viewModel = MouseViewModel(device: device)

        viewModel.handleTap()

        #expect(device.clickCallCount == 1)
        #expect(device.lastClickButton == .left)
    }

    @Test
    func disconnectedDeviceSkipsMove() {
        let device = MockMouseDevice()
        device.isConnected = false
        let viewModel = MouseViewModel(device: device)

        viewModel.handleMove(dx: 5, dy: 3)

        #expect(device.moveCallCount == 0)
    }

    @Test
    func disconnectedDeviceSkipsClick() {
        let device = MockMouseDevice()
        device.isConnected = false
        let viewModel = MouseViewModel(device: device)

        viewModel.handleLeftClick()

        #expect(device.clickCallCount == 0)
    }

    @Test
    func disconnectedDeviceSkipsScroll() {
        let device = MockMouseDevice()
        device.isConnected = false
        let viewModel = MouseViewModel(device: device)

        viewModel.handleScroll(vertical: 1, horizontal: 0)

        #expect(device.scrollCallCount == 0)
    }
}
