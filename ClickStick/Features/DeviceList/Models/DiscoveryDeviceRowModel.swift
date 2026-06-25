//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import Foundation

struct DiscoveryDeviceRowModel: Identifiable {
    let id: UUID
    let name: String
    let rssi: Int
    let device: DeviceModel?

    init(device: DeviceModel) {
        self.id = device.id
        self.name = device.displayName
        self.rssi = device.rssi
        self.device = device
    }

    init(id: UUID = UUID(), name: String, rssi: Int) {
        self.id = id
        self.name = name
        self.rssi = rssi
        self.device = nil
    }

    #if DEBUG
    static let preview: [Self] = [
        .init(name: "ClickStick 9F8C", rssi: -42),
        .init(name: "ClickStick 8F8C", rssi: -71),
        .init(name: "ClickStick A1B2", rssi: -88)
    ]
    #endif
}
