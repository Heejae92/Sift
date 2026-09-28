import Foundation
import Observation

/// The deck state machine of IA §5. The view animates; the model decides what the deck *is*.
@MainActor
@Observable
final class ReviewModel {
    enum Phase: Equatable, Sendable {
        case loading, reviewing, dragging, exiting(Verdict), promoting, rewinding, allDone, noScreenshots
    }

    private(set) var phase: Phase = .loading
    /// Front card first, at most `DSSize.stackDepth` cards.
    private(set) var deck: [Screenshot] = []
    /// The card flying out, kept until the full exit duration so the view can finish the throw.
    private(set) var flying: (screenshot: Screenshot, verdict: Verdict)?
    private(set) var rewindEntry: RewindEntry?
    /// The card landing after a rewind, for the view to animate in from its exit position.
    private(set) var landing: (screenshot: Screenshot, verdict: Verdict)?
    /// VoiceOver: "Trashed. 13 of 340" (P-22).
    private(set) var lastAnnouncement: String?
    /// Haptic triggers (ADR-007): the count changes once per event.
    private(set) var commitCount = 0
    private(set) var lastVerdict: Verdict?
    private(set) var rewindCount = 0
    private(set) var queueDoneCount = 0

    let catalog: Catalog
    private let sleep: @Sendable (Duration) async -> Void
    private var pinnedFrontID: String?
    private var flightTask: Task<Void, Never>?

    init(catalog: Catalog, sleep: @escaping @Sendable (Duration) async -> Void = { try? await Task.sleep(for: $0) }) {
        self.catalog = catalog
        self.sleep = sleep
    }

    // MARK: - Counter (IA §1 rule 5)

    var total: Int { catalog.total }
    /// "12 / 340" while a card is up; `total / total` when the queue is empty.
    var position: Int {
        let reviewed = catalog.reviewedCount
        return catalog.queue.isEmpty ? total : min(reviewed + 1, total)
    }

    var acceptsInput: Bool { phase == .reviewing }
    var canRewind: Bool { rewindEntry != nil && (phase == .reviewing || phase == .allDone) }

    // MARK: - Deck

    /// Recompute the deck from the catalog when the phase allows it. During `dragging`, `exiting`
    /// and `promoting` the front card is pinned; the cards behind it may refresh (IA §8).
    func sync() {
        guard catalog.isLoaded else { phase = .loading; return }
        let queue = catalog.queue
        switch phase {
        case .dragging, .exiting, .promoting, .rewinding:
            guard let front = deck.first else { return }
            let rest = queue.filter { $0.id != front.id }
            deck = [front] + Array(rest.prefix(DSSize.stackDepth - 1))
        case .loading, .reviewing, .allDone, .noScreenshots:
            var ordered = queue
            // IA §5: a newcomer joins by date but behind the front card, never under the thumb. The
            // front card changes only through a verdict, a rewind or its own disappearance, so while
            // reviewing the current front stays in front; `pinnedFrontID` carries the same rule
            // across a drag and a landing.
            let stableFront = pinnedFrontID ?? (phase == .reviewing ? deck.first?.id : nil)
            if let pinned = stableFront, let index = ordered.firstIndex(where: { $0.id == pinned }), index != 0 {
                ordered.insert(ordered.remove(at: index), at: 0)
            }
            deck = Array(ordered.prefix(DSSize.stackDepth))
            let next: Phase = catalog.total == 0 ? .noScreenshots : (queue.isEmpty ? .allDone : .reviewing)
            if next == .allDone, phase != .allDone, phase != .loading { queueDoneCount += 1 }
            phase = next
        }
    }

    func beginDrag() {
        guard phase == .reviewing else { return }
        phase = .dragging
    }

    func cancelDrag() {
        guard phase == .dragging else { return }
        phase = .reviewing
        sync()
    }

    /// Throw the front card. The side effect fires at `DSSwipe.promoteAt` of the exit and input
    /// reopens then; the flying card is released at the end of the exit.
    func commit(_ verdict: Verdict, exitDuration: Double) async {
        guard phase == .reviewing || phase == .dragging, let front = deck.first else { return }
        pinnedFrontID = nil
        phase = .exiting(verdict)
        flying = (front, verdict)
        landing = nil
        await sleep(.seconds(exitDuration * Double(DSSwipe.promoteAt)))
        phase = .promoting
        let entry: RewindEntry?
        switch verdict {
        case .trash: entry = await catalog.trash(front.id)
        case .archive: entry = await catalog.archive(front.id)
        case .fave: entry = await catalog.favorite(front.id)
        }
        rewindEntry = entry
        lastVerdict = verdict
        commitCount += 1
        phase = .reviewing
        sync()
        lastAnnouncement = "\(verdict.pastTense). \(position) of \(total)"
        let remaining = max(exitDuration * (1 - Double(DSSwipe.promoteAt)), 0)
        flightTask?.cancel()
        flightTask = Task { [sleep] in
            await sleep(.seconds(remaining))
            guard !Task.isCancelled else { return }
            self.flying = nil
        }
    }

    /// One step back (ADR-008). The card returns to the front of the deck.
    func rewind(landDuration: Double) async {
        guard canRewind, let entry = rewindEntry else { return }
        rewindEntry = nil
        flightTask?.cancel()
        flying = nil
        phase = .rewinding
        rewindCount += 1
        await catalog.rewind(entry)
        pinnedFrontID = entry.id
        if let shot = catalog.screenshot(entry.id) {
            landing = (shot, entry.verdict)
            deck = [shot] + deck.filter { $0.id != shot.id }.prefix(DSSize.stackDepth - 1)
        }
        await sleep(.seconds(landDuration))
        landing = nil
        phase = .reviewing
        sync()
        lastAnnouncement = "Rewound. \(position) of \(total)"
    }

    /// Called when the catalog changes underneath the deck; safe in any phase.
    func catalogDidChange() {
        invalidateStaleRewind()
        sync()
    }

    /// IA §5 "invalidation": the rewind entry is dropped once its verdict no longer stands — the
    /// screenshot was restored, moved, purged or deleted elsewhere — so Rewind never reverses a
    /// state that has already changed under it.
    private func invalidateStaleRewind() {
        guard let entry = rewindEntry else { return }
        guard let shot = catalog.screenshot(entry.id) else { rewindEntry = nil; return }
        let stillHolds: Bool
        switch entry.verdict {
        case .trash: stillHolds = catalog.state.isTrashed(entry.id)
        case .archive: stillHolds = entry.wasArchived || catalog.state.isArchived(entry.id)
        case .fave: stillHolds = entry.wasFavorite || shot.isFavorite
        }
        if !stillHolds { rewindEntry = nil }
    }
}

extension Verdict {
    var pastTense: String {
        switch self {
        case .trash: return "Trashed"
        case .archive: return "Archived"
        case .fave: return "Favorited"
        }
    }

    var caption: String {
        switch self {
        case .trash: return "Trash"
        case .archive: return "Archive"
        case .fave: return "Fave"
        }
    }

    var stampWord: String { caption.uppercased() }
}
