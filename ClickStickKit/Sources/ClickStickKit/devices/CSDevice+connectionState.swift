//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import Foundation

extension CSDevice {
    @frozen
    public enum ConnectionState: CustomStringConvertible {
        case disconnected
        case serviceDiscovery
        case connectedUnauthorized
        case connectedAuthorized

        public var description: String {
            switch self {
            case .disconnected:
                return "Disconnected"
            case .serviceDiscovery:
                return "Preparing"
            case .connectedUnauthorized:
                return "Unauthorized"
            case .connectedAuthorized:
                return "Connected"
            }
        }
    }
}
