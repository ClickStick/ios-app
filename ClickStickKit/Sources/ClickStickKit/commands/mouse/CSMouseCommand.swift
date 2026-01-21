//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import Foundation
import os.log

private let log = Logger(subsystem: "io.clickstick", category: #file)

public enum CSMouseButton: UInt8 {
    case left     = 0b00000001
    case right    = 0b00000010
    case middle   = 0b00000100
    case backward = 0b00001000
    case forward  = 0b00010000
}
typealias CSMouseButtons = Set<CSMouseButton>

public struct CSMouseEvent {
    let buttons: UInt8
    let dx: Int8
    let dy: Int8
    let scrollV: Int8
    let scrollH: Int8

    /// Structure size in bytes
    static let size = MemoryLayout<Self>.size

    /// Event data packed as byte array
    var bytes: [UInt8] {
        [
            buttons,
            UInt8(bitPattern: dx),
            UInt8(bitPattern: dy),
            UInt8(bitPattern: scrollV),
            UInt8(bitPattern: scrollH)
        ]
    }

    public init (buttons: UInt8, dx: Int8, dy: Int8, scrollV: Int8, scrollH: Int8) {
        self.buttons = buttons
        self.dx = dx
        self.dy = dy
        self.scrollV = scrollV
        self.scrollH = scrollH
    }

    /// Deserializes a MouseEvent from a byte array.
    init?(bytes: [UInt8]) {
        guard bytes.count == Self.size else { return nil }
        self.buttons = bytes[0]
        self.dx = Int8(bitPattern: bytes[1])
        self.dy = Int8(bitPattern: bytes[2])
        self.scrollV = Int8(bitPattern: bytes[3])
        self.scrollH = Int8(bitPattern: bytes[4])
    }
}

/// Emulates mouse moves, button presses and scroll events.
final class CSMouseCommand: CSCommand {
    override class var commandID: CommandID { 0x20 }

    /// Max expected time for handling one event
    private let timeoutPerEvent: TimeInterval = 0.01

    let events: [CSMouseEvent]

    /// Maximium number of mouse events accepted per command.
    static func getMaxEventCount(forCommandSize commandSize: Int) -> Int {
        let commandParamsSize = commandSize - 1 // -1 reserved for commandID
        return commandParamsSize / CSMouseEvent.size
    }

    /// `events` that don't fit into the limit will be silently truncated to that size.
    /// The limit is `getMaxEventCount(maxCommandSize)`.
    init(events: [CSMouseEvent], maxCommandSize: Int, completion: CSCommandCompletion?) {
        let maxEventCount = Self.getMaxEventCount(forCommandSize: maxCommandSize)
        assert(events.count <= maxEventCount, "Event array too long, truncating")
        self.events = Array(events.prefix(maxEventCount))

        var packet = Data(capacity: 1 + events.count * CSMouseEvent.size)
        packet.append(Self.commandID)
        for event in events {
            packet.append(contentsOf: event.bytes)
        }

        // Typing will take some extra time
        let typingTimeout = TimeInterval(events.count) * timeoutPerEvent
        super.init(
            name: "MOUSE",
            packet: packet,
            attributes: [],
            timeout: Self.baselineTimeout + typingTimeout,
            maxCommandSize: maxCommandSize,
            completion: completion
        )
    }

    /// Parses a plain-text command packet into a CSMouseCommandCommand instance.
    /// In case of error, returns `nil`.
    /// For mock/demo devices only.
    internal static func fromMockPacket(_ packet: Data) -> Self? {
        guard packet.count > 1 else {
            log.error("Packet too small")
            return nil
        }
        guard packet.first == Self.commandID else {
            assertionFailure("Wrong command ID")
            return nil
        }
        let events = stride(from: 1, to: packet.count - 1, by: CSMouseEvent.size).compactMap {
            CSMouseEvent(bytes: Array(packet[$0..<($0 + CSMouseEvent.size)]))
        }
        return Self(events: events, maxCommandSize: packet.count, completion: nil)
    }
}

extension CSDevice {
    /// Sends a command to press-and-release a mouse button.
    /// - Parameters:
    ///   - button: which button to click
    ///   - completion: called once the command completes
    public func sendMouseClick(button: CSMouseButton, completion: CSCommandCompletion?) {
        let event = CSMouseEvent(buttons: button.rawValue, dx: 0, dy: 0, scrollV: 0, scrollH: 0)
        let command = CSMouseCommand(
            events: [event],
            maxCommandSize: _maxCommandSize,
            completion: completion)
        _enqueueCommand(command)
    }

    public func sendMouseMove(dx: Int8, dy: Int8, completion: CSCommandCompletion?) {
        let event = CSMouseEvent(buttons: 0, dx: dx, dy: dy, scrollV: 0, scrollH: 0)
        let command = CSMouseCommand(
            events: [event],
            maxCommandSize: _maxCommandSize,
            completion: completion)
        _enqueueCommand(command)
    }

    public func sendMouseScroll(vertical: Int8, horizontal: Int8, completion: CSCommandCompletion?) {
        let event = CSMouseEvent(buttons: 0, dx: 0, dy: 0, scrollV: vertical, scrollH: horizontal)
        let command = CSMouseCommand(
            events: [event],
            maxCommandSize: _maxCommandSize,
            completion: completion)
        _enqueueCommand(command)
    }

    /// Send a sequence of mouse events to the dongle.
    /// Long sequences are automatically split into several packets.
    public func sendMouseEvents(_ events: [CSMouseEvent], completion: CSCommandCompletion?) {
        // If there are too many events, we split them into several command packets
        let chunkSize = CSMouseCommand.getMaxEventCount(forCommandSize: _maxCommandSize)
        for start in stride(from: 0, to: events.count, by: chunkSize) {
            let end = min(start + chunkSize, events.count)
            let command = CSMouseCommand(
                events: Array(events[start..<end]),
                maxCommandSize: _maxCommandSize,
                completion: completion)
            _enqueueCommand(command)
        }
    }
}
