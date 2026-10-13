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

/// What the app should do with the recording when the key moves
enum RecordingCommand: Equatable {
    case start
    case stop
    case nothing
}

extension HotkeyAction {
    /// A press shorter than this counts as a tap. About a third of a second:
    /// longer than a quick tap, shorter than holding the key to say even one word.
    static let tapLength: TimeInterval = 0.35

    /// Turns a key press or release into start, stop or nothing.
    ///
    /// The key works two ways without a setting. Hold it and talk, and letting
    /// go stops the recording, like a walkie-talkie. Tap it instead, and the
    /// recording stays on like a light switch until the next press. The only
    /// difference is how long the key was down (`heldFor`) when it came back up.
    /// `isRecording` is whether a recording really started, which is what stops
    /// a "stop" with nothing to stop.
    func recordingCommand(isRecording: Bool, heldFor: TimeInterval) -> RecordingCommand {
        switch self {
        case .press:
            // Pressing while it's already recording is the second press of a tap
            return isRecording ? .stop : .start
        case .release:
            guard isRecording else { return .nothing }
            return heldFor < Self.tapLength ? .nothing : .stop
        case .passthrough:
            return .nothing
        }
    }
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

    /// Called when the Stream Deck key is pushed
    var onStreamDeckPush: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapThread: Thread?
    private var eventHandler = HotkeyEventHandler()

    /// A second talk key, just for my Stream Deck: F20. My real talk key is
    /// Right Command on its own, and a Stream Deck button can't send a lone
    /// Command key. My keyboard has no F20, so nothing else will ever press it.
    /// (90 is the Mac's number for the F20 key.)
    static let streamDeckKey = HotkeyBinding(keyCode: 90, modifierFlags: 0, isModifierOnly: false)
    /// Its own press/release tracking, so the two keys can't confuse each other
    private var streamDeckHandler = HotkeyEventHandler()

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
        streamDeckHandler.isHotkeyPressed = false
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

        // The Stream Deck key gets checked first. Each push flips the recording
        // on or off, however long the button stays down. A deck button is slower
        // to come back up than a keyboard key, so timing it like a tap made me
        // hold it. Letting go means nothing, and F20 is swallowed so no other
        // app sees it.
        if keyCode == Self.streamDeckKey.keyCode {
            let deckAction = streamDeckHandler.handleRegularHotkey(
                type: type, keyCode: keyCode, flags: flags, binding: Self.streamDeckKey
            )
            if deckAction == .press {
                DispatchQueue.main.async { [weak self] in self?.onStreamDeckPush?() }
            }
            return nil
        }

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
