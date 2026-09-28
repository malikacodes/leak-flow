import SwiftUI
import AppKit

extension NSColor {
    /// Leak Flow's deep rose pink, shared by the menu bar dot and the recording pill
    static let leakPink = NSColor(red: 0.78, green: 0.29, blue: 0.46, alpha: 1)
}

/// Floating window on the left edge of the screen that shows a pulsing dot during recording
final class RecordingIndicatorWindow: NSPanel {

    private static let size = NSSize(width: 40, height: 150)

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        ignoresMouseEvents = true

        contentView = NSHostingView(rootView: RecordingIndicatorView())

        positionOnLeftEdge()
    }

    /// Position the indicator against the left edge, centered top to bottom
    func positionOnLeftEdge() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame

        let x = visible.minX + 12
        let y = visible.midY - frame.height / 2

        setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// Show the recording indicator
    func showIndicator() {
        positionOnLeftEdge()
        orderFrontRegardless()
    }

    /// Hide the recording indicator
    func hideIndicator() {
        orderOut(nil)
    }
}

/// SwiftUI view for the recording indicator: a tall pink pill with the dot on top
/// and "Recording..." reading top to bottom
struct RecordingIndicatorView: View {
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(Color.white)
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
                .fixedSize()
                .rotationEffect(.degrees(90))
                .frame(width: 16, height: 90)
        }
        .padding(.vertical, 12)
        .frame(width: 32)
        .background(
            Capsule()
                .fill(Color(nsColor: .leakPink))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isPulsing = true
        }
    }
}
