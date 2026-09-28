import SwiftUI
import UIKit

/// UI_DESIGN §10 "PermissionScreen, SwipeLegend, DemoStack" and §11.1 "Top 55 %": three bundled
/// sample screenshots looping through the three verdicts — card one left with TRASH, card two right
/// with ARCHIVE, card three up with FAVE, then again. The loop is synthetic input fed through the
/// real gesture arithmetic, `SwipeGeometry`, so the demo cannot drift from the product.
///
/// - States (§11.1): `looping` · `interrupted` · `reduced`. Touching the front card stops the loop for
///   good and the card follows the finger: the user can swipe for real, and a committed direction is
///   inserted into `completed`, which checks its `SwipeLegend` row. Under Reduce Motion there is no
///   loop and no gesture: three static panels, each stamped, each with its typeset arrow.
/// - Anatomy: each card is the product's card — `surface` at `DSRadius.xl`, the screenshot fitted
///   (never cropped) inside a `DSSize.cardInset` letterbox, the verdict stamp as §10 "VerdictStamp"
///   draws it — laid out at the product width (the region minus `DSGrid.mobileMargin` each side) and
///   scaled down whole to fit the region, so the miniature keeps the product's proportions. The stack
///   uses `DSSize.stackDepth`, `stackOffsetY`, `stackScaleStep` and `DSShadow.stack` behind the front.
/// - Timing (§11.1): each card takes `DSMotion.demoCard` — a synthetic drag to `DSSwipe.commitDistance`
///   filling what the stamp hold (`DSMotion.stampHoldReduced`) and the flick (`DSMotion.buttonFlick`)
///   leave of it, promoting at `DSSwipe.promoteAt` — then the deck rests `DSMotion.demoPause`.
/// - Accessibility: decorative, `accessibilityHidden`; the legend carries the same facts as text
///   (P-22).
struct DemoStack: View {
    @Binding private var completed: Set<Verdict>
    private let block: DSBlock

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale

    /// Downsampled to the card's pixel size; empty until the first layout has produced one.
    @State private var samples: [UIImage] = []
    /// Front first. A thrown card leaves at the promotion point and re-enters at the back as a new
    /// card (new serial), so it fades in there instead of sliding back across the stack.
    @State private var deck: [Card]
    /// Thrown cards still finishing their exit, drawn above the deck.
    @State private var flying: [Card] = []
    @State private var poses: [Int: Pose] = [:]
    @State private var nextSerial: Int
    /// 0…1: how far the second card has moved toward the front during a drag (UI_DESIGN §6).
    @State private var parallax: CGFloat = 0
    @State private var phase: Phase = .idle
    @State private var loopStopped = false
    @State private var loopStep = 0
    @State private var drag: DragTrack?
    @GestureState private var touching = false

    init(completed: Binding<Set<Verdict>>, on block: DSBlock = .onboarding) {
        _completed = completed
        self.block = block
        let cards = Samples.originals.indices.map { Card(sample: $0, serial: $0) }
        _deck = State(initialValue: cards)
        _nextSerial = State(initialValue: cards.count)
    }

    var body: some View {
        GeometryReader { geo in
            if let design = Samples.designSize(width: geo.size.width - 2 * DSGrid.mobileMargin) {
                let card = cardSize(in: geo.size, design: design)
                Group {
                    if reduceMotion {
                        panels(design: design)
                    } else {
                        stack(card: card, design: design)
                            .task(id: samples.isEmpty) { await runLoop() }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                // Blank cards are not a state worth showing: the demo fades in once the samples decode.
                .opacity(samples.isEmpty ? 0 : 1)
                .animation(DSMotion.gated(DSMotion.crossFade, reduce: reduceMotion), value: samples.isEmpty)
                .task(id: Int(card.width * displayScale)) { await loadSamples(width: card.width * displayScale) }
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Layout

    /// Room left for the cards behind the front one to peek out below it.
    private var stackAllowance: CGFloat {
        CGFloat(DSSize.stackDepth - 1) * DSSize.stackOffsetY
    }

    /// The front card: the product-size card scaled to fit the region, never enlarged.
    private func cardSize(in region: CGSize, design: CGSize) -> CGSize {
        let room = CGSize(width: region.width - 2 * DSGrid.mobileMargin,
                          height: region.height - 2 * DSSpace.s5 - stackAllowance)
        let scale = max(0, min(room.width / design.width, room.height / design.height, 1))
        return CGSize(width: design.width * scale, height: design.height * scale)
    }

    private func stack(card: CGSize, design: CGSize) -> some View {
        let visible = Array(deck.prefix(DSSize.stackDepth))
        // Drawn back to front, flying cards last. A promotion then only inserts a card at the start
        // and never reorders the others, so the stack needs no z-index and nothing re-draws out of order.
        return ZStack {
            ForEach(Array(visible.reversed()) + flying) { item in
                cardView(item, index: visible.firstIndex(of: item), card: card, design: design)
            }
        }
        .frame(width: card.width, height: card.height)
        .padding(.bottom, stackAllowance)
        .onChange(of: touching) { _, isTouching in
            // A touch the system cancelled never reaches `onEnded`; settle whatever it left behind.
            guard !isTouching, drag != nil else { return }
            drag = nil
            if phase == .dragging { settle() }
        }
    }

    /// `index` is the card's place in the deck, or nil while it is flying out.
    private func cardView(_ item: Card, index: Int?, card: CGSize, design: CGSize) -> some View {
        let pose = poses[item.serial] ?? Pose()
        let depth: CGFloat = index.map { $0 == 1 ? 1 - parallax : CGFloat($0) } ?? 0
        return CardView(offset: pose.offset, rotation: pose.rotation, sector: pose.sector,
                        image: sample(item.sample), design: design, size: card, floats: (index ?? 0) == 0)
            .scaleEffect(1 - depth * DSSize.stackScaleStep, anchor: .bottom)
            .offset(y: depth * DSSize.stackOffsetY)
            .transition(.opacity.animation(DSMotion.gated(DSMotion.crossFade, reduce: reduceMotion)))
            .gesture(dragGesture, including: index == 0 ? .all : GestureMask.none)
    }

    /// Reduce Motion (UI_DESIGN §6: interpretive movement goes): three static, stamped panels.
    private func panels(design: CGSize) -> some View {
        HStack(alignment: .top, spacing: DSSpace.s4) {
            ForEach(Array(SwipeLegend.Entry.all.enumerated()), id: \.element.id) { index, entry in
                VStack(spacing: DSSpace.s3) {
                    Miniature(image: sample(index), stamp: entry.verdict, stampOpacity: 1, design: design)
                    Text(entry.arrow)
                        .dsType(.headline)
                        .foregroundStyle(block.ink)
                }
            }
        }
        .padding(.horizontal, DSGrid.mobileMargin)
        .padding(.vertical, DSSpace.s5)
    }

    private func sample(_ index: Int) -> UIImage? {
        samples.indices.contains(index) ? samples[index] : nil
    }

    // MARK: - The loop (synthetic input)

    private func runLoop() async {
        guard !samples.isEmpty else { return }
        let entries = SwipeLegend.Entry.all
        while !Task.isCancelled, !loopStopped, phase == .idle {
            let started = ContinuousClock.now
            await play(entries[loopStep % entries.count])
            loopStep += 1
            try? await Task.sleep(until: started + .seconds(DSMotion.demoCard + DSMotion.demoPause), clock: .continuous)
        }
    }

    /// One synthetic verdict: drag to the commit point, hold the stamp, flick.
    private func play(_ entry: SwipeLegend.Entry) async {
        let axis = Self.sector(for: entry.verdict).axis
        let target = CGSize(width: axis.dx * DSSwipe.commitDistance, height: axis.dy * DSSwipe.commitDistance)
        guard let front = deck.first,
              let sector = SwipeGeometry.sector(dx: target.width, dy: target.height, current: nil) else { return }
        phase = .auto
        let dragDuration = DSMotion.demoCard - DSMotion.stampHoldReduced - DSMotion.buttonFlick
        withAnimation(DSMotion.gated(DSMotion.throwOut(duration: dragDuration), reduce: reduceMotion)) {
            poses[front.serial] = Pose(offset: target, rotation: SwipeGeometry.rotationDegrees(dx: target.width),
                                       sector: sector)
            parallax = min(hypot(target.width, target.height) / DSSwipe.commitDistance, 1)
        }
        try? await Task.sleep(for: .seconds(dragDuration))
        try? await Task.sleep(for: .seconds(DSMotion.stampHoldReduced))
        await throwFront(sector: sector, duration: DSMotion.buttonFlick)
    }

    // MARK: - The gesture (real input)

    private var dragGesture: some Gesture {
        DragGesture(coordinateSpace: .global)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { dragChanged($0) }
            .onEnded { dragEnded($0) }
    }

    private func dragChanged(_ value: DragGesture.Value) {
        loopStopped = true
        // A drag that starts while a synthetic step is still running waits for it to promote, then
        // takes over from wherever the finger is by then instead of jumping the card.
        if drag == nil { drag = DragTrack(base: phase == .idle ? .zero : nil) }
        guard phase == .idle || phase == .dragging, let front = deck.first, var track = drag else { return }
        let base = track.base ?? value.translation
        let dx = value.translation.width - base.width
        let dy = value.translation.height - base.height
        let sector = SwipeGeometry.sector(dx: dx, dy: dy, current: track.sector)
        track.base = base
        track.sector = sector
        drag = track
        phase = .dragging
        let follow = sector == .down ? DSSwipe.downFollow : 1
        let offset = CGSize(width: dx * follow, height: dy * follow)
        poses[front.serial] = Pose(offset: offset, rotation: SwipeGeometry.rotationDegrees(dx: offset.width),
                                   sector: sector)
        parallax = min(hypot(dx, dy) / DSSwipe.commitDistance, 1)
    }

    private func dragEnded(_ value: DragGesture.Value) {
        guard let track = drag else { return }
        drag = nil
        guard phase == .dragging, let front = deck.first else { return }
        let base = track.base ?? value.translation
        let dx = value.translation.width - base.width
        let dy = value.translation.height - base.height
        if let sector = SwipeGeometry.sector(dx: dx, dy: dy, current: track.sector), let verdict = sector.verdict {
            let velocity = SwipeGeometry.velocityAlongAxis(velocity: value.velocity, sector: sector)
            if SwipeGeometry.shouldCommit(distance: hypot(dx, dy), velocityAlongAxis: velocity) {
                phase = .throwing
                poses[front.serial]?.sector = sector
                withAnimation(DSMotion.gated(DSMotion.standard, reduce: reduceMotion)) {
                    _ = completed.insert(verdict)
                }
                Task { await throwFront(sector: sector, duration: DSMotion.exitDuration(velocity: velocity)) }
                return
            }
        }
        settle()
    }

    /// Snap back. The sector is kept so the stamp fades out with the distance on the way home.
    private func settle() {
        phase = .idle
        guard let front = deck.first else { return }
        withAnimation(DSMotion.gated(DSMotion.snapBack, reduce: reduceMotion, reduced: DSMotion.snapBackReduced)) {
            poses[front.serial] = Pose(sector: poses[front.serial]?.sector)
            parallax = 0
        }
    }

    // MARK: - The exit pipeline, shared by the loop and the gesture

    private func throwFront(sector: SwipeSector, duration: Double) async {
        guard let front = deck.first else { return }
        let start = poses[front.serial] ?? Pose(sector: sector)
        withAnimation(DSMotion.gated(DSMotion.throwOut(duration: duration), reduce: reduceMotion)) {
            poses[front.serial] = Self.exitPose(from: start, sector: sector)
        }
        try? await Task.sleep(for: .seconds(duration * Double(DSSwipe.promoteAt)))
        // Promotion: the stack re-lays out, the thrown card re-enters at the back, input reopens.
        withAnimation(DSMotion.gated(DSMotion.stackSettle, reduce: reduceMotion)) {
            deck.removeAll { $0 == front }
            flying.append(front)
            deck.append(Card(sample: front.sample, serial: nextSerial))
            parallax = 0
        }
        nextSerial += 1
        if phase == .auto || phase == .throwing { phase = .idle }
        try? await Task.sleep(for: .seconds(duration * (1 - Double(DSSwipe.promoteAt))))
        flying.removeAll { $0 == front }
        poses[front.serial] = nil
    }

    /// The throw of the guide's deck: sideways verdicts keep their height and turn to
    /// `exitRotationDegrees`; FAVE keeps its sideways drift and leaves upward.
    private static func exitPose(from pose: Pose, sector: SwipeSector) -> Pose {
        var exit = pose
        exit.sector = sector
        switch sector {
        case .trash:
            exit.offset.width = -DSSwipe.exitDistanceX
            exit.rotation = -Double(DSSwipe.exitRotationDegrees)
        case .archive:
            exit.offset.width = DSSwipe.exitDistanceX
            exit.rotation = Double(DSSwipe.exitRotationDegrees)
        case .fave:
            exit.offset.height = -DSSwipe.exitDistanceY
            exit.rotation = SwipeGeometry.rotationDegrees(dx: pose.offset.width)
        case .down:
            break
        }
        return exit
    }

    private static func sector(for verdict: Verdict) -> SwipeSector {
        switch verdict {
        case .trash: return .trash
        case .archive: return .archive
        case .fave: return .fave
        }
    }

    // MARK: - Samples

    private func loadSamples(width: CGFloat) async {
        guard width > 0 else { return }
        var loaded: [UIImage] = []
        for original in Samples.originals {
            // Index-aligned with `deck`: an image that cannot be sized is kept as it is.
            guard original.size.width > 0 else { loaded.append(original); continue }
            let size = CGSize(width: width, height: width * original.size.height / original.size.width)
            loaded.append(await original.byPreparingThumbnail(ofSize: size) ?? original)
        }
        guard !Task.isCancelled else { return }
        samples = loaded
    }
}

// MARK: - Parts

extension DemoStack {
    private enum Phase {
        /// Front card at rest; the loop or a finger may take it.
        case idle
        /// A synthetic step is running up to its promotion point.
        case auto
        case dragging
        /// A real throw is running up to its promotion point.
        case throwing
    }

    private struct DragTrack {
        /// Translation at which this drag took the card; nil while it waits for a synthetic step.
        var base: CGSize?
        var sector: SwipeSector?
    }

    private struct Card: Identifiable, Equatable {
        let sample: Int
        let serial: Int
        var id: Int { serial }
    }

    private struct Pose: Equatable {
        var offset: CGSize = .zero
        var rotation: Double = 0
        var sector: SwipeSector?
    }

    /// Three of the six bundled sample screenshots (real iOS screens captured on a simulator), one
    /// per verdict in loop order.
    private enum Samples {
        static let names = ["sample-1", "sample-2", "sample-3"]

        /// Read once from the bundle. PNG data decodes lazily; only downsampled copies are drawn.
        static let originals: [UIImage] = names.compactMap { name in
            guard let url = Bundle.main.url(forResource: name, withExtension: "png") else { return nil }
            return UIImage(contentsOfFile: url.path)
        }

        /// The product card at `width`: the screenshot fitted inside a `DSSize.cardInset` letterbox.
        static func designSize(width: CGFloat) -> CGSize? {
            guard let first = originals.first, first.size.width > 0, width > 2 * DSSize.cardInset else { return nil }
            let inner = width - 2 * DSSize.cardInset
            return CGSize(width: width, height: inner * first.size.height / first.size.width + 2 * DSSize.cardInset)
        }
    }

    /// A deck card in motion. `offset` and `rotation` animate frame by frame, so the stamp's opacity
    /// and the upward lift are recomputed from the live distance by `SwipeGeometry`, exactly as
    /// under a finger, rather than interpolated between two end states.
    private struct CardView: View, Animatable {
        var offset: CGSize
        var rotation: Double
        let sector: SwipeSector?
        let image: UIImage?
        let design: CGSize
        let size: CGSize
        let floats: Bool

        nonisolated var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, Double> {
            get { AnimatablePair(AnimatablePair(offset.width, offset.height), rotation) }
            set {
                offset = CGSize(width: newValue.first.first, height: newValue.first.second)
                rotation = newValue.second
            }
        }

        var body: some View {
            let distance = hypot(offset.width, offset.height)
            Miniature(image: image, stamp: sector?.verdict,
                      stampOpacity: SwipeGeometry.stampOpacity(distance: distance), design: design)
                .frame(width: size.width, height: size.height)
                .background { shadows }
                .scaleEffect(sector == .fave ? SwipeGeometry.upScale(distance: distance) : 1)
                .rotationEffect(.degrees(rotation), anchor: .bottom)
                .offset(offset)
        }

        /// `DSShadow.floating` in front, `DSShadow.stack` behind (§10 ScreenshotCard). Both are always
        /// present and swap by opacity: `dsShadow` switches on its level, and switching it on a live
        /// card would rebuild the card mid-promotion and cross-fade it with itself.
        private var shadows: some View {
            let shape = RoundedRectangle(cornerRadius: DSRadius.xl * size.width / design.width, style: .continuous)
            return ZStack {
                shape.fill(DSColor.surface).dsShadow(.stack).opacity(floats ? 0 : 1)
                shape.fill(DSColor.surface).dsShadow(.floating).opacity(floats ? 1 : 0)
            }
        }
    }

    /// The product card drawn at `design` size and shrunk, whole, to the frame it is given.
    private struct Miniature: View {
        let image: UIImage?
        let stamp: Verdict?
        let stampOpacity: Double
        let design: CGSize

        var body: some View {
            GeometryReader { geo in
                face
                    .frame(width: design.width, height: design.height)
                    .scaleEffect(min(geo.size.width / design.width, geo.size.height / design.height))
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .aspectRatio(design, contentMode: .fit)
        }

        private var face: some View {
            ZStack {
                RoundedRectangle(cornerRadius: DSRadius.xl, style: .continuous)
                    .fill(DSColor.surface)
                if let image {
                    // Nested radius = outer − gap, clamped up to the smallest step (P-10).
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: max(DSRadius.xl - DSSize.cardInset, DSRadius.xs),
                                                    style: .continuous))
                        .padding(DSSize.cardInset)
                }
            }
            .overlay(alignment: Stamp.alignment(stamp)) {
                if let stamp {
                    Stamp(verdict: stamp)
                        .offset(y: stamp == .fave ? -DSSize.stampFaveRaise * design.height : 0)
                        .opacity(stampOpacity)
                }
            }
        }
    }

    /// §10 "VerdictStamp": a solid `main` pill with the `on` glyph and word, inset `DSSpace.s5`: TRASH
    /// top-right at +`DSSwipe.stampTiltDegrees`, ARCHIVE top-left at the negative, FAVE upright and
    /// raised `DSSize.stampFaveRaise` of the card height above the centre (applied by `Miniature`).
    /// The word is the fixed 32 pt `stamp` role: the miniature keeps the product's proportions.
    private struct Stamp: View {
        let verdict: Verdict

        var body: some View {
            let entry = SwipeLegend.Entry.of(verdict)
            let colors = Self.colors(verdict)
            HStack(spacing: DSSpace.s2) {
                entry.icon.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: DSSize.stampIcon, height: DSSize.stampIcon)
                Text(entry.word)
                    .dsType(.stamp)
            }
            .fixedSize()
            .foregroundStyle(colors.on)
            .padding(.vertical, DSSpace.s2)
            .padding(.horizontal, DSSpace.s4)
            .background(colors.main, in: RoundedRectangle(cornerRadius: DSRadius.pill, style: .continuous))
            .dsShadow(.floating)
            .rotationEffect(.degrees(Self.tilt(verdict)))
            .padding(DSSpace.s5)
        }

        static func alignment(_ verdict: Verdict?) -> Alignment {
            switch verdict {
            case .trash: return .topTrailing
            case .archive: return .topLeading
            case .fave, nil: return .center
            }
        }

        private static func tilt(_ verdict: Verdict) -> Double {
            switch verdict {
            case .trash: return Double(DSSwipe.stampTiltDegrees)
            case .archive: return -Double(DSSwipe.stampTiltDegrees)
            case .fave: return 0
            }
        }

        private static func colors(_ verdict: Verdict) -> VerdictColorSet {
            switch verdict {
            case .trash: return DSColor.trash
            case .archive: return DSColor.archive
            case .fave: return DSColor.fave
            }
        }
    }
}
