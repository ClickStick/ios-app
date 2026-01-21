//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import Foundation
import os.log

private let log = Logger(subsystem: "io.clickstick", category: #file)

final class CSCancelCommand: CSCommand {
    override class var commandID: CommandID { 0x01 }

    init(maxCommandSize: Int, completion: CSCommandCompletion?) {
        super.init(
            name: "CANCEL",
            packet: Data([Self.commandID]),
            attributes: [.highPriority, .resetsSequenceCounter],
            maxCommandSize: maxCommandSize,
            completion: completion
        )
    }

    /// Parses a plain-text command packet into a CSCancelCommand instance.
    /// In case of error, returns `nil`.
    /// For mock/demo devices only.
    internal static func fromMockPacket(_ packet: Data) -> Self? {
        let expectedSize = 1
        guard packet.count == expectedSize else {
            log.error("Unexpected packet size: \(packet.count) instead of \(expectedSize) byte")
            return nil
        }
        guard packet.first == Self.commandID else {
            assertionFailure("Wrong command ID")
            return nil
        }
        return Self(maxCommandSize: 1, completion: nil)
    }
}

extension CSDevice {
    /// Instructs the dongle to stop processing the current command, clear the command queue,
    /// and return to the `IDLE` state as soon as possible.
    /// This command is ignored in `INIT_SESSION` state.
    public func sendCancelCommand(completion: CSCommandCompletion?) {
//        guard _deviceState != .initSession else {
//            log.warning("Cannot cancel when device is in .initSession state, ignoring")
//            return
//        }
        let command = CSCancelCommand(maxCommandSize: _maxCommandSize, completion: completion)
        _enqueueCommand(command)
    }
}
