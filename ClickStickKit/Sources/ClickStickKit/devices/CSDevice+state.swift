//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import Foundation
import os.log
import CryptoKit

private let log = Logger(subsystem: "io.clickstick", category: #file)

extension CSDevice {
    /// Reflects device's readiness for accepting new commands.
    public enum State: UInt8, CustomStringConvertible {
        /// Device needs to (re)establish the connection session.
        case initSession = 0x00
        /// Device is busy processing a command.
        case busy = 0x01
        /// Device is ready for new commands.
        case idle = 0x02

        public var description: String {
            switch self {
            case .initSession:
                return "initSession"
            case .busy:
                return "busy"
            case .idle:
                return "idle"
            }
        }
    }
}
