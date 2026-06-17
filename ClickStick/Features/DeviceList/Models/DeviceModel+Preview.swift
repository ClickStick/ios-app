//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Foundation

#if DEBUG
extension DeviceModel {
    /// Creates a preview-only DeviceModel with mock data.
    /// This uses the demo mode of ClickStickService to get real mock devices.
    private static func createPreviewService() -> ClickStickService {
        let service = ClickStickService()
        service.isDemoMode = true
        return service
    }

    private static func wait(_ seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        RunLoop.main.run(until: deadline)
    }

    /// A preview device from demo mode (connected)
    static var preview: DeviceModel {
        let service = createPreviewService()
        guard let device = service.devices.first else {
            fatalError("Demo mode should provide mock devices")
        }
        device.connect()
        wait(2.0)
        return device
    }

    /// A preview device that appears disconnected
    static var previewDisconnected: DeviceModel {
        let service = createPreviewService()
        if let device = service.devices.last ?? service.devices.first {
            device.disconnect()
            wait(0.2)
            return device
        }
        fatalError("Demo mode should provide mock devices")
    }

    /// A preview device flagged as compromised (failed session validation).
    static var previewCompromised: DeviceModel {
        let device = previewDisconnected
        device.deviceDidDetectTampering(device.device)
        return device
    }

    /// Deterministic preview device fixed in a given display state.
    static func preview(_ name: String, _ state: CSDevice.PreviewState) -> DeviceModel {
        DeviceModel(device: .makePreview(name: name, state: state))
    }

    /// A connectable device with a faint signal ("Weak signal").
    static var previewWeakSignal: DeviceModel {
        preview("ClickStick A2A1", .weakSignal)
    }
}
#endif
