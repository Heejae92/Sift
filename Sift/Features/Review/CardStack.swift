import SwiftUI
import Photos

/// Transform and opacity of one card. `CardStack` applies it outside `ScreenshotCard`, so a drag frame
/// changes transforms and nothing else (UI_DESIGN §6: transform and opacity only, never layout).
struct CardPose: Equatable {
    var offset: CGSize = .zero
    /// Degrees, anchored at the card's bottom edge, so it pivots like a paper card on a table.
    var rotation: Double = .zero
    var scale: CGFloat = 1
    var opacity: Double = 1

    static let rest = CardPose()
}

/// The stamp a card is showing: which verdict, how strongly.
struct CardStamp: Equatable {
    let verdict: Verdict
    var opacity: Double
}

/// Where each card is drawn while the deck changes: the finger, the throw, the landing.
/// `ReviewModel` (IA §5) decides what the deck *is*; this decides how it moves in between.
///
/// One instance is shared by `CardStack` (the gesture), `VerdictButtonRow` and the VoiceOver actions
/// (the synthesized flick) and `RewindButton`. A verdict therefore takes one path however it is given
/// (§10): stamp to full, card out, `ReviewModel.commit(_:exitDuration:)`.
@MainActor
@Observable
final class DeckMotion {
    /// The front card under the finger.
    struct Drag: Equatable {
        let id: String
        var translation: CGSize = .zero
        var sector: SwipeSector?
        /// Set on the first rising edge of the commit rule, so `DSHaptic.thresholdArmed` fires once
        /// per drag, not on every frame past the threshold (§7).
        var hasArmed = false

        var distance: CGFloat { hypot(translation.width, translation.height) }

        /// How far the second card has come toward the front card's values (§6 Stack geometry).
        var progress: CGFloat { min(distance / DSSwipe.commitDistance, 1) }

        /// Only the active sector's stamp shows, ramped by `SwipeGeometry.stampOpacity(distance:)`.
        var stamp: CardStamp? {
            guard let verdict = sector?.verdict else { return nil }
            return CardStamp(verdict: verdict, opacity: SwipeGeometry.stampOpacity(distance: distance))
        }

        /// 1:1 with the finger, except the down dead zone, which follows at `DSSwipe.downFollow`.
        /// Rotation and the FAVE lift are interpretive, so Reduce Motion drops them (§6).
        func pose(reduceMotion: Bool) -> CardPose {
            let follow = sector == .down ? DSSwipe.downFollow : 1
            let offset = CGSize(width: translation.width * follow, height: translation.height * follow)
            guard !reduceMotion else { return CardPose(offset: offset) }
            return CardPose(offset: offset,
                            rotation: SwipeGeometry.rotationDegrees(dx: offset.width),
                            scale: sector == .fave ? SwipeGeometry.upScale(distance: distance) : 1)
        }
    }

    private(set) var drag: Drag?
    /// The pose of a card leaving (from release until it is out of `ReviewModel.flying`) or coming
    /// back (from a rewind until it lands). It takes precedence over the card's stack position.
    private(set) var exits: [String: CardPose] = [:]
    /// The full stamp of a card leaving or coming back.
    private(set) var stamps: [String: CardStamp] = [:]
    /// The second card's progress at release, held until the stack re-lays out at `promoteAt`.
    private(set) var releaseProgress: CGFloat = .zero
    /// Trigger for `DSHaptic.thresholdArmed`.
    private(set) var armedCount = 0

    /// Where the last committed card went, so a rewind brings it back from there (§6 Rewind).
    @ObservationIgnored private var lastExit: (id: String, pose: CardPose)?
    /// The card a rewind is bringing back. Its pose survives the end of its flight.
    @ObservationIgnored private var rewindingID: String?

    // MARK: - Finger

    func dragChanged(_ id: String, translation: CGSize, velocity: CGSize, model: ReviewModel) {
        if drag?.id != id {
            guard model.acceptsInput, model.deck.first?.id == id else { return }
            model.beginDrag()
            drag = Drag(id: id)
        }
        guard var next = drag else { return }
        next.translation = translation
        next.sector = SwipeGeometry.sector(dx: translation.width, dy: translation.height, current: next.sector)
        if !next.hasArmed, let sector = next.sector, sector.verdict != nil,
           SwipeGeometry.shouldCommit(distance: next.distance,
                                      velocityAlongAxis: SwipeGeometry.velocityAlongAxis(velocity: velocity, sector: sector)) {
            next.hasArmed = true
            armedCount += 1
        }
        drag = next
    }

    /// Release: the sector at release is the one that counts (§6). Commit on distance, or on velocity
    /// along the sector's axis past the travel floor (ADR-019); anything else snaps back.
    func dragEnded(translation: CGSize, velocity: CGSize, model: ReviewModel, reduceMotion: Bool) {
        guard var released = drag else { return }
        released.translation = translation
        released.sector = SwipeGeometry.sector(dx: translation.width, dy: translation.height, current: released.sector)
        guard let sector = released.sector, let verdict = sector.verdict else {
            return snapBack(model: model, reduceMotion: reduceMotion)
        }
        // A finger moving back toward the centre carries no momentum into the throw.
        let speed = max(SwipeGeometry.velocityAlongAxis(velocity: velocity, sector: sector), .zero)
        guard SwipeGeometry.shouldCommit(distance: released.distance, velocityAlongAxis: speed) else {
            return snapBack(model: model, reduceMotion: reduceMotion)
        }
        let start = released.pose(reduceMotion: reduceMotion)
        let exit: CardPose
        switch verdict {
        case .trash:
            exit = CardPose(offset: CGSize(width: -DSSwipe.exitDistanceX, height: start.offset.height),
                            rotation: -Double(DSSwipe.exitRotationDegrees), scale: start.scale)
        case .archive:
            exit = CardPose(offset: CGSize(width: DSSwipe.exitDistanceX, height: start.offset.height),
                            rotation: Double(DSSwipe.exitRotationDegrees), scale: start.scale)
        case .fave:
            exit = CardPose(offset: CGSize(width: start.offset.width, height: -DSSwipe.exitDistanceY),
                            rotation: start.rotation, scale: start.scale)
        }
        let exitDuration = launch(released.id, verdict: verdict, from: start, to: exit,
                                  throwDuration: DSMotion.exitDuration(velocity: speed),
                                  stampAnimation: DSMotion.standard,
                                  progress: released.progress, reduceMotion: reduceMotion)
        // The front card is pinned while `dragging` (IA §5), so the model commits this very card.
        Task {
            await model.commit(verdict, exitDuration: exitDuration)
            restoreIfUncommitted(released.id, model: model, reduceMotion: reduceMotion)
        }
    }

    /// The gesture went away without `onEnded` (a system gesture, the app leaving the foreground):
    /// an uncommitted release.
    func dragInterrupted(model: ReviewModel, reduceMotion: Bool) {
        guard drag != nil else { return }
        snapBack(model: model, reduceMotion: reduceMotion)
    }

    /// Silent by design (§7): nothing happened, so nothing is reported.
    private func snapBack(model: ReviewModel, reduceMotion: Bool) {
        withAnimation(DSMotion.gated(DSMotion.snapBack, reduce: reduceMotion, reduced: DSMotion.snapBackReduced)) {
            drag = nil
        }
        model.cancelDrag()
    }

    // MARK: - Buttons, keys and VoiceOver

    /// The synthesized flick (§10): the stamp pops with `DSMotion.stampPop`, the card leaves over
    /// `DSMotion.buttonFlick` at the drag clamp, `DSSwipe.maxRotationDegrees`, and the same haptic fires.
    func flick(_ verdict: Verdict, model: ReviewModel, reduceMotion: Bool) {
        Task {
            // Checked in the same main-actor turn as the model's own guard, so the card that is
            // animated is the card that is committed.
            guard model.acceptsInput, let front = model.deck.first else { return }
            let exitDuration = launch(front.id, verdict: verdict, from: .rest, to: Self.flickExit(verdict),
                                      throwDuration: DSMotion.buttonFlick, stampAnimation: DSMotion.stampPop,
                                      progress: .zero, reduceMotion: reduceMotion)
            await model.commit(verdict, exitDuration: exitDuration)
            restoreIfUncommitted(front.id, model: model, reduceMotion: reduceMotion)
        }
    }

    private static func flickExit(_ verdict: Verdict) -> CardPose {
        switch verdict {
        case .trash:
            return CardPose(offset: CGSize(width: -DSSwipe.exitDistanceX, height: .zero),
                            rotation: -Double(DSSwipe.maxRotationDegrees))
        case .archive:
            return CardPose(offset: CGSize(width: DSSwipe.exitDistanceX, height: .zero),
                            rotation: Double(DSSwipe.maxRotationDegrees))
        case .fave:
            return CardPose(offset: CGSize(width: .zero, height: -DSSwipe.exitDistanceY))
        }
    }

    /// Starts the exit and returns the duration the model promotes against. Reduce Motion substitutes
    /// the throw (§6): the stamp holds for `DSMotion.stampHoldReduced`, then the card cross-fades out
    /// where it is, with no rotation and no stack parallax.
    private func launch(_ id: String, verdict: Verdict, from start: CardPose, to exit: CardPose,
                        throwDuration: Double, stampAnimation: Animation, progress: CGFloat,
                        reduceMotion: Bool) -> Double {
        var target = exit
        if reduceMotion {
            target = start
            target.opacity = .zero
        }
        withAnimation(DSMotion.gated(stampAnimation, reduce: reduceMotion)) {
            stamps[id] = CardStamp(verdict: verdict, opacity: 1)
        }
        withAnimation(DSMotion.gated(DSMotion.throwOut(duration: throwDuration), reduce: reduceMotion,
                                     reduced: DSMotion.crossFade.delay(DSMotion.stampHoldReduced))) {
            exits[id] = target
            releaseProgress = reduceMotion ? .zero : progress
            drag = nil
        }
        lastExit = (id, target)
        return reduceMotion ? DSMotion.stampHoldReduced + DSMotion.fade : throwDuration
    }

    /// Safety net: if the model declined the commit, the card comes back rather than staying off
    /// screen as the front card.
    private func restoreIfUncommitted(_ id: String, model: ReviewModel, reduceMotion: Bool) {
        guard exits[id] != nil, model.flying?.screenshot.id != id,
              model.deck.contains(where: { $0.id == id }) else { return }
        withAnimation(DSMotion.gated(DSMotion.snapBack, reduce: reduceMotion, reduced: DSMotion.snapBackReduced)) {
            exits[id] = nil
            stamps[id] = nil
        }
    }

    // MARK: - Rewind

    /// One step back (ADR-008). The card is put back at the pose it left with; `land(_:reduceMotion:)`
    /// brings it in once the model has it at the front of the deck again.
    func rewind(model: ReviewModel, reduceMotion: Bool) {
        Task {
            guard model.canRewind, let entry = model.rewindEntry else { return }
            let recorded = lastExit?.id == entry.id ? lastExit?.pose : nil
            rewindingID = entry.id
            releaseProgress = .zero
            exits[entry.id] = recorded ?? (reduceMotion ? CardPose(opacity: .zero) : Self.flickExit(entry.verdict))
            stamps[entry.id] = CardStamp(verdict: entry.verdict, opacity: 1)
            // Input stays closed until the card has landed (IA §5 `rewinding`). The land spring has no
            // duration token, so the window is the slowest throw; under Reduce Motion, one cross-fade.
            await model.rewind(landDuration: reduceMotion ? DSMotion.fade : DSMotion.exitMax)
            rewindingID = nil
            exits[entry.id] = nil
            stamps[entry.id] = nil
        }
    }

    /// `ReviewModel.landing` names the card: it lands with `DSMotion.land` and its stamp fades over
    /// `DSMotion.dur2` (§6 Rewind). Under Reduce Motion both become `DSMotion.crossFade`.
    func land(_ id: String, reduceMotion: Bool) {
        withAnimation(DSMotion.gated(DSMotion.land, reduce: reduceMotion, reduced: DSMotion.crossFade)) {
            exits[id] = nil
        }
        withAnimation(DSMotion.gated(DSMotion.standard, reduce: reduceMotion, reduced: DSMotion.crossFade)) {
            stamps[id] = nil
        }
    }

    /// `ReviewModel.flying` moved on from `id`: that flight is over, or a newer card replaced it.
    func flightEnded(_ id: String) {
        guard id != rewindingID else { return }
        exits[id] = nil
        stamps[id] = nil
    }
}

/// UI_DESIGN §10 "CardStack": `DSSize.stackDepth` cards front to back in a `ZStack`. Card n behind the
/// front sits `n × DSSize.stackOffsetY` lower at `1 − n × DSSize.stackScaleStep`, on `DSShadow.stack`.
/// Only the front card takes the gesture. The card in flight stays on top until it is out. At
/// `DSSwipe.promoteAt` of the exit the stack re-lays out with `DSMotion.stackSettle`, and the new back
/// card fades in over `DSMotion.fade`.
///
/// States: `loading` (the skeleton), `populated`, `last` (nothing behind), and `done`, where the deck
/// is empty and only a card still in flight is drawn over the block. The stack itself carries no
/// VoiceOver label; the front card carries everything (P-22).
struct CardStack: View {
    let model: ReviewModel
    let motion: DeckMotion
    /// "12 of 340" for the front card's VoiceOver label. The screen computes it once per change, not
    /// on every drag frame.
    let position: String

    @Environment(Catalog.self) private var catalog
    @Environment(ImageLoader.self) private var images
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var isTouching = false
    @AccessibilityFocusState private var focusedCard: String?
    @State private var warmed = Warmed()

    /// A card in the render list: its place in `ReviewModel.deck`, or nil while it is the card in
    /// flight after the deck has already moved on.
    private struct Card {
        let shot: Screenshot
        let index: Int?
    }

    private struct Prefetch: Equatable {
        let frontID: String?
        let pixelSize: CGSize
    }

    private struct Warmed {
        var ids: [String] = []
        var pixelSize: CGSize = .zero
    }

    /// Width is the screen minus both margins; height is the space above the docked row minus
    /// `DSSpace.s5`, the gap the cards behind peek into (§10 ScreenshotCard).
    static func cardSize(in available: CGSize) -> CGSize {
        CGSize(width: max(available.width - 2 * DSGrid.mobileMargin, .zero),
               height: max(available.height - DSSpace.s5, .zero))
    }

    var body: some View {
        GeometryReader { geo in
            let cardSize = Self.cardSize(in: geo.size)
            let pixelSize = ScreenshotCard.pixelSize(forCard: cardSize, scale: displayScale)
            ZStack(alignment: .top) {
                if model.phase == .loading {
                    CardSkeleton.card(size: cardSize)
                }
                ForEach(Array(cards.enumerated()), id: \.element.shot.id) { order, card in
                    deckCard(card, size: cardSize)
                        .zIndex(Double(order))
                        .transition(.opacity.animation(DSMotion.gated(DSMotion.crossFade, reduce: reduceMotion)))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .animation(DSMotion.gated(DSMotion.stackSettle, reduce: reduceMotion), value: model.deck.map(\.id))
            .task(id: Prefetch(frontID: model.deck.first?.id, pixelSize: pixelSize)) {
                await prefetch(pixelSize: pixelSize)
            }
        }
        .onChange(of: isTouching) { _, touching in
            guard !touching else { return }
            // `onEnded` has already run for a normal release; a drag still open here was cancelled.
            Task { motion.dragInterrupted(model: model, reduceMotion: reduceMotion) }
        }
        .onChange(of: model.flying?.screenshot.id) { old, new in
            if let old, old != new { motion.flightEnded(old) }
        }
        .onChange(of: model.landing?.screenshot.id) { _, new in
            if let new { motion.land(new, reduceMotion: reduceMotion) }
        }
        .onChange(of: model.lastAnnouncement) { _, _ in
            // §13: after a commit or a rewind, VoiceOver focus moves to the new front card.
            focusedCard = model.deck.first?.id
        }
    }

    /// Back to front: the deck from its last card to its first, then the card in flight once the deck
    /// has moved on without it.
    private var cards: [Card] {
        var list = model.deck.enumerated().reversed().map { Card(shot: $0.element, index: $0.offset) }
        if let flying = model.flying?.screenshot, !model.deck.contains(where: { $0.id == flying.id }) {
            list.append(Card(shot: flying, index: nil))
        }
        return list
    }

    private func deckCard(_ card: Card, size: CGSize) -> some View {
        let isFront = card.index == 0 && motion.exits[card.shot.id] == nil
        let takesGesture = isFront && (model.acceptsInput || model.phase == .dragging)
        return DeckCard(shot: card.shot, index: card.index, size: size, frontID: model.deck.first?.id,
                        position: isFront ? position : nil, motion: motion)
            .allowsHitTesting(isFront)
            .accessibilityHidden(!isFront)
            .accessibilityFocused($focusedCard, equals: card.shot.id)
            .accessibilityActions {
                if isFront { actions }
            }
            .gesture(dragGesture(for: card.shot.id), including: takesGesture ? .all : .subviews)
    }

    /// P-22: Trash, Archive, Favorite, then Rewind last. Each runs the same pipeline as its button.
    @ViewBuilder private var actions: some View {
        ForEach(Verdict.actionOrder, id: \.self) { verdict in
            Button(verdict.actionName) {
                motion.flick(verdict, model: model, reduceMotion: reduceMotion)
            }
        }
        if model.canRewind {
            Button("Rewind") {
                motion.rewind(model: model, reduceMotion: reduceMotion)
            }
        }
    }

    /// `DragGesture(minimumDistance: 10)` (§6): 10 is SwiftUI's default, so no value is typed here.
    /// Measured in the global space, because the card it drives is itself moving under the finger.
    private func dragGesture(for id: String) -> some Gesture {
        DragGesture(coordinateSpace: .global)
            .updating($isTouching) { _, touching, _ in touching = true }
            .onChanged { value in
                motion.dragChanged(id, translation: value.translation, velocity: value.velocity, model: model)
            }
            .onEnded { value in
                motion.dragEnded(translation: value.translation, velocity: value.velocity,
                                 model: model, reduceMotion: reduceMotion)
            }
    }

    /// One stack ahead of the front card (`DSSize.stackDepth` cards): images warmed at the card's pixel
    /// size and file sizes read, so promoting a card never waits on PhotoKit (§15 item 4).
    private func prefetch(pixelSize: CGSize) async {
        guard let frontID = model.deck.first?.id, pixelSize.width > .zero, pixelSize.height > .zero else { return }
        let ahead = Array(catalog.queue.lazy.filter { $0.id != frontID }.prefix(DSSize.stackDepth).map(\.id))
        let stale = warmed.ids.filter { !ahead.contains($0) || warmed.pixelSize != pixelSize }
        if !stale.isEmpty {
            images.stopCaching(ids: stale, targetSize: warmed.pixelSize, contentMode: .aspectFit)
        }
        images.startCaching(ids: ahead, targetSize: pixelSize, contentMode: .aspectFit)
        warmed = Warmed(ids: ahead, pixelSize: pixelSize)
        for id in ahead {
            guard !Task.isCancelled else { return }
            _ = await catalog.fileSizeBytes(for: id)
        }
    }
}

/// One card of the stack. It reads its own pose from `DeckMotion`, so a drag frame re-renders the
/// front and second cards and nothing else.
private struct DeckCard: View {
    let shot: Screenshot
    /// Place in `ReviewModel.deck`; nil for the card in flight after the deck moved on.
    let index: Int?
    let size: CGSize
    let frontID: String?
    let position: String?
    let motion: DeckMotion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let pose = self.pose
        ScreenshotCard(screenshot: shot, size: size, floats: isTopCard, showsStamps: isTopCard,
                       stamp: stamp, position: position)
            .scaleEffect(pose.scale, anchor: .bottom)
            .rotationEffect(.degrees(pose.rotation), anchor: .bottom)
            .offset(pose.offset)
            .opacity(pose.opacity)
    }

    /// The front card, or the card in flight above it.
    private var isTopCard: Bool { index == nil || index == 0 }

    private var pose: CardPose {
        if index == 0, let drag = motion.drag, drag.id == shot.id {
            return drag.pose(reduceMotion: reduceMotion)
        }
        if let exit = motion.exits[shot.id] { return exit }
        guard let index, index > 0 else { return .rest }
        var depth = CGFloat(index)
        if index == 1 { depth -= secondCardProgress }
        return CardPose(offset: CGSize(width: .zero, height: DSSize.stackOffsetY * depth),
                        scale: 1 - DSSize.stackScaleStep * depth)
    }

    /// §6 Stack geometry: during a drag the second card moves toward the front card's values by
    /// min(d / `DSSwipe.commitDistance`, 1); after a release it holds there until the stack re-lays
    /// out at `promoteAt`. Reduce Motion removes the parallax and the cards hold their places.
    private var secondCardProgress: CGFloat {
        guard !reduceMotion, let frontID else { return .zero }
        if let drag = motion.drag, drag.id == frontID { return drag.progress }
        return motion.exits[frontID] != nil ? motion.releaseProgress : .zero
    }

    private var stamp: CardStamp? {
        if let committed = motion.stamps[shot.id] { return committed }
        if index == 0, let drag = motion.drag, drag.id == shot.id { return drag.stamp }
        return nil
    }
}

/// `CardStack`'s `loading` state (P-18): the card's footprint in `surfaceRaised`, nothing on it.
struct CardSkeleton: View {
    var body: some View {
        GeometryReader { geo in
            Self.card(size: CardStack.cardSize(in: geo.size))
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
    }

    static func card(size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: DSRadius.xl, style: .continuous)
            .fill(DSColor.surfaceRaised)
            .frame(width: size.width, height: size.height)
            .accessibilityHidden(true)
    }
}
