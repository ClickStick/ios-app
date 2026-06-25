//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Observation
import UIKit

@Observable
@MainActor
final class MouseViewModel {
    private let device: any MouseControllingDevice

    init(device: any MouseControllingDevice) {
        self.device = device
    }

    func handleMove(dx: Int8, dy: Int8) {
        guard device.isConnected else { return }
        device.sendMouseMove(dx: dx, dy: dy, completion: nil)
    }

    func handleScroll(vertical: Int8, horizontal: Int8) {
        guard device.isConnected else { return }
        device.sendMouseScroll(vertical: vertical, horizontal: horizontal, completion: nil)
    }

    func handleTap() {
        handleLeftClick()
    }

    func handleLeftClick() {
        guard device.isConnected else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        device.sendMouseClick(button: .left, completion: nil)
    }

    func handleRightClick() {
        guard device.isConnected else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        device.sendMouseClick(button: .right, completion: nil)
    }
}
