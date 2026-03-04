//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import Foundation
import os.log

private let log = Logger(subsystem: "io.clickstick", category: #file)

/// Keyboard layouts supported by the CSTypeCommand
public enum CSKeyboardLayout: CaseIterable, CustomStringConvertible {
    case usQWERTY          // ANSI
    case deQWERTZ          // DIN 2137 T1 (ISO)
    case frAZERTY_Classic  // Classic/legacy French AZERTY

    public var description: String {
        switch self {
        case .usQWERTY: "US - QWERTY"
        case .deQWERTZ: "DE - QWERTZ"
        case .frAZERTY_Classic: "FR - AZERTY (Classic)"
        }
    }

    /// Converts text to HID key codes for a given keyboard layout.
    /// By default, `includeUnknown` is true: unknown characters are replaced with question marks.
    /// If `includeUnknown` is false, unknown characters are skipped.
    func getKeyCodes(for text: String, includeUnknown: Bool = true) -> [KeyCode] {
        var out: [KeyCode] = []
        let mapper = LayoutMapper(layout: self)

        for scalar in text.unicodeScalars {
            if let ks = mapper.mapScalar(scalar) {
                out.append(ks)
            } else if includeUnknown, let questionMark = mapper.mapScalar("?") {
                log.debug("Unsupported character `\(String(format: "%04X", scalar.value))`, replaced")
                out.append(questionMark)
            }
            // else: skip
        }
        return out
    }
}

extension CSKeyboardLayout {
    /// Detects the appropriate keyboard layout from the system locale
    public static func fromSystemLocale() -> CSKeyboardLayout {
        guard let languageCode = Locale.current.language.languageCode?.identifier else {
            return .usQWERTY
        }
        switch languageCode {
        case "de": return .deQWERTZ
        case "fr": return .frAZERTY_Classic
        default:   return .usQWERTY
        }
    }
}

/// USB HID keyboard modifier bits (boot keyboard)
struct KeyModifiers: OptionSet {
    let rawValue: UInt8
    static let leftControl  = Self(rawValue: 0x01)
    static let leftShift    = Self(rawValue: 0x02)
    static let leftAlt      = Self(rawValue: 0x04)
    static let leftGUI      = Self(rawValue: 0x08)
    static let rightControl = Self(rawValue: 0x10)
    static let rightShift   = Self(rawValue: 0x20)
    static let rightAlt     = Self(rawValue: 0x40) // AltGr on many layouts
    static let rightGUI     = Self(rawValue: 0x80)

    static let altGr = rightAlt
}

struct KeyCode: CustomDebugStringConvertible {
    // Common HID codes needed across maps
    static let enter      = Self(0x28)
    static let tab        = Self(0x2B)
    static let space      = Self(0x2C)
    static let minus      = Self(0x2D)
    static let equal      = Self(0x2E)
    static let lbracket   = Self(0x2F)
    static let rbracket   = Self(0x30)
    static let backslash  = Self(0x31)
    static let semicolon  = Self(0x33)
    static let quote      = Self(0x34)
    static let grave      = Self(0x35)
    static let comma      = Self(0x36)
    static let period     = Self(0x37)
    static let slash      = Self(0x38)

    let modifiers: KeyModifiers

    // USB HID Keyboard/Keypad usage ID
    let code: UInt8

    /// Structure size in bytes
    static let size = MemoryLayout<KeyCode>.size

    /// Keycode data packed as byte array
    var bytes: [UInt8] { [modifiers.rawValue, code] }

    init(_ code: UInt8, modifiers: KeyModifiers = []) {
        self.modifiers = modifiers
        self.code = code
    }

    /// Deserializes a KeyCode from a byte array.
    init?(bytes: [UInt8]) {
        guard bytes.count == Self.size else { return nil }
        self.modifiers = KeyModifiers(rawValue: bytes[0])
        self.code = bytes[1]
    }

    func withModifiers(_ modifiers: KeyModifiers) -> Self {
        return .init(code, modifiers: modifiers)
    }

    var debugDescription: String {
        return "Mods: 0x\(String(format: "%02X", modifiers.rawValue)), Code: 0x\(String(format: "%02X", code))"
    }
}

// MARK: - Internal Mapper

private struct LayoutMapper {
    let layout: CSKeyboardLayout

    // Helpers
    private func key(_ code: UInt8, _ mods: KeyModifiers = []) -> KeyCode {
        KeyCode(code, modifiers: mods)
    }

    func mapScalar(_ scalar: Unicode.Scalar) -> KeyCode? {
        let ch = Character(scalar)

        // Whitespace / controls (layout-agnostic)
        switch ch {
        case "\n", "\r":
            return KeyCode.enter
        case "\t":
            return KeyCode.tab
        case " ":
            return KeyCode.space
        default:
            break
        }

        // Letters (layout-specific swaps handled in mapLetter)
        if let ascii = ch.asciiValue {
            if ascii >= 0x61 && ascii <= 0x7A { // 'a'...'z'
                return mapLetter(lower: ch)
            }
            if ascii >= 0x41 && ascii <= 0x5A { // 'A'...'Z'
                if let base = mapLetter(lower: Character(ch.lowercased())) {
                    return base.withModifiers(.leftShift)
                }
            }
        }

        // Symbols/national characters per layout
        return symbolMap[ch]
    }

    // MARK: Letters by layout
    private func mapLetter(lower ch: Character) -> KeyCode? {
        switch layout {
        case .usQWERTY:
            guard let usage = usLetterUsage[ch] else { return nil }
            return key(usage)
        case .deQWERTZ:
            // Y/Z swap
            if ch == "y" { return KeyCode(0x1D) } // US 'Z' position
            if ch == "z" { return KeyCode(0x1C) } // US 'Y' position
            guard let usage = usLetterUsage[ch] else { return nil }
            return key(usage)
        case .frAZERTY_Classic:
            // A<->Q, Z<->W swap
            if ch == "a" { return KeyCode(0x14) } // US 'Q'
            if ch == "q" { return KeyCode(0x04) } // US 'A'
            if ch == "z" { return KeyCode(0x1A) } // US 'W'
            if ch == "w" { return KeyCode(0x1D) } // US 'Z'
            guard let usage = usLetterUsage[ch] else { return nil }
            return key(usage)
        }
    }

    private var usLetterUsage: [Character: UInt8] {[
        "a": 0x04, "b": 0x05, "c": 0x06, "d": 0x07, "e": 0x08, "f": 0x09,
        "g": 0x0A, "h": 0x0B, "i": 0x0C, "j": 0x0D, "k": 0x0E, "l": 0x0F,
        "m": 0x10, "n": 0x11, "o": 0x12, "p": 0x13, "q": 0x14, "r": 0x15,
        "s": 0x16, "t": 0x17, "u": 0x18, "v": 0x19, "w": 0x1A, "x": 0x1B,
        "y": 0x1C, "z": 0x1D
    ]}

    // MARK: Per-layout symbol maps
    private var symbolMap: [Character: KeyCode] {
        switch layout {
        case .usQWERTY:
            return mapUS()
        case .deQWERTZ:
            return mapDE_T1()
        case .frAZERTY_Classic:
            return mapFR_Classic()
        }
    }

    // --- US (baseline reference) ---
    private func mapUS() -> [Character: KeyCode] {
        var m: [Character: KeyCode] = [:]

        // Number row
        m["1"] = KeyCode(0x1E);  m["!"] = KeyCode(0x1E, modifiers: .leftShift)
        m["2"] = KeyCode(0x1F);  m["@"] = KeyCode(0x1F, modifiers: .leftShift)
        m["3"] = KeyCode(0x20);  m["#"] = KeyCode(0x20, modifiers: .leftShift)
        m["4"] = KeyCode(0x21);  m["$"] = KeyCode(0x21, modifiers: .leftShift)
        m["5"] = KeyCode(0x22);  m["%"] = KeyCode(0x22, modifiers: .leftShift)
        m["6"] = KeyCode(0x23);  m["^"] = KeyCode(0x23, modifiers: .leftShift)
        m["7"] = KeyCode(0x24);  m["&"] = KeyCode(0x24, modifiers: .leftShift)
        m["8"] = KeyCode(0x25);  m["*"] = KeyCode(0x25, modifiers: .leftShift)
        m["9"] = KeyCode(0x26);  m["("] = KeyCode(0x26, modifiers: .leftShift)
        m["0"] = KeyCode(0x27);  m[")"] = KeyCode(0x27, modifiers: .leftShift)

        // Punctuation
        m["-"]  = KeyCode.minus
        m["_"]  = KeyCode.minus.withModifiers(.leftShift)

        m["="]  = KeyCode.equal
        m["+"]  = KeyCode.equal.withModifiers(.leftShift)

        m["["]  = KeyCode.lbracket
        m["{"]  = KeyCode.lbracket.withModifiers(.leftShift)

        m["]"]  = KeyCode.rbracket
        m["}"]  = KeyCode.rbracket.withModifiers(.leftShift)

        m["\\"] = KeyCode.backslash
        m["|"]  = KeyCode.backslash.withModifiers(.leftShift)

        m[";"]  = KeyCode.semicolon
        m[":"]  = KeyCode.semicolon.withModifiers(.leftShift)

        m["'"]  = KeyCode.quote
        m["\""] = KeyCode.quote.withModifiers(.leftShift)

        m["`"]  = KeyCode.grave
        m["~"]  = KeyCode.grave.withModifiers(.leftShift)

        m[","]  = KeyCode.comma
        m["<"]  = KeyCode.comma.withModifiers(.leftShift)

        m["."]  = KeyCode.period
        m[">"]  = KeyCode.period.withModifiers(.leftShift)

        m["/"]  = KeyCode.slash
        m["?"]  = KeyCode.slash.withModifiers(.leftShift)

        return m
    }

    // --- German QWERTZ (DIN 2137 T1, ISO) ---
    // Digits unshifted; shifted symbols as below. Brackets/backslash via AltGr.
    private func mapDE_T1() -> [Character: KeyCode] {
        var m: [Character: KeyCode] = [:]

        // Number row (unshifted digits, common shifted set)
        m["1"] = KeyCode(0x1E);  m["!"] = KeyCode(0x1E, modifiers: .leftShift)
        m["2"] = KeyCode(0x1F);  m["\""] = KeyCode(0x1F, modifiers: .leftShift)
        m["3"] = KeyCode(0x20);  m["§"] = KeyCode(0x20, modifiers: .leftShift)   // non-ASCII
        m["4"] = KeyCode(0x21);  m["$"] = KeyCode(0x21, modifiers: .leftShift)
        m["5"] = KeyCode(0x22);  m["%"] = KeyCode(0x22, modifiers: .leftShift)
        m["6"] = KeyCode(0x23);  m["&"] = KeyCode(0x23, modifiers: .leftShift)
        m["7"] = KeyCode(0x24);  m["/"] = KeyCode(0x24, modifiers: .leftShift)
        m["8"] = KeyCode(0x25);  m["("] = KeyCode(0x25, modifiers: .leftShift)
        m["9"] = KeyCode(0x26);  m[")"] = KeyCode(0x26, modifiers: .leftShift)
        m["0"] = KeyCode(0x27);  m["="] = KeyCode(0x27, modifiers: .leftShift)

        // National letters (single key on DE T1)
        m["ä"] = KeyCode.quote // often on US ';' key position
        m["Ä"] = KeyCode.quote.withModifiers(.leftShift)
        m["ö"] = KeyCode.semicolon // often on US ''' key position
        m["Ö"] = KeyCode.semicolon.withModifiers(.leftShift)
        m["ü"] = KeyCode.lbracket
        m["Ü"] = KeyCode.lbracket.withModifiers(.leftShift)
        m["ß"] = KeyCode.minus // right of 0
        m["?"] = KeyCode.minus.withModifiers(.leftShift) // Shift+ß

        // Comma/period keys behave like US for < >
        m[","] = KeyCode.comma
        m["<"] = KeyCode.comma.withModifiers(.leftShift)
        m["."] = KeyCode.period
        m[">"] = KeyCode.period.withModifiers(.leftShift)

        // Brackets / braces / backslash via AltGr combos on DE:
        m["{"] = KeyCode(0x24, modifiers: .altGr)   // AltGr+7
        m["["] = KeyCode(0x25, modifiers: .altGr)   // AltGr+8
        m["]"] = KeyCode(0x26, modifiers: .altGr)   // AltGr+9
        m["}"] = KeyCode(0x27, modifiers: .altGr)   // AltGr+0
        m["\\"] = KeyCode.minus.withModifiers(.altGr) // AltGr+ß

        // Caret/grave (dead on real layout, but we send single press)
        m["^"] = KeyCode.grave.withModifiers(.leftShift)
        m["`"] = KeyCode.grave

        return m
    }

    // --- French AZERTY (Classic) ---
    // Digits require Shift; unshifted number row yields national/symbol chars.
    // Brackets/backslash via AltGr combos.
    private func mapFR_Classic() -> [Character: KeyCode] {
        var m: [Character: KeyCode] = [:]

        // Number row (unshifted symbols / shifted digits)
        m["&"] = KeyCode(0x1E);  m["1"] = KeyCode(0x1E, modifiers: .leftShift)
        m["é"] = KeyCode(0x1F);  m["2"] = KeyCode(0x1F, modifiers: .leftShift)
        m["\""] = KeyCode(0x20); m["3"] = KeyCode(0x20, modifiers: .leftShift)
        m["'"] = KeyCode(0x21);  m["4"] = KeyCode(0x21, modifiers: .leftShift)
        m["("] = KeyCode(0x22);  m["5"] = KeyCode(0x22, modifiers: .leftShift)
        m["-"] = KeyCode(0x23);  m["6"] = KeyCode(0x23, modifiers: .leftShift)
        m["è"] = KeyCode(0x24);  m["7"] = KeyCode(0x24, modifiers: .leftShift)
        m["_"] = KeyCode(0x25);  m["8"] = KeyCode(0x25, modifiers: .leftShift)
        m["ç"] = KeyCode(0x26);  m["9"] = KeyCode(0x26, modifiers: .leftShift)
        m["à"] = KeyCode(0x27);  m["0"] = KeyCode(0x27, modifiers: .leftShift)

        // Common punctuation (varies by vendor; these are safe defaults)
        m[","] = KeyCode.comma
        m[";"] = KeyCode.semicolon
        m[":"] = KeyCode.semicolon.withModifiers(.leftShift)
        m["."] = KeyCode.period
        // On classic FR, '/' and '?' often require Shift on the slash key; map both to Shifted slash:
        m["/"] = KeyCode.slash.withModifiers(.leftShift)
        m["?"] = KeyCode.slash.withModifiers(.leftShift)

        // Brackets / braces / backslash via AltGr on FR legacy:
        m["{"] = KeyCode(0x22, modifiers: .altGr)  // AltGr+5 (common)
        m["}"] = KeyCode(0x27, modifiers: .altGr)  // AltGr+0 (common)
        m["["] = KeyCode(0x25, modifiers: .altGr)  // AltGr+8
        m["]"] = KeyCode(0x26, modifiers: .altGr)  // AltGr+9
        m["\\"] = KeyCode.backslash.withModifiers(.altGr) // AltGr on the backslash area

        // Caret/grave (often dead keys physically; we emit single press)
        m["^"] = KeyCode.grave.withModifiers(.leftShift)
        m["`"] = KeyCode.grave
        return m
    }
}
