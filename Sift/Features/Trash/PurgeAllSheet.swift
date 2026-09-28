import SwiftUI

/// UI_DESIGN §10 "PurgeAllSheet", rung 2 of ADR-009. It names the count and pre-announces the iOS
/// dialog; it does not replace it. The size stays on the docked button that opens it (§11.3).
///
/// Confirming only reports back. The presenter dismisses the sheet and starts the deletion from
/// the sheet's `onDismiss`, so `DSHaptic.purgeArmed` and the iOS dialog both come after the sheet
/// is gone and two confirmations never stack.
///
/// One state. §10 also lists `pending` and `error`, but both happen while the iOS dialog is up, and
/// by then the sheet has already closed: pending shows in the docked button, the error as the
/// inline line under the Trash header.
struct PurgeAllSheet: View {
    private let count: Int
    private let onConfirm: () -> Void
    private let onKeep: () -> Void

    /// The content's own height, so the sheet's one detent fits it.
    @State private var contentHeight: CGFloat?
    @AccessibilityFocusState private var isTitleFocused: Bool

    init(count: Int, onConfirm: @escaping () -> Void, onKeep: @escaping () -> Void) {
        self.count = count
        self.onConfirm = onConfirm
        self.onKeep = onKeep
    }

    var body: some View {
        ScrollView {
            content
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents(detents)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(DSRadius.xl)
        .presentationBackground(DSColor.surface)
        .onAppear { isTitleFocused = true }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: DSSpace.s4) {
            Text(title)
                .dsType(.subhead)
                .foregroundStyle(DSColor.ink)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($isTitleFocused)
            Text(message)
                .dsType(.body)
                .foregroundStyle(DSColor.ink2)
            VStack(alignment: .leading, spacing: DSSpace.s3) {
                DSButton("Delete \(count) permanently", kind: .destructive, isFullWidth: true, action: onConfirm)
                DSButton("Keep them", kind: .secondary, isFullWidth: true, action: onKeep)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpace.s5)
    }

    /// Fitted to the content once it has been measured. Content taller than the screen scrolls.
    private var detents: Set<PresentationDetent> {
        guard let contentHeight else { return [.medium] }
        return [.height(contentHeight)]
    }

    private var title: String {
        count == 1 ? "Delete 1 screenshot permanently?" : "Delete \(count) screenshots permanently?"
    }

    /// Pre-announces the second dialog so the double confirmation reads as designed (ADR-009), and
    /// does not promise "gone": Photos keeps them in Recently Deleted for 30 days (§12).
    private var message: String {
        let subject = count == 1 ? "It leaves" : "They leave"
        let verb = count == 1 ? "goes" : "go"
        return "\(subject) \(Brand.name) for good and \(verb) to Photos' Recently Deleted for 30 days. iOS will double-check — that's expected."
    }
}
