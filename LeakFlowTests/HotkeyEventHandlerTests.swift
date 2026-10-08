import XCTest
import CoreGraphics
@testable import LeakFlow

final class HotkeyEventHandlerTests: XCTestCase {

    var handler: HotkeyEventHandler!

    override func setUp() {
        super.setUp()
        handler = HotkeyEventHandler()
    }

    // MARK: - Modifier-Only Hotkey Tests

    func testModifierOnly_pressDetected() {
        let binding = HotkeyBinding(
            keyCode: 61,
            modifierFlags: NSEvent.ModifierFlags.option.rawValue,
            isModifierOnly: true
        )
        let flags = CGEventFlags(rawValue: UInt64(NSEvent.ModifierFlags.option.rawValue))
        let action = handler.handleModifierOnlyHotkey(
            type: .flagsChanged, keyCode: 61, flags: flags, binding: binding
        )
        XCTAssertEqual(action, .press)
        XCTAssertTrue(handler.isHotkeyPressed)
    }

    func testModifierOnly_releaseDetected() {
        let binding = HotkeyBinding(
            keyCode: 61,
            modifierFlags: NSEvent.ModifierFlags.option.rawValue,
            isModifierOnly: true
        )
        // First press
        let pressFlags = CGEventFlags(rawValue: UInt64(NSEvent.ModifierFlags.option.rawValue))
        _ = handler.handleModifierOnlyHotkey(
            type: .flagsChanged, keyCode: 61, flags: pressFlags, binding: binding
        )
        // Then release (no flags)
        let action = handler.handleModifierOnlyHotkey(
            type: .flagsChanged, keyCode: 61, flags: CGEventFlags(rawValue: 0), binding: binding
        )
        XCTAssertEqual(action, .release)
        XCTAssertFalse(handler.isHotkeyPressed)
    }

    func testModifierOnly_ignoredWhenAlreadyPressed() {
        let binding = HotkeyBinding(
            keyCode: 61,
            modifierFlags: NSEvent.ModifierFlags.option.rawValue,
            isModifierOnly: true
        )
        let flags = CGEventFlags(rawValue: UInt64(NSEvent.ModifierFlags.option.rawValue))
        // First press
        _ = handler.handleModifierOnlyHotkey(
            type: .flagsChanged, keyCode: 61, flags: flags, binding: binding
        )
        // Second press (duplicate)
        let action = handler.handleModifierOnlyHotkey(
            type: .flagsChanged, keyCode: 61, flags: flags, binding: binding
        )
        XCTAssertEqual(action, .passthrough)
    }

    func testModifierOnly_ignoredForWrongKeyCode() {
        let binding = HotkeyBinding(
            keyCode: 61,
            modifierFlags: NSEvent.ModifierFlags.option.rawValue,
            isModifierOnly: true
        )
        let flags = CGEventFlags(rawValue: UInt64(NSEvent.ModifierFlags.option.rawValue))
        let action = handler.handleModifierOnlyHotkey(
            type: .flagsChanged, keyCode: 58, flags: flags, binding: binding
        )
        XCTAssertEqual(action, .passthrough)
        XCTAssertFalse(handler.isHotkeyPressed)
    }

    func testModifierOnly_ignoredForNonFlagsChanged() {
        let binding = HotkeyBinding(
            keyCode: 61,
            modifierFlags: NSEvent.ModifierFlags.option.rawValue,
            isModifierOnly: true
        )
        let flags = CGEventFlags(rawValue: UInt64(NSEvent.ModifierFlags.option.rawValue))
        let action = handler.handleModifierOnlyHotkey(
            type: .keyDown, keyCode: 61, flags: flags, binding: binding
        )
        XCTAssertEqual(action, .passthrough)
    }

    // MARK: - Regular Hotkey Tests

    func testRegularHotkey_keyDownWithModifiers_press() {
        let binding = HotkeyBinding(
            keyCode: 0,
            modifierFlags: NSEvent.ModifierFlags.command.rawValue,
            isModifierOnly: false
        )
        let flags = CGEventFlags(rawValue: UInt64(NSEvent.ModifierFlags.command.rawValue))
        let action = handler.handleRegularHotkey(
            type: .keyDown, keyCode: 0, flags: flags, binding: binding
        )
        XCTAssertEqual(action, .press)
        XCTAssertTrue(handler.isHotkeyPressed)
    }

    func testRegularHotkey_keyDownWithoutModifiers_passthrough() {
        let binding = HotkeyBinding(
            keyCode: 0,
            modifierFlags: NSEvent.ModifierFlags.command.rawValue,
            isModifierOnly: false
        )
        let action = handler.handleRegularHotkey(
            type: .keyDown, keyCode: 0, flags: CGEventFlags(rawValue: 0), binding: binding
        )
        XCTAssertEqual(action, .passthrough)
        XCTAssertFalse(handler.isHotkeyPressed)
    }

    func testRegularHotkey_keyUp_release() {
        let binding = HotkeyBinding(
            keyCode: 0,
            modifierFlags: NSEvent.ModifierFlags.command.rawValue,
            isModifierOnly: false
        )
        // First press
        let flags = CGEventFlags(rawValue: UInt64(NSEvent.ModifierFlags.command.rawValue))
        _ = handler.handleRegularHotkey(
            type: .keyDown, keyCode: 0, flags: flags, binding: binding
        )
        // Then key up
        let action = handler.handleRegularHotkey(
            type: .keyUp, keyCode: 0, flags: flags, binding: binding
        )
        XCTAssertEqual(action, .release)
        XCTAssertFalse(handler.isHotkeyPressed)
    }

    func testRegularHotkey_keyUp_notPressedIgnored() {
        let binding = HotkeyBinding(
            keyCode: 0,
            modifierFlags: NSEvent.ModifierFlags.command.rawValue,
            isModifierOnly: false
        )
        let action = handler.handleRegularHotkey(
            type: .keyUp, keyCode: 0, flags: CGEventFlags(rawValue: 0), binding: binding
        )
        XCTAssertEqual(action, .passthrough)
    }

    func testRegularHotkey_noModifierRequired() {
        let binding = HotkeyBinding(
            keyCode: 49,
            modifierFlags: 0,
            isModifierOnly: false
        )
        let action = handler.handleRegularHotkey(
            type: .keyDown, keyCode: 49, flags: CGEventFlags(rawValue: 0), binding: binding
        )
        XCTAssertEqual(action, .press)
        XCTAssertTrue(handler.isHotkeyPressed)
    }

    // MARK: - Hold to talk, or tap to keep it on

    // Protects the original way of talking: down starts, letting go after a
    // real hold stops.
    func testHold_downStartsAndLettingGoStops() {
        XCTAssertEqual(HotkeyAction.press.recordingCommand(isRecording: false, heldFor: 0), .start)
        XCTAssertEqual(HotkeyAction.release.recordingCommand(isRecording: true, heldFor: 2.0), .stop)
    }

    // The whole point of the tap: a quick press and release must not end the
    // recording, or it would stop the moment my finger came off the key.
    func testTap_lettingGoKeepsRecording() {
        XCTAssertEqual(HotkeyAction.release.recordingCommand(isRecording: true, heldFor: 0.1), .nothing)
    }

    // After a tap, the next press is the off switch, and letting go of that
    // press must not start or stop anything else.
    func testTap_nextPressStops() {
        XCTAssertEqual(HotkeyAction.press.recordingCommand(isRecording: true, heldFor: 0), .stop)
        XCTAssertEqual(HotkeyAction.release.recordingCommand(isRecording: false, heldFor: 0.1), .nothing)
    }

    // Right at the line, a press counts as a hold, so the recording can't get
    // stuck on by a press that felt like holding.
    func testPressExactlyTapLength_countsAsHold() {
        XCTAssertEqual(
            HotkeyAction.release.recordingCommand(isRecording: true, heldFor: HotkeyAction.tapLength),
            .stop
        )
    }

    // If the recording never started (say the last one was still being
    // transcribed), letting go shouldn't "stop" a recording that isn't there.
    func testLetGoWithNothingRecording_doesNothing() {
        XCTAssertEqual(HotkeyAction.release.recordingCommand(isRecording: false, heldFor: 2.0), .nothing)
    }
}
