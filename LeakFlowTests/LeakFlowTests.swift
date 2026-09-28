import XCTest
@testable import LeakFlow

final class HotkeyBindingTests: XCTestCase {

    // MARK: - Existing Tests

    func testDefaultBinding() {
        let binding = HotkeyBinding.defaultBinding
        XCTAssertEqual(binding.keyCode, 61)
        XCTAssertTrue(binding.isModifierOnly)
        XCTAssertEqual(binding.displayString, "Right ⌥")
    }

    func testEquality() {
        let a = HotkeyBinding(keyCode: 61, modifierFlags: 0, isModifierOnly: true)
        let b = HotkeyBinding(keyCode: 61, modifierFlags: 0, isModifierOnly: true)
        XCTAssertEqual(a, b)
    }

    func testCodable() throws {
        let original = HotkeyBinding.defaultBinding
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HotkeyBinding.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testDisplayStringWithModifiers() {
        let binding = HotkeyBinding(
            keyCode: 0, // A key
            modifierFlags: NSEvent.ModifierFlags.command.rawValue,
            isModifierOnly: false
        )
        XCTAssertEqual(binding.displayString, "⌘A")
    }

    func testModifierOnlyDisplayStrings() {
        let cases: [(UInt16, String)] = [
            (61, "Right ⌥"),
            (58, "Left ⌥"),
            (62, "Right ⌃"),
            (59, "Left ⌃"),
            (60, "Right ⇧"),
            (56, "Left ⇧"),
            (55, "Left ⌘"),
            (54, "Right ⌘"),
        ]
        for (keyCode, expected) in cases {
            let binding = HotkeyBinding(keyCode: keyCode, modifierFlags: 0, isModifierOnly: true)
            XCTAssertEqual(binding.displayString, expected, "Failed for keyCode \(keyCode)")
        }
    }

    // MARK: - New Key Code Tests

    func testKeyCodeToString_letterKeys() {
        let letterCases: [(UInt16, String)] = [
            (0, "A"), (1, "S"), (2, "D"), (3, "F"), (4, "H"),
            (5, "G"), (6, "Z"), (7, "X"), (8, "C"), (9, "V"),
            (11, "B"), (12, "Q"), (13, "W"), (14, "E"), (15, "R"),
            (16, "Y"), (17, "T"), (31, "O"), (32, "U"), (34, "I"),
            (35, "P"), (37, "L"), (38, "J"), (40, "K"), (45, "N"),
            (46, "M"),
        ]
        for (keyCode, expected) in letterCases {
            let binding = HotkeyBinding(keyCode: keyCode, modifierFlags: 0, isModifierOnly: false)
            XCTAssertEqual(binding.displayString, expected, "Failed for keyCode \(keyCode)")
        }
    }

    func testKeyCodeToString_functionKeys() {
        let functionCases: [(UInt16, String)] = [
            (122, "F1"), (120, "F2"), (99, "F3"), (118, "F4"),
            (96, "F5"), (97, "F6"), (98, "F7"), (100, "F8"),
            (101, "F9"), (109, "F10"), (103, "F11"), (111, "F12"),
        ]
        for (keyCode, expected) in functionCases {
            let binding = HotkeyBinding(keyCode: keyCode, modifierFlags: 0, isModifierOnly: false)
            XCTAssertEqual(binding.displayString, expected, "Failed for keyCode \(keyCode)")
        }
    }

    func testKeyCodeToString_specialKeys() {
        let specialCases: [(UInt16, String)] = [
            (49, "Space"), (36, "Return"), (48, "Tab"),
            (51, "Delete"), (53, "Escape"),
        ]
        for (keyCode, expected) in specialCases {
            let binding = HotkeyBinding(keyCode: keyCode, modifierFlags: 0, isModifierOnly: false)
            XCTAssertEqual(binding.displayString, expected, "Failed for keyCode \(keyCode)")
        }
    }

    func testKeyCodeToString_unknownKeyCode() {
        let binding = HotkeyBinding(keyCode: 200, modifierFlags: 0, isModifierOnly: false)
        XCTAssertEqual(binding.displayString, "Key(200)")
    }

    func testDisplayString_multipleModifiers() {
        let flags = NSEvent.ModifierFlags.control.rawValue
            | NSEvent.ModifierFlags.option.rawValue
            | NSEvent.ModifierFlags.shift.rawValue
            | NSEvent.ModifierFlags.command.rawValue
        let binding = HotkeyBinding(keyCode: 0, modifierFlags: flags, isModifierOnly: false)
        XCTAssertEqual(binding.displayString, "⌃⌥⇧⌘A")
    }

    func testDisplayString_noModifiers() {
        let binding = HotkeyBinding(keyCode: 0, modifierFlags: 0, isModifierOnly: false)
        XCTAssertEqual(binding.displayString, "A")
    }

    func testModifierOnlyDisplayString_unknownKeyCode() {
        let binding = HotkeyBinding(keyCode: 99, modifierFlags: 0, isModifierOnly: true)
        XCTAssertEqual(binding.displayString, "Key 99")
    }

    func testCodable_roundTrip_customBinding() throws {
        let original = HotkeyBinding(
            keyCode: 0,
            modifierFlags: NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue,
            isModifierOnly: false
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HotkeyBinding.self, from: data)
        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.keyCode, 0)
        XCTAssertFalse(decoded.isModifierOnly)
    }
}
