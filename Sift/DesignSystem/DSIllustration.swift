import SwiftUI

/// Typographic faces (ADR-016): a face is ONE glyph borrowed from a world script, framed by round
/// parentheses. The parentheses are the head; the glyph is the eyes and the mouth at once, so a
/// face is a single line, not two. Seven blocks, seven scripts, no glyph used twice.
///
/// Forager is a Latin face, so only the parentheses come from it — each centre glyph resolves
/// to whichever system font carries that script. The weight contrast between a heavy Latin bracket
/// and a lighter non-Latin glyph is the intended look; it is also why a face is never used to carry
/// information. Faces are `accessibilityHidden`; the headline under the block says what happened.
enum DSFace: CaseIterable {
    /// Onboarding — a ready, lopsided grin. \u{141B}
    case eager
    /// Queue finished — wide open delight. \u{0BB6}
    case delighted
    /// Trash emptied — a shrug, nothing left to care about. \u{30C4}
    case breezy
    /// Favorites empty — soft, waiting to be given something. \u{03C9}
    case soft
    /// Archive empty — perfectly, roundly blank. \u{0C20}
    case blank
    /// Permission denied — downcast. \u{0CA5}
    case tearful
    /// Limited access — head tilted, making do. \u{0479}
    case quizzical

    /// The centre glyph.
    var glyph: String {
        switch self {
        case .eager:     return "\u{141B}"   // ᐛ
        case .delighted: return "\u{0BB6}"   // ஶ
        case .breezy:    return "\u{30C4}"   // ツ
        case .soft:      return "\u{03C9}"   // ω
        case .blank:     return "\u{0C20}"   // ఠ
        case .tearful:   return "\u{0CA5}"   // ಥ
        case .quizzical: return "\u{0479}"   // ѹ
        }
    }

    /// Where the glyph comes from. Printed in UI_DESIGN section 9 so nobody has to guess, and read
    /// aloud by nothing — the face itself is hidden from VoiceOver.
    var origin: String {
        switch self {
        case .eager:     return "U+141B CANADIAN SYLLABICS NASKAPI WAA"
        case .delighted: return "U+0BB6 TAMIL LETTER SHA"
        case .breezy:    return "U+30C4 KATAKANA LETTER TU"
        case .soft:      return "U+03C9 GREEK SMALL LETTER OMEGA"
        case .blank:     return "U+0C20 TELUGU LETTER TTHA"
        case .tearful:   return "U+0CA5 KANNADA LETTER THA"
        case .quizzical: return "U+0479 CYRILLIC SMALL LETTER UK"
        }
    }

    /// The bracket pair that frames every face. Round, never square: a head is a head.
    static let open = "("
    static let close = ")"

    /// The whole face as one string, for a preview or a snapshot test.
    var text: String { "\(DSFace.open)\(glyph)\(DSFace.close)" }
}

/// Color blocks: which expressive color, which ink, which face each full-bleed screen gets.
/// The expressive palette never carries verdict meaning. The reverse is not symmetrical: two blocks
/// deliberately borrow a verdict colour — `onboarding` takes `trash.main`, the reference's hero, and
/// `limited` takes `fave.soft` — and ADR-016 records both as exceptions. There is no third.
enum DSBlock: CaseIterable {
    case onboarding, allDone, trashEmpty, favoritesEmpty, archiveEmpty, denied, limited

    var fill: Color {
        switch self {
        case .onboarding:     return DSColor.trash.main      // tomato — the reference's hero block
        case .allDone:        return DSColor.lime
        case .trashEmpty:     return DSColor.mint
        case .favoritesEmpty: return DSColor.pink
        case .archiveEmpty:   return DSColor.lavender
        case .denied:         return DSColor.violet
        case .limited:        return DSColor.fave.soft
        }
    }

    /// Ink on the block: navy everywhere except violet, which takes white (6.9:1).
    var ink: Color {
        self == .denied ? DSColor.onAccent : DSColor.ink
    }

    /// The call-to-action pill on a block INVERTS the block's ink pair: the pill is filled with the
    /// block's own ink and labelled with that ink's counterpart. Measured, and the reason the pill
    /// is not a free choice between navy and white: a white pill on `lime` is 1.15:1 against its own
    /// block and a navy pill on `violet` is 2.33:1, both invisible as shapes. Filled with the
    /// block's ink the pill clears 4.61 at worst (tomato) and 14.01 at best (pale yellow), and the
    /// label clears 16.16 on every block, in both directions.
    var ctaFill: Color { ink }

    var ctaLabel: Color {
        self == .denied ? DSColor.accent : DSColor.onAccent
    }

    /// The focus ring on a block is the block's ink at FULL strength, not `DSColor.focus`.
    /// `focus` is ink at 60 %, tuned for the neutral surfaces; composited over a saturated block it
    /// drops to 2.65 on tomato, 2.92 on lavender and 1.71 on violet, all under the 3:1 non-text bar.
    /// At full strength it is the same pair the block's own copy already passes, 4.61 at worst.
    var focusRing: Color { ink }

    var face: DSFace {
        switch self {
        case .onboarding:     return .eager
        case .allDone:        return .delighted
        case .trashEmpty:     return .breezy
        case .favoritesEmpty: return .soft
        case .archiveEmpty:   return .blank
        case .denied:         return .tearful
        case .limited:        return .quizzical
        }
    }
}
