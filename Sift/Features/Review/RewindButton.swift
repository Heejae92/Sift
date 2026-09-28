import SwiftUI

/// UI_DESIGN §10 "VerdictButtonRow and RewindButton": the one undo control (ADR-008, P-03). A ghost,
/// with no fill and no border: `DSSize.rewindButton` across, pinned to the leading edge of the
/// docked row, with a `DSTextRole.buttonCaption` caption under it like the three verdicts. It stays
/// on screen in `allDone`, where it is the way back from the block.
///
/// Ink: `ink2` over the canvas, as a chrome glyph. Over a full-bleed block the ink and the focus ring
/// come from the block (§9 Rules, ADR-023). With no history, or while a card is in flight, it drops
/// to `DSOpacity.disabled` and gains the disabled trait. It keeps its label rather than disappearing.
struct RewindButton: View {
    let isEnabled: Bool
    /// The block behind the button, when there is one.
    let block: DSBlock?
    let action: () -> Void
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: DSSpace.s1) {
            Button(action: action) {
                DSIcon.rewind.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: DSSize.iconChrome, height: DSSize.iconChrome)
                    .frame(width: DSSize.rewindButton, height: DSSize.rewindButton)
                    .contentShape(Circle())
            }
            .buttonStyle(.dsPress)
            .disabled(!isEnabled)
            .focused($isFocused)
            .dsFocusRing(isFocused, cornerRadius: DSRadius.pill, color: block?.focusRing ?? DSColor.focus)
            .accessibilityLabel("Rewind")
            .accessibilityHint("Brings back the last screenshot you sorted.")
            VerdictCaption("Rewind", width: DSSize.rewindButton)
        }
        .foregroundStyle(block?.ink ?? DSColor.ink2)
        .opacity(isEnabled ? 1 : DSOpacity.disabled)
        .animation(DSMotion.gated(DSMotion.standard, reduce: reduceMotion), value: isEnabled)
    }
}
