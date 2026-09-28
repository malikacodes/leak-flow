import SwiftUI
import AppKit

/// Invisible view that captures the next keypress for hotkey assignment
struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var isRecording: Bool
    var onHotkeyRecorded: (HotkeyBinding) -> Void

    func makeNSView(context: Context) -> HotkeyCapturingView {
        let view = HotkeyCapturingView()
        view.onKeyEvent = { binding in
            DispatchQueue.main.async {
                onHotkeyRecorded(binding)
                isRecording = false
            }
        }
        view.onCancel = {
            DispatchQueue.main.async {
                isRecording = false
            }
        }
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }

        return view
    }

    func updateNSView(_ nsView: HotkeyCapturingView, context: Context) {}
}

/// NSView that captures key events for hotkey recording
final class HotkeyCapturingView: NSView {
    var onKeyEvent: ((HotkeyBinding) -> Void)?
    var onCancel: (() -> Void)?

    private var localMonitor: Any?
    private var flagsMonitor: Any?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.onCancel?()
                self?.cleanup()
                return nil
            }

            let binding = HotkeyBinding(
                keyCode: event.keyCode,
                modifierFlags: event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue,
                isModifierOnly: false
            )
            self?.onKeyEvent?(binding)
            self?.cleanup()
            return nil
        }

        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Only record when a modifier is pressed down, not on release
            guard !flags.isEmpty else { return event }

            let binding = HotkeyBinding(
                keyCode: event.keyCode,
                modifierFlags: flags.rawValue,
                isModifierOnly: true
            )
            self?.onKeyEvent?(binding)
            self?.cleanup()
            return nil
        }
    }

    private func cleanup() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
            flagsMonitor = nil
        }
    }

    deinit {
        cleanup()
    }
}
