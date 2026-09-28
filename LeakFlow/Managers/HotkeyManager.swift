import Foundation
import AppKit
import CoreGraphics

/// Represents the action to take in response to a hotkey event
enum HotkeyAction: Equatable {
    /// The hotkey was pressed down
    case press
    /// The hotkey was released
    case release
    /// The event should be passed through unchanged
    case passthrough
}

/// Pure logic handler for hotkey state machine, extracted for testability
struct HotkeyEventHandler {
    /// Whether the hotkey is currently held down
    var isHotkeyPressed: Bool = false

    /// Handle a modifier-only hotkey event (e.g. just the Option key)
    mutating func handleModifierOnlyHotkey(
        type: CGEventType,
        keyCode: UInt16,
        flags: CGEventFlags,
        binding: HotkeyBinding
    ) -> HotkeyAction {
        guard type == .flagsChanged else {
            return .passthrough
        }

        let expectedFlags = CGEventFlags(rawValue: UInt64(binding.modifierFlags))

        guard keyCode == binding.keyCode else {
            return .passthrough
        }

        if flags.contains(expectedFlags) && !isHotkeyPressed {
            isHotkeyPressed = true
            return .press
        } else if !flags.contains(expectedFlags) && isHotkeyPressed {
            isHotkeyPressed = false
            return .release
        }

        return .passthrough
    }

    /// Handle a regular hotkey event (e.g. Cmd+Shift+A)
    mutating func handleRegularHotkey(
        type: CGEventType,
        keyCode: UInt16,
        flags: CGEventFlags,
        binding: HotkeyBinding
    ) -> HotkeyAction {
        guard keyCode == binding.keyCode else {
            return .passthrough
        }

        let requiredFlags = CGEventFlags(rawValue: UInt64(binding.modifierFlags))
        let hasRequiredModifiers = binding.modifierFlags == 0 || flags.contains(requiredFlags)

        if type == .keyDown && hasRequiredModifiers && !isHotkeyPressed {
            isHotkeyPressed = true
            return .press
        } else if type == .keyUp && isHotkeyPressed {
            isHotkeyPressed = false
            return .release
        }

        return .passthrough
    }
}

/// Manages global hotkey detection via CGEvent tap
final class HotkeyManager {
    static let shared = HotkeyManager()

    /// Called when the hotkey is pressed down
    var onHotkeyDown: (() -> Void)?

    /// Called when the hotkey is released
    var onHotkeyUp: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapThread: Thread?
    private var eventHandler = HotkeyEventHandler()

    private init() {}

    /// Start listening for the global hotkey
    func start() {
        guard eventTap == nil else { return }

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: hotkeyEventCallback,
            userInfo: refcon
        ) else {
            print("HotkeyManager: Failed to create event tap. Accessibility permission required.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        let thread = Thread { [weak self] in
            guard let self = self, let source = self.runLoopSource else { return }
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()
        }
        thread.name = "com.malikapixels.leakflow.hotkey"
        thread.qualityOfService = .userInteractive
        thread.start()
        tapThread = thread
    }

    /// Stop listening for the global hotkey
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopSourceInvalidate(source)
        }
        eventTap = nil
        runLoopSource = nil
        tapThread?.cancel()
        tapThread = nil
        eventHandler.isHotkeyPressed = false
    }

    /// Handle a CGEvent and determine if it matches the hotkey
    fileprivate func handleEvent(_ proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let binding = AppSettings.shared.hotkeyBinding
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        let action: HotkeyAction
        if binding.isModifierOnly {
            action = eventHandler.handleModifierOnlyHotkey(type: type, keyCode: keyCode, flags: flags, binding: binding)
        } else {
            action = eventHandler.handleRegularHotkey(type: type, keyCode: keyCode, flags: flags, binding: binding)
        }

        switch action {
        case .press:
            DispatchQueue.main.async { [weak self] in
                self?.onHotkeyDown?()
            }
            return binding.isModifierOnly ? Unmanaged.passUnretained(event) : nil
        case .release:
            DispatchQueue.main.async { [weak self] in
                self?.onHotkeyUp?()
            }
            return binding.isModifierOnly ? Unmanaged.passUnretained(event) : nil
        case .passthrough:
            return Unmanaged.passUnretained(event)
        }
    }
}

/// CGEvent tap callback function
private func hotkeyEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
    return manager.handleEvent(proxy, type: type, event: event)
}
