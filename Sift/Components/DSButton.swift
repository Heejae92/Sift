import SwiftUI

/// UI_DESIGN §10 "Buttons": five kinds, no more, and only four of them carry a fill.
///
/// | Kind | Fill | Label | Radius |
/// |---|---|---|---|
/// | `.primary` | `DSColor.accent` | `DSColor.onAccent`, `DSTextRole.label` | `DSRadius.pill` |
/// | `.secondary` | `DSColor.surfaceRaised` | `DSColor.ink`, `DSTextRole.labelSmall` | `DSRadius.md` |
/// | `.destructive` | `DSColor.trash.main` | `DSColor.ink`, `DSTextRole.label` | `DSRadius.pill` |
/// | `.blockCTA(block)` | `block.ctaFill` | `block.ctaLabel`, `DSTextRole.label` | `DSRadius.pill` |
/// | `.blockText(block)` | none | `block.ink`, `DSTextRole.label`, underlined | `DSRadius.pill`, for the focus ring only |
///
/// - The destructive label is `ink`, never `trash.on`: `DSTextRole.label` is 16 pt bold, below the
///   19 pt bold large-text floor, so it owes 4.5:1 — navy on tomato is 4.61, white only 3.51
///   (ADR-004). The kind carries `ButtonRole.destructive`, and its title always names a count (§12).
/// - `.secondary` is for a white surface only. On a color block the second action is `.blockText`:
///   a block carries exactly one filled action (P-19, ADR-023).
/// - Every kind pads by `DSSpace.s3` vertically and `DSSpace.s5` horizontally, is at least
///   `DSSize.tapMin` in both dimensions (P-21), presses through `DSPressStyle`, and wraps rather
///   than truncates (P-20). The button hugs its label.
/// - States: default · pressed · disabled (dimmed; keeps its label and gains the disabled trait,
///   also when a container disables it) · loading (the label is replaced by a progress view at the
///   same size, input is off; VoiceOver keeps the title and hears "In progress" as the value).
/// - Shadow: only `.primary` and `.destructive` take `DSShadow.floating`, and only when docked over
///   content, so the docking screen applies `.dsShadow(.floating)`; the button itself never does.
/// - Focus: keyboard and Full Keyboard Access only, through `.dsFocusRing`. The two block kinds pass
///   `DSBlock.focusRing`; the rest keep the default `DSColor.focus` (ADR-021, ADR-023).
struct DSButton: View {
    enum Kind: Equatable {
        case primary
        case secondary
        case destructive
        case blockCTA(DSBlock)
        case blockText(DSBlock)
    }


    private let title: String
    private let kind: Kind
    private let isLoading: Bool
    private let isEnabled: Bool
    private let action: () -> Void

    @Environment(\.isEnabled) private var isEnabledByContainer
    @FocusState private var isFocused: Bool

    init(_ title: String, kind: Kind, isLoading: Bool = false, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.kind = kind
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(role: buttonRole, action: action) {
            label
        }
        .focused($isFocused)
        .buttonStyle(.dsPress)
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled && isEnabledByContainer ? 1 : DSOpacity.disabled)
        .dsFocusRing(isFocused, cornerRadius: cornerRadius, color: focusRingColor)
        .accessibilityLabel(title)
        .accessibilityValue(isLoading ? "In progress" : "")
    }

    // MARK: - Anatomy

    private var label: some View {
        Group {
            if isLoading {
                titleText
                    .hidden()
                    .overlay {
                        // Hidden from VoiceOver: the spinner would leak a raw value of "1" into the
                        // button; the button states "In progress" itself.
                        ProgressView()
                            .tint(labelColor)
                            .accessibilityHidden(true)
                    }
            } else {
                titleText
            }
        }
        .padding(.vertical, DSSpace.s3)
        .padding(.horizontal, DSSpace.s5)
        .frame(minWidth: DSSize.tapMin, minHeight: DSSize.tapMin)
        .background {
            if let fillColor {
                shape.fill(fillColor)
            }
        }
        .contentShape(shape)
    }

    private var titleText: some View {
        Text(title)
            .underline(isTextAction)
            .dsType(textRole)
            .foregroundStyle(labelColor)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    // MARK: - Tokens per kind

    private var buttonRole: ButtonRole? {
        kind == .destructive ? .destructive : nil
    }

    private var isTextAction: Bool {
        if case .blockText = kind { return true }
        return false
    }

    private var textRole: DSTextRole {
        kind == .secondary ? .labelSmall : .label
    }

    private var cornerRadius: CGFloat {
        kind == .secondary ? DSRadius.md : DSRadius.pill
    }

    private var fillColor: Color? {
        switch kind {
        case .primary:             return DSColor.accent
        case .secondary:           return DSColor.surfaceRaised
        case .destructive:         return DSColor.trash.main
        case .blockCTA(let block): return block.ctaFill
        case .blockText:           return nil
        }
    }

    private var labelColor: Color {
        switch kind {
        case .primary:              return DSColor.onAccent
        case .secondary:            return DSColor.ink
        case .destructive:          return DSColor.ink
        case .blockCTA(let block):  return block.ctaLabel
        case .blockText(let block): return block.ink
        }
    }

    private var focusRingColor: Color {
        switch kind {
        case .blockCTA(let block), .blockText(let block): return block.focusRing
        case .primary, .secondary, .destructive:          return DSColor.focus
        }
    }
}
