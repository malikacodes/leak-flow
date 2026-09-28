import SwiftUI
import AppKit

/// Floating window that shows a pulsing red dot during recording
final class RecordingIndicatorWindow: NSPanel {

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 180, height: 72),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        ignoresMouseEvents = true

        let hostingView = NSHostingView(rootView: RecordingIndicatorView())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 140, height: 36))
        container.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        contentView = container

        positionNearMenuBar()
    }

    /// Position the indicator centered horizontally, just below the menu bar
    func positionNearMenuBar() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let menuBarHeight = screen.frame.height - screen.visibleFrame.height - (screen.visibleFrame.origin.y - screen.frame.origin.y)

        let x = (screenFrame.width - frame.width) / 2 + screenFrame.origin.x
        let y = screenFrame.maxY - menuBarHeight - frame.height - 4 - (screen.visibleFrame.height * 0.20)

        setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// Show the recording indicator
    func showIndicator() {
        positionNearMenuBar()
        orderFrontRegardless()
    }

    /// Hide the recording indicator
    func hideIndicator() {
        orderOut(nil)
    }
}

/// SwiftUI view for the recording indicator
struct RecordingIndicatorView: View {
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .opacity(isPulsing ? 1.0 : 0.4)
                .animation(
                    .easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true),
                    value: isPulsing
                )

            Text("Recording...")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.75))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                .shadow(color: Color.white.opacity(0.25), radius: 3, x: 0, y: 0)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)
        .onAppear {
            isPulsing = true
        }
    }
}
