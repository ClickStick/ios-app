//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import Foundation

public protocol CSDeviceObserver: AnyObject {
    func deviceDidUpdateProperties(_ device: CSDevice)
    func deviceConnectionStateUpdated(_ device: CSDevice)
    func deviceNeedsAuthentication(_ device: CSDevice)
    /// Called when a known device's session data fails to validate (bad signature/MAC),
    /// i.e. `CSDeviceSession.parse()` returned nil — the device may have been tampered with.
    func deviceDidDetectTampering(_ device: CSDevice)
    func deviceDidFail(_ device: CSDevice, with error: CSError)
    func deviceDidDisconnect(_ device: CSDevice, with error: CSError?)
}

// Empty stubs to reduce observers' boilerplate
public extension CSDeviceObserver {
    func deviceDidUpdateProperties(_ device: CSDevice) {}
    func deviceConnectionStateUpdated(_ device: CSDevice) {}
    func deviceNeedsAuthentication(_ device: CSDevice) {}
    func deviceDidDetectTampering(_ device: CSDevice) {}
    func deviceDidFail(_ device: CSDevice, with error: CSError) {}
    func deviceDidDisconnect(_ device: CSDevice, with error: CSError?) {}
}

extension CSDevice {
    public func addObserver(_ observer: CSDeviceObserver) {
        _observers.add(observer)
    }

    public func removeObserver(_ observer: CSDeviceObserver) {
        _observers.remove(observer)
    }

    internal func _notifyObservers(_ block: @escaping (CSDeviceObserver) -> Void) {
        let notificationQueue = DispatchQueue.main
        for object in _observers.allObjects {
            if let observer = object as? CSDeviceObserver {
                notificationQueue.async {
                    block(observer)
                }
            }
        }
    }
}
