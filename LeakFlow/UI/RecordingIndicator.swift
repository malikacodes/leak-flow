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

/// The same colors, in the form SwiftUI (the part that draws the dot) uses,
/// plus three extra pearl shades for the shading on the dot.
extension Color {
    static let leakPink = Color(nsColor: .leakPink)
    static let leakRose = Color(nsColor: .leakRose)

    static let pearlGleam = Color(red: 1.0, green: 0.98, blue: 0.97)   // almost white, for where light hits the pearl
    static let pearlLuster = Color(red: 0.97, green: 0.92, blue: 0.91) // a soft cream-pink, for the middle of the pearl
    static let pearlShade = Color(red: 0.86, green: 0.68, blue: 0.66)  // a dusty pink, for the shadowy bottom edge
}

/// The little floating window that holds the recording dot on the left edge of the screen
/// while you're holding the key and talking.
///
/// NSPanel is a special kind of window that can float on top of everything
/// without stealing focus, so whatever app you're typing in stays active.
final class RecordingIndicatorWindow: NSPanel {

    /// How big the window is. It's much bigger than the 14-point pearl so the
    /// glow and the ripple ring have room to spread out without getting cut off.
    private static let size = NSSize(width: 56, height: 56)

    /// How far the pearl sits from the left edge of the screen, in points.
    /// At its biggest the ripple ring reaches about 13 points out from the
    /// pearl's middle, so this leaves enough room for the whole ring (and most
    /// of the glow) to show without getting cut off by the screen edge.
    private static let edgeGap: CGFloat = 12

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

    /// Put the pearl right up against the left edge of the screen, halfway down.
    func positionOnLeftEdge() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame // the screen minus the menu bar and Dock

        // The pearl sits in the middle of its window, and the window is wider than
        // the pearl. So we slide the window partly off the left side of the screen
        // until the pearl itself is edgeGap points from the edge.
        let pearlSize: CGFloat = 14
        let x = visible.minX + Self.edgeGap - (frame.width - pearlSize) / 2
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

/// Frosted glass: blurs whatever is behind the pearl, like looking through a
/// frosted shower door. That's what makes it see-through instead of flat.
///
/// SwiftUI can't make this effect by itself, so this borrows the macOS one
/// (NSVisualEffectView, the same thing behind Control Center and menus) and
/// wraps it so SwiftUI can use it.
private struct FrostedGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow        // which style of blur to use
        view.appearance = NSAppearance(named: .vibrantLight) // light glass, so the pearl looks pale and not gray
        view.blendingMode = .behindWindow // blur what's on screen behind the dot
        view.state = .active              // keep blur active even when Leak Flow isn't frontmost
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// The recording indicator: a small glass pearl that gently breathes, with a
/// thin ring that keeps spreading out from it, like ripples when you drop a
/// pebble in water.
///
/// It's built from layers stacked on top of each other, back to front,
/// like stacking see-through stickers.
struct RecordingIndicatorView: View {
    /// How wide the pearl is, in points
    private let dotSize: CGFloat = 14

    /// Flips back and forth to make the pearl and its glow breathe
    @State private var isBreathing = false

    var body: some View {
        ZStack {
            // 1. The glow behind the pearl: a soft, blurry pink haze that
            //    brightens and grows a little on each breath
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
                // The box is bigger than the glow itself (which fades out at
                // about 1.1x the pearl's width) so the blur has room to soften
                // all the way out. In a tighter box the blur gets trimmed and
                // leaves a faint square edge.
                .frame(width: dotSize * 3, height: dotSize * 3)
                .blur(radius: 3.5)
                .scaleEffect(isBreathing ? 1.08 : 0.92)

            // 2. The ripple ring (it has its own timing, see RippleRing below)
            RippleRing(size: dotSize)

            // 3. The pearl itself
            ZStack {
                // A. Frosted glass at the very back, so the screen blurs through
                FrostedGlass()

                // B. The pearl's main color: nearly white near the top left
                //    (where the light hits) fading to pink and then rose at the
                //    edges. This is what makes it look round instead of flat.
                RadialGradient(
                    stops: [
                        .init(color: Color.pearlGleam.opacity(0.92), location: 0.0),
                        .init(color: Color.pearlLuster.opacity(0.85), location: 0.30),
                        .init(color: Color.leakPink.opacity(0.78), location: 0.65),
                        .init(color: Color.pearlShade.opacity(0.70), location: 0.90),
                        .init(color: Color.leakRose.opacity(0.60), location: 1.0)
                    ],
                    center: UnitPoint(x: 0.36, y: 0.32), // the brightest spot is up and to the left
                    startRadius: 1,
                    endRadius: dotSize * 0.72
                )

                // C. A faint glow near the bottom right, like light passing
                //    through a glass marble and coming out the other side
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

                // D. The shiny streak across the top, like the shine on a
                //    glass bead. It gets a bit brighter on each breath.
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

                // E. A tiny bright speck of reflected light, up and to the left
                Circle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 1.6, height: 1.6)
                    .offset(x: -dotSize * 0.22, y: -dotSize * 0.22)
                    .blur(radius: 0.15)
            }
            .frame(width: dotSize, height: dotSize)
            .clipShape(Circle()) // trim all the layers above into a circle
            .overlay(
                // F. The pearl's outline: bright white at the top left, fading
                //    to rose at the bottom right, like light catching the rim
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
                // G. One more very faint white outline, so the edge stays crisp
                Circle()
                    .stroke(Color.white.opacity(0.20), lineWidth: 0.4)
            )
            .shadow(color: Color.leakRose.opacity(0.35), radius: 3, x: 0, y: 1.5) // a soft pink shadow underneath
            .scaleEffect(isBreathing ? 1.04 : 0.97) // swell and shrink just a little on each breath
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // center everything in the window
        .onAppear {
            // Start breathing: take 1.5 seconds to breathe in, 1.5 to breathe
            // out, and keep going as long as the pearl is showing.
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }
}

/// A thin ring that starts at the pearl's edge, spreads outward, and fades
/// away, over and over, like ripples in water.
///
/// This lives in its own little view on purpose. Each animation in SwiftUI
/// needs its own timing, and when the ripple shared a view with the breathing,
/// the breathing's timing won and the ring never spread out. Giving the ripple
/// its own view keeps the two from fighting.
private struct RippleRing: View {
    /// How big the ring is when it starts (the same size as the pearl)
    let size: CGFloat

    /// false = small and visible, true = spread out and faded away
    @State private var hasSpread = false

    var body: some View {
        Circle()
            .stroke(Color.pearlGleam, lineWidth: 1.0)
            .frame(width: size, height: size)
            .scaleEffect(hasSpread ? 1.8 : 1.0) // grow to almost twice the pearl's size
            .opacity(hasSpread ? 0.0 : 0.55)    // while fading from soft to gone
            .onAppear {
                // Spread out over 1.7 seconds, then snap back and start again
                // (autoreverses: false means it doesn't shrink back slowly).
                withAnimation(.easeOut(duration: 1.7).repeatForever(autoreverses: false)) {
                    hasSpread = true
                }
            }
    }
}
