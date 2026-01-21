//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import CoreBluetooth

internal enum CSUUID {
    static let deviceInformationService = CBUUID(string: "180A")
    static let serialNumberCharacteristic = CBUUID(string: "2A25")
    static let firmwareRevisionCharacteristic = CBUUID(string: "2A26")

    static let clickStickService = CBUUID(string: "BC820DCF-3C7D-4D89-A332-E4B246D69B6B")
    static let commandCharacteristic = CBUUID(string: "96AA4230-546C-4367-A6EC-412C9A80FE24")
    static let statusCharacteristic = CBUUID(string: "C8675C75-9916-41B0-B8C5-B2B950613355")
}
