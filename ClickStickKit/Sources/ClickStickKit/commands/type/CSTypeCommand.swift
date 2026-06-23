//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import Foundation
import os.log

private let log = Logger(subsystem: "io.clickstick", category: #file)

/// Emulates pressing and releasing specific keys with a fixed delay.
/// For each scancode, the dongle produces three actions: a "key press" HID frame,
/// a "key release" frame, and a fixed delay defined by dongle's rate limit.
final class CSTypeCommand: CSCommand {
    override class var commandID: CommandID { 0x10 }

    /// Max expected time for typing out a single key code.
    private let timeoutPerKeyCode: TimeInterval = 0.05

    let keyCodes: [KeyCode]

    /// Maximum number of key codes accepted per command.
    static func getMaxKeyCodeCount(forCommandSize commandSize: Int) -> Int {
        let commandParamsSize = commandSize - 1 // -1 reserved for commandID
        return commandParamsSize / KeyCode.size
    }

    /// `keyCodes` that don't fit into the limit will be silently truncated to that size.
    /// The limit is `getMaxKeyCodeCount(maxCommandSize)`.
    init(keyCodes: [KeyCode], maxCommandSize: Int, completion: CSCommandCompletion?) {
        let maxKeyCodes = Self.getMaxKeyCodeCount(forCommandSize: maxCommandSize)
        assert(keyCodes.count <= maxKeyCodes, "Keycode array too long, truncating")
        self.keyCodes = Array(keyCodes.prefix(maxKeyCodes))

        var packet = Data(capacity: 1 + keyCodes.count * KeyCode.size)
        packet.append(Self.commandID)
        for keyCode in keyCodes {
            packet.append(contentsOf: keyCode.bytes)
        }

        // Typing will take some extra time
        let typingTimeout = TimeInterval(keyCodes.count) * timeoutPerKeyCode
        super.init(
            name: "TYPE",
            packet: packet,
            attributes: [],
            timeout: Self.baselineTimeout + typingTimeout,
            maxCommandSize: maxCommandSize,
            completion: completion
        )
    }

    /// Parses a plain-text command packet into a CSTypeCommandCommand instance.
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
        let keyCodes = stride(from: 1, to: packet.count - 1, by: KeyCode.size).compactMap {
            KeyCode(bytes: Array(packet[$0..<($0 + KeyCode.size)]))
        }
        return Self(keyCodes: keyCodes, maxCommandSize: packet.count, completion: nil)
    }
}

extension CSDevice {
    /// Converts given `text` to key codes corresponding to given keyboard layout,
    /// and sends them to the dongle for typing.
    /// - Parameters:
    ///   - text: text to type
    ///   - layout: host's keyboard layout
    ///   - targetOS: host's target operating system. Not used by mappings yet.
    ///   - completion: called once the command completes
    public func sendTypeCommands(
        text: String,
        layout: CSKeyboardLayout,
        targetOS: CSTypingOS,
        completion: CSCommandCompletion?
    ) {
        let keyCodes = layout.getKeyCodes(for: text, includeUnknown: false)
        guard !keyCodes.isEmpty else {
            completion?(.success(()))
            return
        }

        // If text is too long, we split it into several typing commands.
        // Only the last chunk carries the completion so it is called exactly once.
        let chunkSize = CSTypeCommand.getMaxKeyCodeCount(forCommandSize: _maxCommandSize)
        let starts = Array(stride(from: 0, to: keyCodes.count, by: chunkSize))
        for (index, start) in starts.enumerated() {
            let end = min(start + chunkSize, keyCodes.count)
            let command = CSTypeCommand(
                keyCodes: Array(keyCodes[start..<end]),
                maxCommandSize: _maxCommandSize,
                completion: index == starts.count - 1 ? completion : nil
            )
            _enqueueCommand(command)
        }
    }
}
