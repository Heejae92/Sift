import SwiftUI

/// UI_DESIGN §10 "AssetViewer": the one place the canvas goes black (P-07). The screenshot is fitted
/// between a top bar (close, date chip) and a bottom bar carrying the presenting screen's action set,
/// so no bar ever covers part of it (P-01). Pinch zooms, a double tap returns to fit, and a drag
/// down past `DSSwipe.commitDistance`, or a flick past `DSSwipe.commitVelocity`, closes it.
///
/// Every action calls the presenter and then closes the viewer, because each one takes the
/// screenshot out of the grid it was opened from. All of them are rung 0 of ADR-009 except
/// "Delete permanently", whose presenter waits for the viewer to close before the iOS dialog.
///
/// Double tap only zooms back OUT. §10 asks for a 2× zoom in and pinch needs a ceiling, and neither
/// factor is a token yet, so neither is typed here (P-12). Pinch is floored at fit and has no ceiling.
struct AssetViewer: View {
    enum Context {
        /// From Trash: Restore and Delete permanently.
        case trash(onRestore: () -> Void, onDelete: () -> Void)
        /// From Library: Move to Archive / Move to Favorites, and Trash.
        case library(segment: LibrarySegment, onMove: () -> Void, onTrash: () -> Void)
    }

    /// States of §10: `loading` · `presented` · `zoomed` · `dismissing`. Zoomed and dismissing are
    /// gesture state on top of `loaded`; an asset Photos cannot deliver is `failed`.
    private enum Phase {
        case loading
        case loaded(UIImage)
        case failed
    }

    /// P-07: pure black appears in exactly one place, this backdrop.
    private static let backdrop = DSColor.viewerBackdrop

    private let screenshot: Screenshot
    private let context: Context

    @Environment(ImageLoader.self) private var images
    @Environment(Catalog.self) private var catalog
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var phase: Phase = .loading
    @State private var bytes: Int64?
    /// Committed zoom; 1 is fit.
    @State private var zoom: CGFloat = 1
    /// Live pinch factor, on top of `zoom` while two fingers are down.
    @State private var pinch: CGFloat = 1
    /// Committed pan of a zoomed image.
    @State private var pan: CGSize = .zero
    /// Live drag: a pan while zoomed, the dismiss drag at fit.
    @State private var drag: CGSize = .zero
    /// The current gesture has pinched, so its drag is a pan and never a dismiss.
    @State private var didPinch = false
    @FocusState private var isCloseFocused: Bool

    init(screenshot: Screenshot, context: Context) {
        self.screenshot = screenshot
        self.context = context
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .zIndex(DSLayer.sticky)
            stage
            bottomBar
                .zIndex(DSLayer.sticky)
        }
        .background {
            Self.backdrop
                .opacity(chromeOpacity)
                .ignoresSafeArea()
        }
        .presentationBackground(.clear)
        .statusBarHidden()
        .accessibilityAction(.escape) { dismiss() }
        .task { bytes = await catalog.fileSizeBytes(for: screenshot.id) }
    }

    // MARK: - Bars

    private var topBar: some View {
        HStack(spacing: DSSpace.s3) {
            closeButton
            chip
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DSGrid.mobileMargin)
        .padding(.vertical, DSSpace.s2)
        .background(Self.backdrop, ignoresSafeAreaEdges: .top)
        .opacity(chromeOpacity)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            DSIcon.close.image
                .resizable()
                .scaledToFit()
                .frame(width: DSSize.iconChrome, height: DSSize.iconChrome)
                .frame(width: DSSize.tapMin, height: DSSize.tapMin)
                .contentShape(Rectangle())
        }
        .buttonStyle(.dsPress)
        .foregroundStyle(DSColor.onImage)
        .focused($isCloseFocused)
        // On black the ring is `onImage` at full strength: the same pair as the bar's own text
        // (`onImage` on black, 21:1), the way `DSBlock.focusRing` is the block's ink (ADR-023).
        .dsFocusRing(isCloseFocused, cornerRadius: DSRadius.pill, color: DSColor.onImage)
        .accessibilityLabel("Close")
    }

    /// "Sep 21 · 2:14 PM · 1.2 MB" on `chip`, solid `surface` under Reduce Transparency (§13). Hidden
    /// from VoiceOver because the image element carries the same facts (P-22).
    private var chip: some View {
        Text(chipText)
            .dsType(.caption)
            .foregroundStyle(DSColor.ink)
            .padding(.vertical, DSSpace.s1)
            .padding(.horizontal, DSSpace.s2)
            .background(reduceTransparency ? DSColor.surface : DSColor.chip,
                        in: RoundedRectangle(cornerRadius: DSRadius.xs, style: .continuous))
            .accessibilityHidden(true)
    }

    private var bottomBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DSSpace.s3) { actions }
            VStack(spacing: DSSpace.s3) { actions }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DSGrid.mobileMargin)
        .padding(.vertical, DSSpace.s4)
        .background(Self.backdrop, ignoresSafeAreaEdges: .bottom)
        .opacity(chromeOpacity)
    }

    @ViewBuilder
    private var actions: some View {
        switch context {
        case .trash(let onRestore, let onDelete):
            DSButton("Restore", kind: .secondary) { run(onRestore) }
            DSButton("Delete permanently", kind: .destructive) { run(onDelete) }
        case .library(let segment, let onMove, let onTrash):
            DSButton(segment.moveTitle, kind: .secondary) { run(onMove) }
            DSButton("Trash", kind: .secondary) { run(onTrash) }  // reversible (rung 0), so not destructive (§12)
        }
    }

    private func run(_ action: () -> Void) {
        action()
        dismiss()
    }

    // MARK: - Stage

    private var stage: some View {
        GeometryReader { geometry in
            let area = geometry.size
            picture(in: area)
                .frame(width: area.width, height: area.height)
                .contentShape(Rectangle())
                .gesture(zoomAndDrag(in: area))
                .onTapGesture(count: 2) { location in toggleZoom(at: location, in: area) }
                .task(id: area) { await load(in: area) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isImage)
    }

    @ViewBuilder
    private func picture(in area: CGSize) -> some View {
        switch phase {
        case .loading:
            ProgressView()
                .tint(DSColor.onImage)
        case .failed:
            DSIcon.warning.image
                .resizable()
                .scaledToFit()
                .frame(width: DSSize.iconChrome, height: DSSize.iconChrome)
                .foregroundStyle(DSColor.onImage)
        case .loaded(let image):
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: area.width, height: area.height)
                .scaleEffect(zoom * pinch)
                .offset(offset(in: area))
        }
    }

    /// The asset fitted at the stage's pixel size. A reload after a size change keeps the old image
    /// up until the new one arrives.
    private func load(in area: CGSize) async {
        guard area.width > 0, area.height > 0 else { return }
        let pixels = CGSize(width: area.width * displayScale, height: area.height * displayScale)
        let image = await images.image(for: screenshot.id, targetSize: pixels)
        guard !Task.isCancelled else { return }
        if let image {
            phase = .loaded(image)
        } else if case .loading = phase {
            phase = .failed
        }
    }

    // MARK: - Gestures

    private var isZoomed: Bool { zoom * pinch > 1 || didPinch }

    /// 0 at rest, 1 at `DSSwipe.commitDistance` down. Only the dismiss drag at fit counts.
    private var dismissProgress: CGFloat {
        guard !isZoomed else { return 0 }
        return min(max(drag.height, 0) / DSSwipe.commitDistance, 1)
    }

    /// The backdrop and both bars fade as the dismiss drag travels, so what is underneath shows.
    private var chromeOpacity: Double { 1 - dismissProgress }

    /// The committed pan plus the live drag.
    private var panned: CGSize {
        CGSize(width: pan.width + drag.width, height: pan.height + drag.height)
    }

    private func offset(in area: CGSize) -> CGSize {
        guard isZoomed else { return drag }
        return clamped(panned, scale: zoom * pinch, in: area)
    }

    private func zoomAndDrag(in area: CGSize) -> some Gesture {
        MagnifyGesture()
            .simultaneously(with: DragGesture())
            .onChanged { value in
                if let magnify = value.first {
                    pinch = magnify.magnification
                    didPinch = true
                }
                if let move = value.second {
                    drag = move.translation
                }
            }
            .onEnded { value in
                if isZoomed {
                    settleZoom(in: area)
                } else if let move = value.second, commitsDismiss(move) {
                    dismiss()
                } else {
                    // An uncommitted drag returns like the card does (UI_DESIGN §6 Reduce Motion table).
                    withAnimation(DSMotion.gated(DSMotion.snapBack, reduce: reduceMotion,
                                                 reduced: DSMotion.snapBackReduced)) {
                        drag = .zero
                    }
                }
                didPinch = false
            }
    }

    /// The commit rule of the card (ADR-019), read downward: distance, or velocity with a travel floor.
    private func commitsDismiss(_ move: DragGesture.Value) -> Bool {
        let travel = move.translation.height
        return travel >= DSSwipe.commitDistance
            || (move.velocity.height >= DSSwipe.commitVelocity && travel >= DSSwipe.minTravelForVelocity)
    }

    /// Commit the pinch and the pan in one animated step, so nothing jumps: below fit returns to fit,
    /// a zoomed image keeps its edges on the stage's edges.
    private func settleZoom(in area: CGSize) {
        withAnimation(DSMotion.gated(DSMotion.enter, reduce: reduceMotion)) {
            let settled = min(max(zoom * pinch, 1), DSSize.viewerZoomMax)
            pan = settled > 1 ? clamped(panned, scale: settled, in: area) : .zero
            zoom = settled
            pinch = 1
            drag = .zero
        }
    }

    /// Double-tap: to `DSSize.viewerZoomDoubleTap` about the tapped point, or back to fit.
    private func toggleZoom(at location: CGPoint, in area: CGSize) {
        withAnimation(DSMotion.gated(DSMotion.enter, reduce: reduceMotion)) {
            if zoom > 1 {
                zoom = 1
                pan = .zero
            } else {
                let target = DSSize.viewerZoomDoubleTap
                // Scaling about the centre moves the tapped point to c + (p − c)·s; this offset puts it back.
                let toward = CGSize(width: (area.width / 2 - location.x) * (target - 1),
                                    height: (area.height / 2 - location.y) * (target - 1))
                zoom = target
                pan = clamped(toward, scale: target, in: area)
            }
        }
    }

    /// A zoomed image may slide until one of its edges meets the stage's edge, never past it.
    private func clamped(_ offset: CGSize, scale: CGFloat, in area: CGSize) -> CGSize {
        let fitted = fittedSize(in: area)
        let limitX = max((fitted.width * scale - area.width) / 2, 0)
        let limitY = max((fitted.height * scale - area.height) / 2, 0)
        return CGSize(width: min(max(offset.width, -limitX), limitX),
                      height: min(max(offset.height, -limitY), limitY))
    }

    private func fittedSize(in area: CGSize) -> CGSize {
        let pixels = screenshot.pixelSize
        guard pixels.width > 0, pixels.height > 0 else { return area }
        let ratio = min(area.width / pixels.width, area.height / pixels.height)
        return CGSize(width: pixels.width * ratio, height: pixels.height * ratio)
    }

    // MARK: - Copy

    private var day: String { screenshot.creationDate.formatted(.dateTime.month(.abbreviated).day()) }
    private var time: String { screenshot.creationDate.formatted(date: .omitted, time: .shortened) }
    private var sizeText: String? {
        bytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }
    }

    /// "Sep 21 · 2:14 PM · 1.2 MB" (UI_DESIGN §12); the size joins once Photos reports it.
    private var chipText: String {
        ([day, time] + [sizeText].compactMap { $0 }).joined(separator: " · ")
    }

    /// "Screenshot, Sep 21, 2:14 PM, 1.2 MB": the card's label without the queue position (§13).
    private var accessibilityText: String {
        (["Screenshot", day, time] + [sizeText].compactMap { $0 }).joined(separator: ", ")
    }
}

extension LibrarySegment {
    /// The Library action set's move names its destination (UI_DESIGN §11.4).
    var moveTitle: String {
        self == .favorites ? "Move to Archive" : "Move to Favorites"
    }
}
