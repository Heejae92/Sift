import SwiftUI

/// Motion tokens. Transform + opacity only. Entries ease out, exits are faster, and every
/// animation is gated on Reduce Motion through `gated(_:reduce:)` (never call `withAnimation`
/// with a raw curve). Swipe distances live in `DSSwipe`; this file owns time.
enum DSMotion {
    /// Micro: press, focus.
    static let dur1: Double = 0.12
    /// Standard UI: color/state changes, stamp fade on rewind.
    static let dur2: Double = 0.18
    /// Surface transitions: sheet, card expand.
    static let dur3: Double = 0.24
    /// Synthesized "medium flick" when a verdict comes from a button instead of a swipe.
    static let buttonFlick: Double = 0.28
    /// Swipe exit duration window; the actual value comes from release velocity.
    static let exitMin: Double = 0.18
    static let exitMax: Double = 0.32
    /// Cross-fades: next-card fade-in, cell removal, Reduce-Motion exit.
    static let fade: Double = 0.18
    /// Reduce Motion: hold the stamp this long before the cross-fade so the verdict is readable.
    static let stampHoldReduced: Double = 0.25
    /// Toast auto-dismiss.
    static let toastVisible: Double = 2.5
    /// All-done confetti burst. Under Reduce Motion there is no confetti (P-15).
    static let confetti: Double = 0.6
    /// Per-cell delay when a grid empties (Trash purge-all): cells fade over `fade`, each starting
    /// this much after the previous one, so a full screen of cells clears in about half a second.
    static let stagger: Double = 0.02
    /// The Permission demo loop (§11.1): one synthetic verdict per card, then a pause before the next.
    static let demoCard: Double = 1.2
    static let demoPause: Double = 1.0
    /// Scale a stamp pops in from on a button-triggered verdict (1.15 → 1), driven by `stampPop`.
    static let stampPopScale: CGFloat = 1.15

    // MARK: Curves
    /// Ease-out entry.
    static var enter: Animation { .timingCurve(0.23, 1, 0.32, 1, duration: dur3) }
    /// Fast ease-in exit.
    static var exit: Animation { .timingCurve(0.32, 0, 0.67, 0, duration: dur1) }
    /// Standard state change.
    static var standard: Animation { .timingCurve(0.40, 0, 0.20, 1, duration: dur2) }
    /// The throw: ease-out with a data-driven length (see `exitDuration`).
    static func throwOut(duration: Double) -> Animation {
        .timingCurve(0.23, 1, 0.32, 1, duration: duration)
    }
    /// clamp(exitDistanceX / |v|, exitMin, exitMax): a hard flick leaves in 0.18 s,
    /// a threshold crawl in 0.32 s, so momentum is never cut.
    static func exitDuration(velocity: CGFloat) -> Double {
        let v = Double(abs(velocity))
        guard v > 0 else { return exitMax }
        return min(max(Double(DSSwipe.exitDistanceX) / v, exitMin), exitMax)
    }

    // MARK: Springs (response / dampingFraction)
    /// Card returns after an uncommitted drag: one small overshoot, settled in ~0.5 s.
    static var snapBack: Animation { .spring(response: 0.35, dampingFraction: 0.70) }
    /// Rewind: the card LANDS, it doesn't bounce.
    static var land: Animation { .spring(response: 0.45, dampingFraction: 0.78) }
    /// Stamp pop on a button-triggered verdict (1.15 → 1).
    static var stampPop: Animation { .spring(response: 0.28, dampingFraction: 0.50) }
    /// Button press (scale 0.90 → 1).
    static var press: Animation { .spring(response: 0.25, dampingFraction: 0.55) }
    /// Stack re-layout after a commit — same feel as the snap so the deck breathes as one.
    static var stackSettle: Animation { snapBack }

    /// Reduce Motion substitutes, named here so no call site ever spells a raw curve (P-15).
    /// A linear snap-back and a cross-fade are *replacements*, not removals: the card still has to
    /// return, and the verdict still has to leave.
    static var snapBackReduced: Animation { .linear(duration: dur1) }
    /// Linear over `fade`: the next card's fade-in, thumbnail-cell removal (each cell offset by
    /// `stagger`), and the Reduce Motion substitute for the throw.
    static var crossFade: Animation { .linear(duration: fade) }

    /// Reduce Motion helper: nil removes the transition, state changes still apply.
    static func gated(_ animation: Animation, reduce: Bool) -> Animation? {
        reduce ? nil : animation
    }

    /// Reduce Motion with a documented SUBSTITUTE (UI_DESIGN §6 lists every one). Use this form
    /// wherever the table prescribes a replacement rather than "removed", passing a named token
    /// above — never a curve written at the call site.
    static func gated(_ animation: Animation, reduce: Bool, reduced: Animation?) -> Animation? {
        reduce ? reduced : animation
    }
}

/// Press style for verdict buttons and primary buttons: pressed = scale 0.90 with the `press`
/// spring. Under Reduce Motion the pressed scale stays (it is state), only the spring goes.
struct DSPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var scale: CGFloat = 0.90

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(DSMotion.gated(DSMotion.press, reduce: reduceMotion),
                       value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == DSPressStyle {
    static var dsPress: DSPressStyle { DSPressStyle() }
}
