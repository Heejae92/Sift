import SwiftUI

/// Trash, the holding pen (UI_DESIGN §11.3): the count and the size in the header, a grid of
/// `ThumbnailCell(.trash)` with the most recently trashed first, and the docked
/// "Delete all permanently". One item or all of them; there is no multi-select (ADR-015).
///
/// The two purge rungs (ADR-009):
/// - One item has no in-app confirmation; the iOS dialog is the one. From the grid's menu it starts
///   at once. From the viewer it waits for the viewer to close, so the dialog and its outcome land
///   on this grid (IA §2, X3).
/// - All items go through `PurgeAllSheet`. Confirming only marks the purge pending and dismisses
///   the sheet; the sheet's `onDismiss` then calls `purgeAll()`, which fires `DSHaptic.purgeArmed`
///   and presents the iOS dialog. The sheet is fully gone first, so two confirmations never stack.
///
/// Removal: a cell fades over `DSMotion.fade`. When the whole trash goes at once, each cell starts
/// `DSMotion.stagger` after the one before it, most recent first, and the block waits for the last
/// one; under Reduce Motion they cross-fade together, since a fade moves nothing. In between, the
/// docked button shows its disabled state ("disabled when empty").
///
/// Empty, the screen is the mint `trashEmpty` block alone. The docked button is not drawn over it: a
/// block carries exactly one filled action, its own "Back to sifting" (P-19, ADR-023).
struct TrashScreen: View {
    @Environment(Catalog.self) private var catalog

    init() {}

    var body: some View {
        TrashContent(model: TrashModel(catalog: catalog))
    }
}

private struct TrashContent: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var inlineIcon = DSSize.iconInline

    @State private var model: TrashModel
    /// The screenshot open in the viewer.
    @State private var viewing: Screenshot?
    /// "Delete" tapped in the viewer: purged once the viewer has closed.
    @State private var viewerPurgeID: String?
    @State private var isPurgeSheetPresented = false
    /// From "Delete N permanently" until Photos answers: `purgeAll()` waits for the sheet to close,
    /// the dock shows pending, and any cells that go, go in a stagger.
    @State private var isPurgingAll = false
    /// Lags `model.items.isEmpty` by the removal fade, so the block appears after the last cell.
    @State private var isShowingEmptyState: Bool
    @FocusState private var focusedCell: String?
    @AccessibilityFocusState private var isDockFocused: Bool

    init(model: TrashModel) {
        _model = State(initialValue: model)
        _isShowingEmptyState = State(initialValue: model.items.isEmpty)
    }

    var body: some View {
        ZStack {
            if isShowingEmptyState {
                EmptyState(.trashEmpty, primaryAction: { dismiss() })
                    .transition(.opacity)
            } else {
                populated
                    .transition(.opacity)
            }
        }
        // The rest of the grid closes up over the same fade; under Reduce Motion it does not slide.
        .animation(DSMotion.gated(DSMotion.crossFade, reduce: reduceMotion), value: model.items.map(\.id))
        .onChange(of: model.items.count) { old, new in
            if new > 0 {
                isShowingEmptyState = false
            } else if old > 0 {
                revealEmptyState(afterCells: old)
            }
        }
        .background(DSColor.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .dsToast($model.toast)
        .dsHaptic(.purgeArmed, trigger: model.purgeArmedCount)
        .dsHaptic(.purgeDone, trigger: model.purgeDoneCount)
        .dsHaptic(.restore, trigger: model.restoreCount)
        .dsHaptic(.error, trigger: model.errorCount)
        .onChange(of: model.inlineError) { _, message in
            if let message { AccessibilityNotification.Announcement(message).post() }
        }
        .task(id: model.items.map(\.id)) { await model.loadSizes() }
        .fullScreenCover(item: $viewing, onDismiss: purgeAfterViewer) { shot in
            AssetViewer(screenshot: shot, context: .trash(
                onRestore: { model.restore(shot.id) },
                onDelete: { viewerPurgeID = shot.id }))
        }
        .sheet(isPresented: $isPurgeSheetPresented, onDismiss: purgeAfterSheet) {
            PurgeAllSheet(count: model.items.count,
                          onConfirm: {
                              isPurgingAll = true
                              isPurgeSheetPresented = false
                          },
                          onKeep: { isPurgeSheetPresented = false })
        }
    }

    // MARK: - Populated

    private var populated: some View {
        VStack(alignment: .leading, spacing: DSSpace.s4) {
            header
            grid
        }
        .safeAreaInset(edge: .bottom) { dock }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DSSpace.s2) {
            Text(model.headerText)
                .dsType(.title)
                .foregroundStyle(DSColor.ink)
                .accessibilityAddTraits(.isHeader)
            if let message = model.inlineError {
                // An error is navy text with the warning glyph, never a red line (P-06, ADR-005).
                HStack(spacing: DSSpace.s1) {
                    DSIcon.warning.image
                        .resizable()
                        .scaledToFit()
                        .frame(width: inlineIcon, height: inlineIcon)
                        .accessibilityHidden(true)
                    Text(message)
                        .dsType(.body)
                }
                .foregroundStyle(DSColor.ink2)
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DSGrid.mobileMargin)
    }

    private var grid: some View {
        GeometryReader { geometry in
            let side = cellSide(forWidth: geometry.size.width)
            ScrollView {
                LazyVGrid(columns: columns(side: side), spacing: DSSize.thumbnailGutter) {
                    ForEach(Array(model.items.enumerated()), id: \.element.id) { index, shot in
                        cell(shot, index: index, side: side)
                    }
                }
                .padding(.horizontal, DSGrid.mobileMargin)
            }
        }
    }

    private func cell(_ shot: Screenshot, index: Int, side: CGFloat) -> some View {
        Button {
            viewing = shot
        } label: {
            ThumbnailCell(screenshot: shot, variant: .trash, side: side)
        }
        .buttonStyle(.dsPress)
        .focused($focusedCell, equals: shot.id)
        .dsFocusRing(focusedCell == shot.id, cornerRadius: DSRadius.xs)
        .contextMenu {
            Button {
                model.restore(shot.id)
            } label: {
                Label { Text("Restore") } icon: { DSIcon.restore.image }
            }
            // No destructive role: it would paint the item system red, and the app has no red (P-06).
            // "Permanently" carries it.
            Button {
                Task { await model.purgeOne(shot.id) }
            } label: {
                Label { Text("Delete") } icon: { DSIcon.trash.image }
            }
        }
        // The menu's actions without a long press (§10 ThumbnailCell).
        .accessibilityAction(named: Text("Restore")) { model.restore(shot.id) }
        .accessibilityAction(named: Text("Delete")) {
            Task { await model.purgeOne(shot.id) }
        }
        .transition(.opacity.animation(removal(at: index)))
    }

    /// Set on the cell before it goes, because SwiftUI takes a removal transition from the last
    /// render: the stagger applies only while everything is being purged.
    private func removal(at index: Int) -> Animation? {
        let delay = isPurgingAll ? Double(index) * DSMotion.stagger : .zero
        return DSMotion.gated(DSMotion.crossFade.delay(delay), reduce: reduceMotion, reduced: DSMotion.crossFade)
    }

    /// The block cross-fades in once the last cell has finished: its stagger step plus the fade.
    private func revealEmptyState(afterCells count: Int) {
        let lastStart = reduceMotion ? .zero : Double(count - 1) * DSMotion.stagger
        Task {
            try? await Task.sleep(for: .seconds(lastStart + DSMotion.fade))
            guard model.items.isEmpty else { return }
            withAnimation(DSMotion.gated(DSMotion.crossFade, reduce: reduceMotion, reduced: DSMotion.crossFade)) {
                isShowingEmptyState = true
            }
        }
    }

    /// Docked over the grid, so it takes `DSShadow.floating` (§10 Buttons). Pending from the moment
    /// the sheet is confirmed until Photos answers.
    private var dock: some View {
        DSButton(model.purgeButtonTitle,
                 kind: .destructive,
                 isLoading: isPurgingAll || model.isPurging,
                 isEnabled: !model.items.isEmpty,
                 isFullWidth: true) {
            isPurgeSheetPresented = true
        }
        .dsShadow(.floating)
        .accessibilityFocused($isDockFocused)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DSGrid.mobileMargin)
        .padding(.vertical, DSSpace.s4)
    }

    // MARK: - Grid geometry

    /// `DSSize.gridColumns` square cells with `DSSize.thumbnailGutter` between them, inside the margins.
    private func cellSide(forWidth width: CGFloat) -> CGFloat {
        let count = CGFloat(DSSize.gridColumns)
        let content = width - 2 * DSGrid.mobileMargin - (count - 1) * DSSize.thumbnailGutter
        return max(content / count, 0)
    }

    private func columns(side: CGFloat) -> [GridItem] {
        Array(repeating: GridItem(.fixed(side), spacing: DSSize.thumbnailGutter), count: DSSize.gridColumns)
    }

    // MARK: - Purge ordering (ADR-009)

    /// Rung 1 from the viewer, once the viewer has closed.
    private func purgeAfterViewer() {
        guard let id = viewerPurgeID else { return }
        viewerPurgeID = nil
        Task { await model.purgeOne(id) }
    }

    /// Rung 2, once the sheet has fully closed. Focus goes back to the docked button either way
    /// (UI_DESIGN §13).
    private func purgeAfterSheet() {
        isDockFocused = true
        guard isPurgingAll else { return }
        Task {
            await model.purgeAll()
            isPurgingAll = false
        }
    }
}
