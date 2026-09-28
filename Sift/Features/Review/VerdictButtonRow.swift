import SwiftUI

/// UI_DESIGN §10 "VerdictButtonRow": three solid `main` circles with the `on` glyph, left to right
/// Trash, Fave, Archive, so the row is a map of the three directions. Fave is smaller
/// (`DSSize.faveButton`) and raised by `DSSize.faveButtonRaise`, which lines its top up with the
/// other two. Each circle carries a `DSTextRole.buttonCaption` caption. `ReviewScreen` docks the row
/// in the bottom `safeAreaInset`, centred, with `RewindButton` pinned to the leading edge.
///
/// A tap runs the same pipeline as a swipe (the synthesized flick in `DeckMotion`): one code path
/// per verdict, not two. The row is disabled unless the deck accepts input: while loading, during a
/// drag, and while a card is in flight. Disabled, the circles drop to `DSOpacity.disabled`, gain the
/// disabled trait and keep their labels.
struct VerdictButtonRow: View {
    let isEnabled: Bool
    let onVerdict: (Verdict) -> Void
    @FocusState private var focused: Verdict?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .bottom, spacing: DSSpace.s5) {
            ForEach(Verdict.rowOrder, id: \.self) { verdict in
                slot(verdict)
            }
        }
        .opacity(isEnabled ? 1 : DSOpacity.disabled)
        .animation(DSMotion.gated(DSMotion.standard, reduce: reduceMotion), value: isEnabled)
    }

    private func slot(_ verdict: Verdict) -> some View {
        let diameter = verdict == .fave ? DSSize.faveButton : DSSize.verdictButton
        return VStack(spacing: DSSpace.s1) {
            Button {
                onVerdict(verdict)
            } label: {
                verdict.icon.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: DSSize.iconVerdict, height: DSSize.iconVerdict)
                    .foregroundStyle(verdict.colors.on)
                    .frame(width: diameter, height: diameter)
                    .background(verdict.colors.main, in: Circle())
                    .dsShadow(.floating)
                    .contentShape(Circle())
            }
            .buttonStyle(.dsPress)
            .disabled(!isEnabled)
            .keyboardShortcut(verdict.arrowKey, modifiers: [])
            .focused($focused, equals: verdict)
            .dsFocusRing(focused == verdict, cornerRadius: DSRadius.pill)
            .accessibilityLabel(verdict.actionName)
            .accessibilityHint(verdict.actionHint)
            .padding(.bottom, verdict == .fave ? DSSize.faveButtonRaise : .zero)
            VerdictCaption(verdict.caption, width: diameter)
                .foregroundStyle(DSColor.ink2)
        }
    }
}

/// The `DSTextRole.buttonCaption` line under a verdict or rewind button. VoiceOver reads the
/// button's own label instead, so the caption is hidden from it. At accessibility text sizes the
/// caption wraps inside its button's width rather than pushing the row off the screen (P-20).
struct VerdictCaption: View {
    private let text: String
    private let width: CGFloat
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(_ text: String, width: CGFloat) {
        self.text = text
        self.width = width
    }

    var body: some View {
        Text(text)
            .dsType(.buttonCaption)
            .multilineTextAlignment(.center)
            .frame(width: dynamicTypeSize.isAccessibilitySize ? width : nil)
            .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: true)
            .accessibilityHidden(true)
    }
}

// MARK: - Verdict, as the Review screen draws and names it

extension Verdict {
    /// Left to right in the docked row: the map of the three directions (§10).
    static let rowOrder: [Verdict] = [.trash, .fave, .archive]
    /// VoiceOver custom actions, in the fixed order of P-22 (Rewind follows them, last).
    static let actionOrder: [Verdict] = [.trash, .archive, .fave]

    var colors: VerdictColorSet {
        switch self {
        case .trash: return DSColor.trash
        case .archive: return DSColor.archive
        case .fave: return DSColor.fave
        }
    }

    var icon: DSIconRef {
        switch self {
        case .trash: return DSIcon.trash
        case .archive: return DSIcon.archive
        case .fave: return DSIcon.fave
        }
    }

    /// "Favorite", although the stamp reads FAVE: the stamp is display type, the action is
    /// language (§13).
    var actionName: String {
        switch self {
        case .trash: return "Trash"
        case .archive: return "Archive"
        case .fave: return "Favorite"
        }
    }

    var actionHint: String {
        switch self {
        case .trash: return "Moves this screenshot to Trash."
        case .archive: return "Adds this screenshot to the \(Brand.archiveAlbumTitle) album in Photos."
        case .fave: return "Marks this screenshot as a favorite in Photos."
        }
    }

    /// Impact weight encodes direction (ADR-007).
    var haptic: DSHaptic {
        switch self {
        case .trash: return .trash
        case .archive: return .archive
        case .fave: return .fave
        }
    }

    /// The arrow key that sends a card the same way as the swipe (IA §5, "arrow key").
    var arrowKey: KeyEquivalent {
        switch self {
        case .trash: return .leftArrow
        case .archive: return .rightArrow
        case .fave: return .upArrow
        }
    }
}
