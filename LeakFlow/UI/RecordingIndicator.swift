import SwiftUI
import AppKit

extension NSColor {
    /// Leak Flow's blush pink. It tints the glass on the recording dot.
    /// Change the hex code here to change the dot's color.
    static let leakPink = NSColor(hex: 0xEFD3CF)

    /// A deeper rose for the menu bar dot and the recording dot's glow. The blush
    /// pink above is too light to see on a light menu bar, so this gives it contrast.
    static let leakRose = NSColor(hex: 0x9C4A63)

    /// Makes a color from a hex code like 0xEFD3CF (the same kind of code
    /// you'd copy from a color picker, just with "0x" in front instead of "#").
    ///
    /// A hex code is three pairs of digits: red, green, blue. Each pair goes from
    /// 00 (none of that color) to FF (all of it). The math below just pulls each
    /// pair out and turns it into a number between 0 and 1, which is what macOS wants.
    convenience init(hex: UInt32) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255   // first pair
        let green = CGFloat((hex >> 8) & 0xFF) / 255  // middle pair
        let blue = CGFloat(hex & 0xFF) / 255          // last pair
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}

/// The little floating window that holds the recording dot on the left edge of the screen
/// while you're holding the key and talking.
///
/// NSPanel is a special kind of window that can float on top of everything
/// without stealing focus, so whatever app you're typing in stays active.
final class RecordingIndicatorWindow: NSPanel {

    /// How big the window is. It's a bit bigger than the dot itself
    /// so the dot's soft glow has room and doesn't get cut off.
    private static let size = NSSize(width: 22, height: 22)

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel], // no title bar, and clicking it won't switch apps
            backing: .buffered,
            defer: false
        )

        level = .floating          // stay on top of other windows
        isOpaque = false           // let the see-through parts actually be see-through
        backgroundColor = .clear   // the window itself is invisible; only the dot shows
        hasShadow = false          // the dot draws its own glow
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .stationary] // show up on every desktop
        ignoresMouseEvents = true  // clicks pass right through it, like it isn't there

        // Put the SwiftUI dot (defined below) inside this window
        contentView = NSHostingView(rootView: RecordingIndicatorView())

        positionOnLeftEdge()
    }

    /// Put the window right up against the left edge of the screen, halfway down.
    func positionOnLeftEdge() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame // the screen minus the menu bar and Dock

        let x = visible.minX                     // flush with the left edge
        let y = visible.midY - frame.height / 2  // centered top to bottom

        setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// Show the dot (called when you press the key)
    func showIndicator() {
        positionOnLeftEdge()
        orderFrontRegardless()
    }

    /// Hide the dot (called when you let go)
    func hideIndicator() {
        orderOut(nil)
    }
}

/// Frosted glass: blurs whatever is behind the dot, like looking through a
/// frosted shower door. This is what makes it see-through instead of flat.
///
/// SwiftUI can't make this effect by itself, so this borrows the macOS one
/// (NSVisualEffectView, the same thing behind Control Center and menus) and
/// wraps it so SwiftUI can use it.
private struct FrostedGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover          // a soft, see-through blur
        view.appearance = NSAppearance(named: .vibrantLight) // light glass, so the pink reads as pink, not gray
        view.blendingMode = .behindWindow // blur what's on screen behind the dot
        view.state = .active              // keep the blur on even when Leak Flow isn't the active app
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// What the indicator looks like: a small dot of pink-tinted frosted glass
/// that gently breathes (grows and fades a little) while you're talking.
struct RecordingIndicatorView: View {
    /// How strong the pink tint is on top of the glass.
    /// 1.0 would hide the glass completely; lower is more see-through.
    private let pinkTint = 0.55

    /// How big the dot is, in points
    private let dotSize: CGFloat = 14

    /// Flips back and forth to make the dot breathe
    @State private var isPulsing = false

    var body: some View {
        // Layers, back to front (like stacking sheets of tinted plastic):
        ZStack {
            FrostedGlass()                                   // 1. the blurry glass
            Color(nsColor: .leakPink).opacity(pinkTint)      // 2. a wash of your pink
            LinearGradient(                                  // 3. a soft shine on the top half,
                colors: [Color.white.opacity(0.4), .clear],  //    so it looks round, not flat
                startPoint: .top,
                endPoint: .center
            )
        }
        .frame(width: dotSize, height: dotSize)
        .clipShape(Circle()) // trim all three layers to a circle
        .overlay(
            // A thin, bright edge, like light catching the rim of a glass bead
            Circle()
                .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
        )
        .shadow(color: Color(nsColor: .leakRose).opacity(0.35), radius: 3) // a faint pink glow
        .scaleEffect(isPulsing ? 1.0 : 0.8) // breathe: grow a little...
        .opacity(isPulsing ? 1.0 : 0.6)     // ...and brighten, then shrink and fade back
        .animation(
            .easeInOut(duration: 0.8)
            .repeatForever(autoreverses: true), // back and forth, forever, while it's showing
            value: isPulsing
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity) // center the dot in its window
        .onAppear {
            isPulsing = true // start breathing as soon as the dot shows up
        }
    }
}
