import SwiftUI
import UIKit

/// Type roles (ADR-003). Two voices:
///   • Display — Forager Bold Overlap: one weight for the wordmark, titles and stamps.
///     Forager is licensed through Adobe Fonts for the web only; until an app license exists
///     it is NOT bundled, and `DSFont.display` resolves to Pretendard Bold at runtime.
///   • Text — Pretendard (SIL OFL, bundled): Regular / Medium / SemiBold / Bold.
/// Ten of the eleven roles bind to a Dynamic Type text style through `relativeTo:`. `stamp` is the
/// exception: it returns a fixed-size font so its 44 pt cap cannot be scaled twice, and the call
/// site owns `@ScaledMetric(relativeTo: .largeTitle)`.
///
/// Hierarchy moves size and weight in the SAME direction. Never use `caption` as a rung above
/// `body`: a smaller-but-bolder line reads as no hierarchy, and at accessibility sizes the two
/// text styles converge.
enum DSFont {
    // PostScript names. Verify with `UIFont.familyNames` after adding the files to the bundle.
    static let displayBold  = "Forager-BoldOverlap"
    /// Forager Overlap has no cut heavier than Bold, so the two display slots resolve to the same
    /// face. The names stay separate because the roles do: a wordmark and a screen title are not
    /// the same thing, and a future family may split them again.
    static let displayBlack = "Forager-BoldOverlap"
    static let textRegular  = "Pretendard-Regular"
    static let textMedium   = "Pretendard-Medium"
    static let textSemibold = "Pretendard-SemiBold"
    static let textBold     = "Pretendard-Bold"

    /// The display PostScript names actually present in the bundle, probed once at first use.
    /// A Set, not a dictionary keyed by name: `displayBold` and `displayBlack` are the SAME string
    /// today (Forager Overlap has one cut), and a dictionary literal with duplicate keys traps at
    /// construction. Each name is still probed on its own, so splitting the family later — two
    /// distinct names, only one of them shipped — keeps falling back per cut rather than drifting
    /// to the system font.
    static let availableDisplayNames: Set<String> = {
        var found: Set<String> = []
        for name in [displayBold, displayBlack] where UIFont(name: name, size: 12) != nil {
            found.insert(name)
        }
        return found
    }()

    static func resolvedDisplay(_ name: String) -> String {
        availableDisplayNames.contains(name) ? name : textBold
    }

    /// Display face with the Pretendard Bold fallback (ADR-003), scaled by Dynamic Type.
    static func display(_ name: String, size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(resolvedDisplay(name), size: size, relativeTo: style)
    }

    /// Display face at a size the caller has ALREADY scaled (see `DSTextRole.stampFont`).
    static func displayFixed(_ name: String, size: CGFloat) -> Font {
        .custom(resolvedDisplay(name), fixedSize: size)
    }

    static func text(_ name: String, size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(name, size: size, relativeTo: style)
    }
}

enum DSTextRole: CaseIterable {
    /// Wordmark, face captions on color blocks. Forager Bold Overlap 34
    case display
    /// Screen-level statement: permission title, empty-state title. Forager Bold Overlap 28
    case headline
    /// Screen titles (Trash, Library). Forager Bold Overlap 24
    case title
    /// Progress "12 / 340". Pretendard Bold 22, tabular digits so the slash never jitters.
    case counter
    /// Card names, sheet titles. Pretendard SemiBold 18
    case subhead
    /// Copy. Pretendard Regular 16
    case body
    /// Buttons, segments. Pretendard Bold 16. At 16 pt, bold buys no relief: WCAG large text starts
    /// at 19 pt bold, so a label on a verdict fill is `ink` at 4.5:1, never `on` at 3:1 (ADR-004).
    case label
    /// Chips, secondary buttons. Pretendard SemiBold 14
    case labelSmall
    /// Dates, hints. Pretendard Medium 14 — the reference's caption floor.
    case caption
    /// Captions under the verdict buttons ONLY. Pretendard Bold 12
    case buttonCaption
    /// TRASH / ARCHIVE / FAVE pill labels. Forager Bold Overlap 32, uppercase, tracking +2; cap 44.
    case stamp
}

extension DSTextRole {
    var font: Font {
        switch self {
        case .display:       return DSFont.display(DSFont.displayBlack, size: 34, relativeTo: .largeTitle)
        case .headline:      return DSFont.display(DSFont.displayBold,  size: 28, relativeTo: .title)
        case .title:         return DSFont.display(DSFont.displayBold,  size: 24, relativeTo: .title2)
        case .counter:       return DSFont.text(DSFont.textBold,        size: 22, relativeTo: .title2).monospacedDigit()
        case .subhead:       return DSFont.text(DSFont.textSemibold,    size: 18, relativeTo: .title3)
        case .body:          return DSFont.text(DSFont.textRegular,     size: 16, relativeTo: .body)
        case .label:         return DSFont.text(DSFont.textBold,        size: 16, relativeTo: .headline)
        case .labelSmall:    return DSFont.text(DSFont.textSemibold,    size: 14, relativeTo: .subheadline)
        case .caption:       return DSFont.text(DSFont.textMedium,      size: 14, relativeTo: .footnote)
        case .buttonCaption: return DSFont.text(DSFont.textBold,        size: 12, relativeTo: .caption2)
        case .stamp:         return DSTextRole.stampFont(size: DSTextRole.stampBaseSize)
        }
    }

    /// Tracking in points: display roles +3 %, subhead and body −1 %, caption +1 %, stamp +2 pt.
    var tracking: CGFloat {
        switch self {
        // Forager Overlap's strokes intentionally run into each other, so the display roles are
        // tracked OUT by 30/1000 em rather than the usual optical tightening.
        case .display:       return 34 * 0.03
        case .headline:      return 28 * 0.03
        case .title:         return 24 * 0.03
        case .subhead:       return 18 * -0.01
        case .body:          return 16 * -0.01
        case .caption:       return 14 *  0.01
        case .stamp:         return  2
        default:             return  0
        }
    }

    /// Extra line spacing. Display roles use the font's own metrics.
    var lineSpacing: CGFloat {
        switch self {
        case .display, .headline, .title, .stamp, .counter: return 0
        case .subhead:                                      return 2
        case .body:                                         return 5
        default:                                            return 3
        }
    }

    /// Stamp sizing: the call site owns Dynamic Type —
    ///     @ScaledMetric(relativeTo: .largeTitle) private var stampSize = DSTextRole.stampBaseSize
    ///     Text("TRASH").font(DSTextRole.stampFont(size: stampSize))
    /// `stampFont` clamps the already-scaled value to `stampMaxSize` and returns a FIXED-size font,
    /// so the cap holds at accessibility sizes and nothing scales twice. `DSTextRole.stamp.font`
    /// (via `dsType`) is the unscaled 32 pt form for previews and the style guide only.
    static let stampBaseSize: CGFloat = 32
    static let stampMaxSize: CGFloat = 44

    static func stampFont(size: CGFloat) -> Font {
        DSFont.displayFixed(DSFont.displayBlack, size: min(size, stampMaxSize))
    }

    /// The display face at a size taken from measured geometry, for a typographic face that fills a
    /// region (`BlockView`): the view renders it at the region's height and then only ever shrinks
    /// it to fit, which keeps the glyph crisp where scaling a small text up would blur it. Tracked
    /// out like every display role (30/1000 em). With `stampFont(size:)`, the only Font-returning
    /// functions a view may hand to `.font` (P-13).
    static func faceFont(size: CGFloat) -> Font { DSFont.displayFixed(DSFont.displayBlack, size: size) }
    static func faceTracking(size: CGFloat) -> CGFloat { size * 0.03 }
}

extension View {
    /// Apply a type role (font + tracking + line spacing). Color is chosen per surface.
    func dsType(_ role: DSTextRole) -> some View {
        self.font(role.font).tracking(role.tracking).lineSpacing(role.lineSpacing)
    }
}
