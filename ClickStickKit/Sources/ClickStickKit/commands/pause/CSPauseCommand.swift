//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import Foundation
import os.log

private let log = Logger(subsystem: "io.clickstick", category: #file)
final class CSPauseCommand: CSCommand {
    override class var commandID: CommandID { 0x02 }

    /// Maximum delay we want to allow
    static let maxAllowedDelay = TimeInterval(1.0)

    /// Maximum delay technically supported by this command.
    static let maxSupportedDelay = TimeInterval(UInt16.max) / 1000.0

    /// `delay` must be within `0...maxAllowedDelay`, otherwise will be silently capped to this range.
    init(delay: TimeInterval, maxCommandSize: Int, completion: CSCommandCompletion?) {
        let delayMillis = Self.sanitizeDelay(delay)
        let delayBytes = Data(from: delayMillis.bigEndian)

        // Generate random dummy payload for traffic obfuscation
        let maxPayloadSize = maxCommandSize
            - 1 // CommandID
            - MemoryLayout.size(ofValue: delayMillis) // delay
        let dummyPayloadSize = Int.random(in: 0..<maxPayloadSize)
        let dummyPayload = (0..<dummyPayloadSize).map { _ in UInt8.random(in: 0...0xFF) }

        var packet = Data(capacity: 1 + MemoryLayout.size(ofValue: delayMillis) + dummyPayloadSize)
        packet.append(Self.commandID)
        packet.append(contentsOf: delayBytes)
        packet.append(contentsOf: dummyPayload)

        super.init(
            name: "PAUSE",
            packet: packet,
            attributes: [],
            timeout: Self.baselineTimeout + delay,
            maxCommandSize: maxCommandSize,
            completion: completion
        )
    }

    private static func sanitizeDelay(_ delay: TimeInterval) -> UInt16 {
        var sanitizedDelay = delay
        if delay < 0 {
            log.warning("Delay must be non-negative, defaulting to 0")
            assertionFailure()
            sanitizedDelay = 0
        } else if delay > maxAllowedDelay {
            log.warning("Delay is too long, capping to \(self.maxAllowedDelay)")
            assertionFailure()
            sanitizedDelay = maxAllowedDelay
        }
        return UInt16(sanitizedDelay * 1000)
    }

    /// Parses a plain-text command packet into a CSPauseCommand instance.
    /// In case of error, returns `nil`.
    /// For mock/demo devices only.
    internal static func fromMockPacket(_ packet: Data) -> Self? {
        let expectedSize = 1 + MemoryLayout<UInt16>.size
        guard packet.count == expectedSize else {
            log.error("Unexpected packet size: \(packet.count) instead of \(expectedSize) bytes")
            return nil
        }
        guard packet.first == Self.commandID else {
            assertionFailure("Wrong command ID")
            return nil
        }
        let intDelay: UInt16 = UInt16(packet[1]) | (UInt16(packet[2]) << 8)
        return Self(delay: TimeInterval(intDelay) * 1000, maxCommandSize: expectedSize, completion: nil)
    }
}

extension CSDevice {
    /// Instructs the dongle to pause execution for a while.
    /// - Parameters:
    ///   - delay: how long to wait
    ///   - completion: called once the command completes
    public func sendPauseCommand(delay: TimeInterval, completion: CSCommandCompletion?) {
        let command = CSPauseCommand(
            delay: delay,
            maxCommandSize: _maxCommandSize,
            completion: completion)
        _enqueueCommand(command)
    }
}
