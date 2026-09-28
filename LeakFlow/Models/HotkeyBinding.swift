import Foundation
import Carbon
import AppKit

/// Represents a keyboard hotkey binding
struct HotkeyBinding: Codable, Equatable {
    /// The virtual key code
    let keyCode: UInt16

    /// The modifier flags (shift, control, option, command)
    let modifierFlags: UInt

    /// Whether this is a modifier-only hotkey (like just Option key)
    let isModifierOnly: Bool

    /// Default hotkey: Right Option key
    static let defaultBinding = HotkeyBinding(
        keyCode: 61, // kVK_RightOption
        modifierFlags: NSEvent.ModifierFlags.option.rawValue,
        isModifierOnly: true
    )

    /// Human-readable description of this hotkey
    var displayString: String {
        if isModifierOnly {
            return modifierDisplayString
        }

        var parts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: modifierFlags)

        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }

        parts.append(keyCodeToString(keyCode))

        return parts.joined()
    }

    private var modifierDisplayString: String {
        switch keyCode {
        case 61: return "Right ⌥"
        case 58: return "Left ⌥"
        case 62: return "Right ⌃"
        case 59: return "Left ⌃"
        case 60: return "Right ⇧"
        case 56: return "Left ⇧"
        case 55: return "Left ⌘"
        case 54: return "Right ⌘"
        default: return "Key \(keyCode)"
        }
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 31: return "O"
        case 32: return "U"
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 40: return "K"
        case 45: return "N"
        case 46: return "M"
        case 49: return "Space"
        case 36: return "Return"
        case 48: return "Tab"
        case 51: return "Delete"
        case 53: return "Escape"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default: return "Key(\(keyCode))"
        }
    }
}
