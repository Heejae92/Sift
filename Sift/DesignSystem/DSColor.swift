import SwiftUI
import Foundation

/// Color tokens — the canonical source (ADR-001). The app is LIGHT ONLY (ADR-006): every token
/// is a fixed `oklch(L, C, H)` value and the root view pins `.preferredColorScheme(.light)`.
/// `scripts/ds_tokens.py` parses this file to generate the WCAG contrast table, the CSS custom
/// properties for `design-system.html`, and the name lint — keep these literal shapes:
///
///     oklch(L, C, H)              opaque token
///     oklch(L, C, H, a)           translucent token
///     <token>.opacity(a)          derived alpha
///
/// Values are OKLCH (L 0–1, C, H degrees). Hex is derived, never written here.
/// Palette lineage: the poster palette from the two reference boards — tomato, cobalt, golden
/// yellow, mint, violet, lime, pink, lavender on white, with a navy ink (ADR-004, ADR-005).
enum DSColor {

    // MARK: - Surfaces
    /// Screen background — pure white (owner decision 2026-09-23). Cards on it separate by
    /// `DSShadow.floating`, not by tint.
    static let canvas        = oklch(1, 0, 0)
    /// Cards, sheets, the letterbox behind a screenshot. Pure white so screenshots are not tinted.
    static let surface       = oklch(1, 0, 0)
    /// Secondary button fill, segmented-control track, list rows. Neutral light gray, L .935
    /// (the reference board's light-gray tile).
    static let surfaceRaised = oklch(0.935, 0, 0)
    /// Toast capsule = navy ink. Text on it is `onToast`.
    static let toast         = oklch(0.25, 0.050, 285)
    /// Translucent chip over a screenshot (date caption): white α .90 + system blur.
    /// α .90 keeps `ink` ≥ 4.5 over a pure-black screenshot (measured 13:1).
    static let chip          = oklch(1, 0, 0, 0.90)

    // MARK: - Ink (navy, not black — the reference's "Discover More" button)
    /// Primary text and icons. L .25
    static let ink      = oklch(0.25, 0.050, 285)
    /// Secondary text, captions. L .45 — 6.19:1 on surfaceRaised, the tightest of the three surfaces.
    static let ink2     = oklch(0.45, 0.030, 285)
    /// Placeholder, disabled meta. L .51 is the ceiling for 4.5:1 on surfaceRaised, where it measures
    /// 4.77; quiet, never small.
    static let inkMuted = oklch(0.51, 0.020, 285)
    static let onToast  = oklch(1, 0, 0)
    /// Text/icons on the viewer's black bars only.
    static let onImage  = oklch(1, 0, 0)

    // MARK: - Accent (monochrome — saturation is reserved for verdicts and blocks, ADR-005)
    /// Primary button fill = ink. On a color block the CTA is NOT a free choice between this and a
    /// white pill — it is `DSBlock.ctaFill`, the block's own ink, because a white pill measures 1.15
    /// against lime and this navy one measures 2.33 against violet (ADR-023).
    static let accent   = oklch(0.25, 0.050, 285)
    static let onAccent = oklch(1, 0, 0)
    /// Focus ring (keyboard / Full Keyboard Access): ink at 60 %, 3 pt. 45 % measured 2.79:1 on
    /// white — below the 3:1 non-text bar — so the ring is denser than the reference's.
    static let focus    = ink.opacity(0.60)

    // MARK: - Verdicts (ADR-004)
    // `main` fills the stamp pill and the verdict button; `on` is the glyph/word on it; `soft`
    // is the pale tint for chips and count badges (text on soft is always `ink`).
    // Rule for text on `main`: WCAG large text is ≥ 24 pt regular or ≥ 19 pt bold, so only the
    // stamp word (32 pt) and glyphs may use `on` at 3:1. Every smaller label on a verdict fill —
    // including the 16 pt bold destructive button — is `ink` (navy), which clears 4.5 on tomato
    // (4.61) and on yellow (10.2); on cobalt white itself clears 4.5 (6.57).
    // Yellow is the one color whose boundary never carries meaning (1.6:1 on white): the navy
    // glyph and the word FAVE do, at 10.2:1.

    /// Swipe LEFT → app Trash. Tomato.
    static let trash = VerdictColorSet(
        main: oklch(0.65, 0.190, 38),
        on:   oklch(1, 0, 0),
        soft: oklch(0.93, 0.036, 38))

    /// Swipe RIGHT → Photos album "<Brand> Archive". Cobalt.
    static let archive = VerdictColorSet(
        main: oklch(0.50, 0.240, 272),
        on:   oklch(1, 0, 0),
        soft: oklch(0.93, 0.029, 272))

    /// Swipe UP → Photos ♥ (isFavorite). Golden yellow with NAVY ink.
    static let fave = VerdictColorSet(
        main: oklch(0.85, 0.160, 92),
        on:   oklch(0.25, 0.050, 285),
        soft: oklch(0.95, 0.070, 95))

    // MARK: - Expressive palette (color blocks for onboarding & empty states, ADR-016)
    // Never carry verdict meaning. Which block goes with which screen lives in `DSBlock`.
    static let mint     = oklch(0.80, 0.100, 165)
    static let violet   = oklch(0.48, 0.160, 285)
    static let lime     = oklch(0.94, 0.200, 118)
    static let pink     = oklch(0.87, 0.080, 335)
    static let lavender = oklch(0.72, 0.140, 305)

    // MARK: - Overlays & shadows (reference elevation: two soft layers, ≤ 10 %)
    /// Modal dim behind sheets.
    static let scrim        = oklch(0.25, 0.050, 285, 0.35)
    /// `shadow-1` layer 1: 0 1 3 · ink 10 %
    static let shadowNear   = oklch(0.25, 0.050, 285, 0.10)
    /// `shadow-1` layer 2: 0 10 24 −6 · ink 5 %
    static let shadowFar    = oklch(0.25, 0.050, 285, 0.05)

    // MARK: - OKLCH → sRGB (verbatim from the previous app's design system)

    /// `oklch(L C H / a)` → sRGB `Color`. L·a 0–1, H degrees.
    static func oklch(_ L: Double, _ C: Double, _ H: Double, _ alpha: Double = 1) -> Color {
        let c = srgbComponents(L, C, H)
        return Color(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: alpha)
    }

    /// OKLCH → gamma-encoded sRGB components (0–1). Björn Ottosson's matrices.
    private static func srgbComponents(_ L: Double, _ C: Double, _ H: Double) -> (r: Double, g: Double, b: Double) {
        let hr = H * .pi / 180
        let a = C * cos(hr)
        let b = C * sin(hr)

        // OKLab → LMS' (cube)
        let l_ = L + 0.3963377774 * a + 0.2158037573 * b
        let m_ = L - 0.1055613458 * a - 0.0638541728 * b
        let s_ = L - 0.0894841775 * a - 1.2914855480 * b
        let l = l_ * l_ * l_
        let m = m_ * m_ * m_
        let s = s_ * s_ * s_

        // LMS → linear sRGB
        let r =  4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let bl = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

        return (gammaEncode(r), gammaEncode(g), gammaEncode(bl))
    }

    private static func gammaEncode(_ x: Double) -> Double {
        let v = min(max(x, 0), 1)
        return v >= 0.0031308 ? 1.055 * pow(v, 1 / 2.4) - 0.055 : 12.92 * v
    }
}

/// The three colors every verdict owns. `main` fills, `on` sits on `main`, `soft` tints.
struct VerdictColorSet {
    let main: Color
    let on: Color
    let soft: Color
}
