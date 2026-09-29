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

extension Color {
    static let leakPink = Color(nsColor: .leakPink)
    static let leakRose = Color(nsColor: .leakRose)

    /// Luminous opalescent pearl tones to create the iridescent liquid glass depth:
    static let pearlGleam = Color(red: 1.0, green: 0.98, blue: 0.97)   // creamy highlight gleam
    static let pearlLuster = Color(red: 0.97, green: 0.92, blue: 0.91) // silky champagne-blush nacre
    static let pearlShade = Color(red: 0.86, green: 0.68, blue: 0.66)  // soft underside refractive shade
}

/// The little floating window that holds the recording dot on the left edge of the screen
/// while you're holding the key and talking.
///
/// NSPanel is a special kind of window that can float on top of everything
/// without stealing focus, so whatever app you're typing in stays active.
final class RecordingIndicatorWindow: NSPanel {

    /// How big the window is. Sized with ample breathing room so the liquid ripple wave
    /// and ambient pearl glow expand naturally without getting clipped by the window edges.
    private static let size = NSSize(width: 36, height: 36)

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

        // Put the SwiftUI liquid glass dot (defined below) inside this window
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

/// Frosted glass: blurs whatever is behind the dot, like looking through frosted glass.
/// This gives the droplet authentic Apple liquid glass translucency.
///
/// Borrowing macOS's NSVisualEffectView and wrapping it for SwiftUI.
private struct FrostedGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow       // crisp, vibrant liquid glass blur
        view.appearance = NSAppearance(named: .vibrantLight) // light glass so the pearl reads clean
        view.blendingMode = .behindWindow // blur what's on screen behind the dot
        view.state = .active              // keep blur active even when Leak Flow isn't frontmost
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// A sleek Apple-style liquid glass pearl recording indicator that breathes
/// with a calm, organic pulse and emits a delicate concentric ripple wave while active.
struct RecordingIndicatorView: View {
    /// The physical diameter of the pearl liquid bead
    private let dotSize: CGFloat = 14

    /// Drives the organic breathing cycle (scale and internal luster)
    @State private var isBreathing = false

    /// Drives the concentric expanding liquid ripple wave
    @State private var isRippling = false

    var body: some View {
        ZStack {
            // 1. Ambient Pearl Aura (soft breathing glow behind the glass)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.leakRose.opacity(isBreathing ? 0.35 : 0.18),
                            Color.leakPink.opacity(isBreathing ? 0.25 : 0.08),
                            .clear
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: dotSize * 1.1
                    )
                )
                .frame(width: dotSize * 2.2, height: dotSize * 2.2)
                .blur(radius: 3.5)
                .scaleEffect(isBreathing ? 1.08 : 0.92)

            // 2. Concentric Liquid Ripple Wave (emits smoothly outward like a droplet in water)
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.pearlGleam.opacity(isRippling ? 0.0 : 0.55),
                            Color.leakPink.opacity(isRippling ? 0.0 : 0.35),
                            Color.leakRose.opacity(isRippling ? 0.0 : 0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
                .frame(width: dotSize, height: dotSize)
                .scaleEffect(isRippling ? 1.75 : 1.0)
                .opacity(isRippling ? 0.0 : 0.7)

            // 3. The Core Liquid Glass Pearl Bead
            ZStack {
                // A. Frosted Glass Foundation (blurs whatever desktop content is behind the bead)
                FrostedGlass()

                // B. Multi-stop Pearl Nacre Gradient (gives 3D volumetric liquid depth)
                RadialGradient(
                    stops: [
                        .init(color: Color.pearlGleam.opacity(0.92), location: 0.0),
                        .init(color: Color.pearlLuster.opacity(0.85), location: 0.30),
                        .init(color: Color.leakPink.opacity(0.78), location: 0.65),
                        .init(color: Color.pearlShade.opacity(0.70), location: 0.90),
                        .init(color: Color.leakRose.opacity(0.60), location: 1.0)
                    ],
                    center: UnitPoint(x: 0.36, y: 0.32), // offset toward top-left where the light hits
                    startRadius: 1,
                    endRadius: dotSize * 0.72
                )

                // C. Underside Caustic Bounce (light refracting through thick glass)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.pearlLuster.opacity(0.45),
                                Color.clear
                            ],
                            center: UnitPoint(x: 0.68, y: 0.72),
                            startRadius: 0,
                            endRadius: dotSize * 0.45
                        )
                    )

                // D. Apple Convex Glass Specular Highlight (glossy meniscus curvature)
                Ellipse()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.85), location: 0.0),
                                .init(color: Color.white.opacity(0.35), location: 0.55),
                                .init(color: Color.clear, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: dotSize * 0.70, height: dotSize * 0.36)
                    .offset(x: 0, y: -dotSize * 0.20)
                    .opacity(isBreathing ? 0.95 : 0.75)

                // E. Micro Catchlight (pinpoint studio reflection at 10 o'clock)
                Circle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 1.6, height: 1.6)
                    .offset(x: -dotSize * 0.22, y: -dotSize * 0.22)
                    .blur(radius: 0.15)
            }
            .frame(width: dotSize, height: dotSize)
            .clipShape(Circle())
            .overlay(
                // F. Fresnel Glass Rim (razor-sharp refractive boundary)
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.88), location: 0.0),
                                .init(color: Color.white.opacity(0.35), location: 0.40),
                                .init(color: Color.pearlLuster.opacity(0.25), location: 0.70),
                                .init(color: Color.leakRose.opacity(0.45), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.65
                    )
            )
            .overlay(
                // Outer delicate hairline definition
                Circle()
                    .stroke(Color.white.opacity(0.20), lineWidth: 0.4)
            )
            .shadow(color: Color.leakRose.opacity(0.35), radius: 3, x: 0, y: 1.5)
            .scaleEffect(isBreathing ? 1.04 : 0.97)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(
            .easeInOut(duration: 1.5)
            .repeatForever(autoreverses: true),
            value: isBreathing
        )
        .animation(
            .easeOut(duration: 1.7)
            .repeatForever(autoreverses: false),
            value: isRippling
        )
        .onAppear {
            isBreathing = true
            isRippling = true
        }
    }
}
