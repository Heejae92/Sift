import Foundation
import Observation

/// The deck state machine of IA §5. The view animates; the model decides what the deck *is*. It also
/// holds what the all-done block says about the cleanup reminder, and re-anchors the reminder when
/// the queue runs out under review (ADR-034).
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
    /// The cleanup reminder as the all-done block shows it (ADR-034); nil until it has been read.
    private(set) var reminder: ReminderStatus?
    /// Haptic trigger: "Remind me" ended with the reminder on.
    private(set) var reminderOnCount = 0

    let catalog: Catalog
    private let reminders: any ReminderScheduler
    private let sleep: @Sendable (Duration) async -> Void
    private var pinnedFrontID: String?
    private var flightTask: Task<Void, Never>?
    /// The re-anchor started when the queue last ran out. A refresh waits for it, so it reads the new
    /// date rather than the old one.
    private var reanchorTask: Task<Void, Never>?
    /// "Remind me" is waiting on iOS, whose permission prompt sends the app through inactive and back.
    private var isEnablingReminder = false
    /// Moves on each time "Remind me" starts, so a refresh whose read began earlier cannot put an older
    /// answer over the one "Remind me" reports.
    private var reminderGeneration = 0

    init(catalog: Catalog, reminders: any ReminderScheduler,
         sleep: @escaping @Sendable (Duration) async -> Void = { try? await Task.sleep(for: $0) }) {
        self.catalog = catalog
        self.reminders = reminders
        self.sleep = sleep
    }

    // MARK: - Counter (IA §1 rule 5)

    /// The due screenshots, reviewed or not (ADR-032). One still waiting is counted once it comes
    /// due; `catalog.total`, which counts every screenshot, decides only `noScreenshots`.
    var total: Int { catalog.reviewTotal }
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
            // IA §5: a newcomer joins by date but behind the front card, never under the thumb. That
            // includes a screenshot that has just come due (ADR-032): it is the newest due one, so it
            // would otherwise sort to the front. The front card changes only through a verdict, a
            // rewind or its own disappearance, so while reviewing the current front stays in front;
            // `pinnedFrontID` carries the same rule across a drag and a landing.
            let stableFront = pinnedFrontID ?? (phase == .reviewing ? deck.first?.id : nil)
            if let pinned = stableFront, let index = ordered.firstIndex(where: { $0.id == pinned }), index != 0 {
                ordered.insert(ordered.remove(at: index), at: 0)
            }
            deck = Array(ordered.prefix(DSSize.stackDepth))
            // `noScreenshots` only when the library has none; one whose screenshots are all still
            // waiting is `allDone` (ADR-032).
            let next: Phase = catalog.total == 0 ? .noScreenshots : (queue.isEmpty ? .allDone : .reviewing)
            // The queue ran out under review. Not a launch that starts out done, and not a first
            // screenshot that arrives and waits, which takes `noScreenshots` to `allDone` with
            // nothing reviewed. A finished sift is also what re-anchors the reminder (ADR-034).
            if next == .allDone, phase == .reviewing {
                queueDoneCount += 1
                reanchorTask = Task { [reminders] in await reminders.reanchor() }
            }
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

    // MARK: - Reminder (ADR-034)

    /// Reads the reminder from iOS: when the all-done block appears and on every return to the
    /// foreground. Skipped while "Remind me" is waiting on iOS, which reports the status itself, and
    /// dropped if "Remind me" started while the read was out.
    func refreshReminder() async {
        await reanchorTask?.value
        guard !isEnablingReminder else { return }
        let generation = reminderGeneration
        let status = await reminders.status()
        guard generation == reminderGeneration else { return }
        reminder = status
    }

    /// "Remind me every 30 days": iOS asks for permission if it never has, then the reminder is
    /// scheduled. This is the only place the app asks (ADR-010). VoiceOver hears the outcome, since
    /// the action it was on goes away (P-22).
    func enableReminder() async {
        guard !isEnablingReminder else { return }
        isEnablingReminder = true
        reminderGeneration += 1
        let status = await reminders.enable()
        isEnablingReminder = false
        reminder = status
        switch status {
        case .on(let next):
            reminderOnCount += 1
            lastAnnouncement = "Reminder on. Next reminder: \(EmptyState.arrivalDay(next))."
        case .denied:
            lastAnnouncement = "Notifications are off. Turn on reminders in Settings."
        case .off:
            break
        }
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
