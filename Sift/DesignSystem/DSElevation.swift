import SwiftUI

/// Elevation & layering (reference rules, ADR-006): borders are forbidden (the focus ring is the
/// one exception); surfaces separate by tint and whitespace; shadows exist only for things that
/// FLOAT — the front card, a committed stamp, the toast, sheets, the verdict buttons — and are
/// two soft layers at ≤ 10 %. Every shadow goes through `dsShadow` so `compositingGroup()` is
/// applied first (otherwise SwiftUI shadows each child separately and a card grows a halo).
enum DSShadow {
    /// `shadow-1`: 0 1 3 · 10 % + 0 10 24 · 5 %.
    case floating
    /// `shadow-stack`: cast UPWARD so a card reads as lying on the one below it.
    case stack
}

extension View {
    @ViewBuilder
    func dsShadow(_ level: DSShadow) -> some View {
        switch level {
        case .floating:
            self.compositingGroup()
                .shadow(color: DSColor.shadowNear, radius: 1.5, x: 0, y: 1)
                .shadow(color: DSColor.shadowFar, radius: 12, x: 0, y: 10)
        case .stack:
            self.compositingGroup()
                .shadow(color: DSColor.shadowNear, radius: 3, x: 0, y: -2)
                .shadow(color: DSColor.shadowFar, radius: 10, x: 0, y: -8)
        }
    }

    /// Focus ring, 3 pt, outside the shape. Keyboard / Full Keyboard Access only.
    ///
    /// The colour is a PARAMETER because the ring is translucent and its ratio therefore depends on
    /// what it sits on. `DSColor.focus` (ink at 60 %) is tuned for the neutral surfaces and clears
    /// 4.34 on `canvas` and 4.06 on `surfaceRaised`; 45 % measured 2.79 on white, under the 3:1
    /// non-text bar, which is why it was raised (ADR-021). Over a saturated block the same token
    /// falls to 2.65 on tomato, 2.92 on lavender and 1.71 on violet, so a control on a block passes
    /// `DSBlock.focusRing` — that block's ink at full strength — instead. Anything drawn on a
    /// surface with no measured focus row has no business hosting a focusable control.
    func dsFocusRing(_ focused: Bool, cornerRadius: CGFloat, color: Color = DSColor.focus) -> some View {
        self.overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(color, lineWidth: focused ? DSSize.focusRing : 0)
                .padding(-DSSize.focusRing)
        }
    }
}

/// z-index scale. SwiftUI `zIndex` is a Double; keep the reference ladder.
enum DSLayer {
    static let base: Double = 0
    /// Sticky header, docked verdict row
    static let sticky: Double = 100
    /// Popovers, context menus
    static let dropdown: Double = 1000
    /// Sheets + scrim
    static let modal: Double = 2000
    /// Toast — always on top
    static let toast: Double = 3000
}
