import SwiftUI

/// UI_DESIGN §10 "VerdictStamp" and ADR-013: a pill carrying the verdict glyph and the stamp word,
/// a solid `main` fill with the verdict's `on` ink, floating. Solid, not an outline, because
/// screenshots are usually white and an outline vanishes on one. The stamp word is the one text set
/// in `on` at the 3:1 bar: at 32 pt it is WCAG large text (P-19).
///
/// `ScreenshotCard` places the three stamps: ARCHIVE top-left at −`DSSwipe.stampTiltDegrees`, TRASH
/// top-right at +`DSSwipe.stampTiltDegrees`, FAVE upright and raised above the centre by
/// `DSSize.stampFaveRaise`. Each is inset by `DSSpace.s5`.
///
/// Decoration only (P-22): VoiceOver hears the verdict as the custom action the user invoked and as
/// the announcement after it, so every stamp is hidden from it.
struct VerdictStamp: View {
    let verdict: Verdict
    /// `SwipeGeometry.stampOpacity(distance:)` for the active sector while dragging, 1 once
    /// committed, 0 for the two inactive stamps.
    let opacity: Double

    /// P-20: the call site owns Dynamic Type for the stamp. `stampFont(size:)` clamps the scaled
    /// value to `DSTextRole.stampMaxSize` and returns a fixed-size font, so nothing scales twice.
    @ScaledMetric(relativeTo: .largeTitle) private var stampSize = DSTextRole.stampBaseSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: DSSpace.s2) {
            verdict.icon.image
                .resizable()
                .scaledToFit()
                .frame(width: DSSize.stampIcon, height: DSSize.stampIcon)
            Text(verdict.stampWord)
                .font(DSTextRole.stampFont(size: stampSize))
                .tracking(DSTextRole.stamp.tracking)
        }
        .foregroundStyle(verdict.colors.on)
        .padding(.vertical, DSSpace.s2)
        .padding(.horizontal, DSSpace.s4)
        .background(verdict.colors.main, in: RoundedRectangle(cornerRadius: DSRadius.pill, style: .continuous))
        .fixedSize()
        .dsShadow(.floating)
        .scaleEffect(scale)
        .rotationEffect(.degrees(tilt))
        .opacity(opacity)
        .accessibilityHidden(true)
    }

    /// TRASH leans right, ARCHIVE leans left, FAVE stands upright (ADR-013).
    private var tilt: Double {
        switch verdict {
        case .trash: return Double(DSSwipe.stampTiltDegrees)
        case .archive: return -Double(DSSwipe.stampTiltDegrees)
        case .fave: return .zero
        }
    }

    /// The stamp settles from `DSMotion.stampPopScale` to 1 as it becomes opaque. A button verdict
    /// animates the opacity on `DSMotion.stampPop`, so the stamp pops in; a swipe presses it down as it
    /// reveals, as the guide's deck does. Reduce Motion keeps the opacity and drops the scale.
    private var scale: CGFloat {
        guard !reduceMotion else { return 1 }
        return DSMotion.stampPopScale - (DSMotion.stampPopScale - 1) * CGFloat(opacity)
    }
}
