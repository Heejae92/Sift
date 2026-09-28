import SwiftUI

/// Library (UI_DESIGN §11.4): the "Library" title, the Favorites / Archive control, and the same grid
/// as Trash with `ThumbnailCell(.library)`. A tap opens the viewer with the Library action set; a long
/// press offers the same two actions. Both are rung 0 (ADR-009): no confirmation.
///
/// An empty segment shows its block below the header, edge to edge and down under the home
/// indicator, and the control above it stays usable: an empty side is not disabled (§10).
///
/// The "Icons" link to Credits (A3) is the footer: after the grid, or on an empty segment the
/// block's bare-text action in its ink, since neither empty block has a filled action of its own.
struct LibraryScreen: View {
    @Environment(Catalog.self) private var catalog
    @Binding private var path: [Route]

    init(path: Binding<[Route]>) {
        _path = path
    }

    var body: some View {
        LibraryContent(model: LibraryModel(catalog: catalog), path: $path)
    }
}

private struct LibraryContent: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model: LibraryModel
    @Binding private var path: [Route]
    /// The screenshot open in the viewer.
    @State private var viewing: Screenshot?
    @FocusState private var focusedCell: String?
    @FocusState private var isCreditsFocused: Bool

    init(model: LibraryModel, path: Binding<[Route]>) {
        _model = State(initialValue: model)
        _path = path
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpace.s4) {
            header
            ZStack {
                if model.items.isEmpty {
                    EmptyState(model.segment == .favorites ? .noFavorites : .noArchived)
                        .safeAreaInset(edge: .bottom) { creditsLinkOnBlock }
                        .transition(.opacity)
                } else {
                    grid
                        .transition(.opacity)
                }
            }
            // The rest of the grid closes up over the cell's fade; under Reduce Motion it does not slide.
            .animation(DSMotion.gated(DSMotion.crossFade, reduce: reduceMotion), value: model.items.map(\.id))
        }
        .background(DSColor.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        // A move lands as its destination's verdict (UI_DESIGN §7, rung 0 of the ladder).
        .dsHaptic(model.moveDestination == .archive ? .archive : .fave, trigger: model.moveCount)
        .dsHaptic(.trash, trigger: model.trashCount)
        .fullScreenCover(item: $viewing) { shot in
            AssetViewer(screenshot: shot, context: .library(
                segment: model.segment,
                onMove: { Task { await model.move(shot.id) } },
                onTrash: { Task { await model.trash(shot.id) } }))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DSSpace.s4) {
            Text("Library")
                .dsType(.title)
                .foregroundStyle(DSColor.ink)
                .accessibilityAddTraits(.isHeader)
            SegmentedControl(selection: $model.segment,
                             favoritesCount: model.favoritesCount,
                             archivedCount: model.archivedCount)
        }
        .padding(.horizontal, DSGrid.mobileMargin)
    }

    private var grid: some View {
        GeometryReader { geometry in
            let side = cellSide(forWidth: geometry.size.width)
            ScrollView {
                VStack(spacing: DSSpace.s5) {
                    LazyVGrid(columns: columns(side: side), spacing: DSSize.thumbnailGutter) {
                        ForEach(model.items) { shot in
                            cell(shot, side: side)
                        }
                    }
                    creditsLink
                }
                .padding(.horizontal, DSGrid.mobileMargin)
                .padding(.bottom, DSSpace.s4)
            }
        }
    }

    private func cell(_ shot: Screenshot, side: CGFloat) -> some View {
        Button {
            viewing = shot
        } label: {
            ThumbnailCell(screenshot: shot, variant: .library, side: side)
        }
        .buttonStyle(.dsPress)
        .focused($focusedCell, equals: shot.id)
        .dsFocusRing(focusedCell == shot.id, cornerRadius: DSRadius.xs)
        .contextMenu {
            Button {
                Task { await model.move(shot.id) }
            } label: {
                Label { Text(model.segment.moveTitle) } icon: { moveIcon.image }
            }
            Button {
                Task { await model.trash(shot.id) }
            } label: {
                Label { Text("Trash") } icon: { DSIcon.trash.image }
            }
        }
        // The menu's actions without a long press (§10 ThumbnailCell).
        .accessibilityAction(named: Text(model.segment.moveTitle)) {
            Task { await model.move(shot.id) }
        }
        .accessibilityAction(named: Text("Trash")) {
            Task { await model.trash(shot.id) }
        }
        // A cell leaves over `DSMotion.fade` (§10 ThumbnailCell), and still cross-fades under Reduce
        // Motion, as Trash's cells do: a fade moves nothing. One at a time here, so no stagger.
        .transition(.opacity.animation(DSMotion.gated(DSMotion.crossFade, reduce: reduceMotion,
                                                      reduced: DSMotion.crossFade)))
    }

    /// The destination's verdict glyph (§8: `archive` and `fave` are the Library move actions).
    private var moveIcon: DSIconRef {
        model.moveDestination == .archive ? DSIcon.archive : DSIcon.fave
    }

    // MARK: - Credits link (A3)

    /// On the white canvas: a quiet text link under the grid.
    private var creditsLink: some View {
        Button {
            path.append(.credits)
        } label: {
            Text("Icons")
                .underline()
                .dsType(.caption)
                .foregroundStyle(DSColor.ink2)
                .frame(minWidth: DSSize.tapMin, minHeight: DSSize.tapMin)
                .contentShape(Rectangle())
        }
        .buttonStyle(.dsPress)
        .focused($isCreditsFocused)
        .dsFocusRing(isCreditsFocused, cornerRadius: DSRadius.pill)
        .accessibilityRemoveTraits(.isButton)
        .accessibilityAddTraits(.isLink)
    }

    /// On an empty segment's block: the block's bare-text action, in the block's ink (§10 Buttons).
    private var creditsLinkOnBlock: some View {
        DSButton("Icons", kind: .blockText(model.segment == .favorites ? .favoritesEmpty : .archiveEmpty)) {
            path.append(.credits)
        }
        .accessibilityRemoveTraits(.isButton)
        .accessibilityAddTraits(.isLink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DSGrid.mobileMargin)
        .padding(.bottom, DSSpace.s4)
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
}
