//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit

protocol CSManaging: AnyObject {
    var isDemoMode: Bool { get set }
    var delegate: CSManagerDelegate? { get set }

    func startScanning()
    func stopScanning()
    func knownDevices() -> [CSDevice]
}

extension CSManager: CSManaging {}
