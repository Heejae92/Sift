import SwiftUI

/// A full-bleed color block: UI_DESIGN §9 "Illustration" (typographic faces, color blocks, rules)
/// laid out with the §10 "EmptyState" anatomy. Used by `EmptyState` and by the Permission screens.
///
/// Anatomy, top to bottom, leading-aligned and vertically centred: the block's face in
/// `DSTextRole.display` (decorative, hidden from VoiceOver, P-08), the headline in
/// `DSTextRole.headline` (the first VoiceOver element, with the header trait), an optional body in
/// `DSTextRole.body`, then the actions. All copy is `block.ink`; the fill runs under the safe areas,
/// because a block is full-bleed or it does not exist. At sizes where the content no longer fits,
/// it scrolls instead of truncating (P-20).
///
/// **A block carries exactly ONE filled action (P-19, ADR-023).** Pass one
/// `DSButton(_:kind: .blockCTA(block))` and at most one `DSButton(_:kind: .blockText(block))` in
/// `actions` — never a `.primary`, `.secondary` or `.destructive` button. A second pill would be a
/// shape owing 3:1 against the block, and `surfaceRaised` measures 2.16 against `lavender`; bare text
/// in the block's ink owes only the copy row the block already clears. The actions sit in one row
/// and stack when the row does not fit. Nothing here enforces the rule beyond this comment.
struct BlockView<Actions: View>: View {
    private let block: DSBlock
    private let headline: String
    private let bodyText: String?
    private let actions: Actions

    init(_ block: DSBlock, headline: String, body: String? = nil, @ViewBuilder actions: () -> Actions) {
        self.block = block
        self.headline = headline
        self.bodyText = body
        self.actions = actions()
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
                .frame(maxHeight: .infinity)
            ScrollView {
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(block.fill, ignoresSafeAreaEdges: .all)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: DSSpace.s7) {
            VStack(alignment: .leading, spacing: DSSpace.s5) {
                Text(block.face.text)
                    .dsType(.display)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DSSpace.s4) {
                    Text(headline)
                        .dsType(.headline)
                        .accessibilityAddTraits(.isHeader)
                    if let bodyText {
                        Text(bodyText)
                            .dsType(.body)
                    }
                }
            }
            if Actions.self != EmptyView.self {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: DSSpace.s3) { actions }
                    VStack(alignment: .leading, spacing: DSSpace.s3) { actions }
                }
            }
        }
        .foregroundStyle(block.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DSGrid.mobileMargin)
        .padding(.vertical, DSSpace.s7)
    }
}
