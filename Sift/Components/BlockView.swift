import SwiftUI

/// A full-bleed color block: UI_DESIGN §9 "Illustration" (typographic faces, color blocks, rules)
/// laid out with the §10 "EmptyState" anatomy. Used by `EmptyState` and by the Permission screens.
///
/// Anatomy, top to bottom, centred: the block's face in `DSTextRole.display` scaled to fill the
/// top `DSSize.blockFaceShare` of the block (decorative, hidden from VoiceOver, P-08), the headline in
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
        GeometryReader { proxy in
            let faceHeight = proxy.size.height * DSSize.blockFaceShare
            ViewThatFits(in: .vertical) {
                content(faceHeight: faceHeight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                ScrollView {
                    content(faceHeight: faceHeight)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(block.fill, ignoresSafeAreaEdges: .all)
    }

    private func content(faceHeight: CGFloat) -> some View {
        VStack(spacing: DSSpace.s7) {
            ScaledFace(text: block.face.text)
                .frame(maxWidth: .infinity)
                .frame(height: faceHeight)
                .accessibilityHidden(true)
            VStack(spacing: DSSpace.s4) {
                Text(headline)
                    .dsType(.headline)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                if let bodyText {
                    Text(bodyText)
                        .dsType(.body)
                        .multilineTextAlignment(.center)
                }
            }
            if Actions.self != EmptyView.self {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: DSSpace.s3) { actions }
                    VStack(spacing: DSSpace.s3) { actions }
                }
            }
        }
        .foregroundStyle(block.ink)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DSGrid.mobileMargin)
        .padding(.vertical, DSSpace.s7)
    }
}

/// The block's face filling its region: set in `DSTextRole.faceFont(size:)` at the region's height,
/// measured, and shrunk (never enlarged) so the whole face fits both the region's width and its
/// height, centred. Rendering large and scaling down keeps the glyph crisp; the size comes from
/// measured geometry, not a literal (P-12, P-13). `Color.clear` is the measuring surface, not a
/// design color.
private struct ScaledFace: View {
    let text: String
    @State private var natural: CGSize = .zero

    var body: some View {
        GeometryReader { region in
            Text(text)
                .font(DSTextRole.faceFont(size: region.size.height))
                .tracking(DSTextRole.faceTracking(size: region.size.height))
                .lineLimit(1)
                .fixedSize()
                .background {
                    GeometryReader { measured in
                        Color.clear
                            .onAppear { natural = measured.size }
                            .onChange(of: measured.size) { _, size in natural = size }
                    }
                }
                .scaleEffect(scale(in: region.size))
                .frame(width: region.size.width, height: region.size.height)
        }
    }

    private func scale(in region: CGSize) -> CGFloat {
        guard natural.width > 0, natural.height > 0, region.width > 0, region.height > 0 else { return 1 }
        return min(1, region.width / natural.width, region.height / natural.height)
    }
}
