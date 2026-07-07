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
        let maxPayloadSize = max(
            0,
            maxCommandSize
                - 1 // CommandID
                - MemoryLayout.size(ofValue: delayMillis) // delay
        )
        let dummyPayloadSize = maxPayloadSize > 0 ? Int.random(in: 0..<maxPayloadSize) : 0
        let dummyPayload = (0..<dummyPayloadSize).map { _ in UInt8.random(in: 0...0xFF) }

        var packet = Data(capacity: 1 + MemoryLayout.size(ofValue: delayMillis) + dummyPayloadSize)
        packet.append(Self.commandID)
        packet.append(contentsOf: delayBytes)
        packet.append(contentsOf: dummyPayload)

        super.init(
            name: "PAUSE",
            packet: packet,
            attributes: [],
            timeout: Self.baselineTimeout + TimeInterval(delayMillis) / 1000,
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
        // Command ID + 2 delay bytes. The real packet also carries a variable-length random
        // obfuscation payload after the delay, so accept anything at least this long.
        let headerSize = 1 + MemoryLayout<UInt16>.size
        guard packet.count >= headerSize else {
            log.error("Unexpected packet size: \(packet.count), expected at least \(headerSize) bytes")
            return nil
        }
        // Normalize to a 0-based array in case `packet` is a slice with non-zero start index.
        let bytes = Array(packet)
        guard bytes.first == Self.commandID else {
            assertionFailure("Wrong command ID")
            return nil
        }
        // Delay is stored big-endian in milliseconds (see `init`); trailing padding is ignored.
        let delayMillis = (UInt16(bytes[1]) << 8) | UInt16(bytes[2])
        return Self(delay: TimeInterval(delayMillis) / 1000, maxCommandSize: packet.count, completion: nil)
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
