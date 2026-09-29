import Foundation
import Testing
@testable import Sift

@MainActor
struct ReviewModelTests {
    private func make(shots: [Screenshot], now: @escaping @Sendable () -> Date = { Date() },
                      reminders: FakeReminderScheduler = FakeReminderScheduler()) async
        -> (ReviewModel, Catalog, FakePhotoLibrary) {
        let library = FakePhotoLibrary(shots: shots)
        let catalog = Catalog(library: library, persistence: InMemoryPersistence(), now: now,
                              minimumAge: Fixtures.minimumAge)
        await catalog.load()
        let model = ReviewModel(catalog: catalog, reminders: reminders, sleep: { _ in })
        model.sync()
        return (model, catalog, library)
    }

    @Test func startsReviewingWithTheNewestInFront() async {
        let (model, _, _) = await make(shots: Fixtures.shots(5))
        #expect(model.phase == .reviewing)
        #expect(model.deck.map(\.id) == ["s1", "s2", "s3"])
        #expect(model.position == 1 && model.total == 5)
    }

    @Test func emptyLibraryAndEmptyQueueAreDesignedStates() async {
        let (empty, _, _) = await make(shots: [])
        #expect(empty.phase == .noScreenshots)
        let (done, _, _) = await make(shots: Fixtures.shots(1, favorite: ["s1"]))
        #expect(done.phase == .allDone)
        #expect(done.position == 1 && done.total == 1)
    }

    @Test func commitPromotesAndReopensInput() async {
        let (model, catalog, _) = await make(shots: Fixtures.shots(3))
        await model.commit(.trash, exitDuration: 0.3)
        #expect(model.phase == .reviewing)
        #expect(model.deck.map(\.id) == ["s2", "s3"])
        #expect(catalog.trashed.map(\.id) == ["s1"])
        #expect(model.position == 2)
        #expect(model.commitCount == 1 && model.lastVerdict == .trash)
        #expect(model.lastAnnouncement == "Trashed. 2 of 3")
        #expect(model.canRewind)
    }

    @Test func rewindIsSingleStepAndBringsTheCardBack() async {
        let (model, catalog, _) = await make(shots: Fixtures.shots(3))
        await model.commit(.archive, exitDuration: 0.3)
        await model.commit(.fave, exitDuration: 0.3)
        await model.rewind(landDuration: 0.45)
        #expect(model.deck.first?.id == "s2")
        #expect(catalog.favorites.isEmpty)
        #expect(!model.canRewind)                 // one step only
        #expect(catalog.archived.map(\.id) == ["s1"])
        await model.rewind(landDuration: 0.45)    // no-op
        #expect(catalog.archived.map(\.id) == ["s1"])
    }

    @Test func queueEmptyBecomesAllDoneAndRewindStaysAvailable() async {
        let (model, _, _) = await make(shots: Fixtures.shots(1))
        await model.commit(.trash, exitDuration: 0.3)
        #expect(model.phase == .allDone)
        #expect(model.queueDoneCount == 1)
        #expect(model.canRewind)
        await model.rewind(landDuration: 0.45)
        #expect(model.phase == .reviewing && model.deck.first?.id == "s1")
    }

    /// IA §5: a newcomer joins by date, behind the front card, never under the thumb. Only a
    /// verdict (or a rewind, or the card vanishing) changes which card is in front.
    @Test func newScreenshotJoinsBehindTheFrontCard() async {
        let (model, catalog, library) = await make(shots: Fixtures.shots(2))
        model.beginDrag()
        await library.add(Fixtures.newer("s0"))
        await catalog.refresh()
        model.catalogDidChange()
        #expect(model.deck.map(\.id) == ["s1", "s0", "s2"])   // mid-drag: front pinned, newcomer behind it
        model.cancelDrag()
        #expect(model.deck.map(\.id) == ["s1", "s0", "s2"])   // released: still the card under review
        await model.commit(.archive, exitDuration: 0)
        #expect(model.deck.map(\.id) == ["s0", "s2"])         // the verdict is what brings the newcomer forward
    }

    /// IA §5 "invalidation": Rewind is dropped when its verdict no longer stands, whether the
    /// screenshot was restored in Trash, purged, or un-hearted in Photos. An untouched verdict keeps it.
    @Test func rewindIsDroppedWhenItsVerdictNoLongerStands() async {
        let (model, catalog, library) = await make(shots: Fixtures.shots(4))
        await model.commit(.trash, exitDuration: 0)          // s1 → Trash
        #expect(model.canRewind)
        catalog.restore("s1")                                 // restored from the Trash screen
        model.catalogDidChange()
        #expect(!model.canRewind)
        #expect(model.deck.map(\.id) == ["s2", "s1", "s3"])  // returns by date, behind the stable front

        await model.commit(.trash, exitDuration: 0)          // s2 → Trash
        #expect(model.canRewind)
        _ = await catalog.purge(["s2"])                       // purged for good
        model.catalogDidChange()
        #expect(!model.canRewind)

        await model.commit(.fave, exitDuration: 0)           // s1 → Favorites
        #expect(model.canRewind)
        await library.setFavoriteFlag("s1", false)            // un-hearted in Photos
        await catalog.refresh()
        model.catalogDidChange()
        #expect(!model.canRewind)

        await model.commit(.archive, exitDuration: 0)        // s3 → Archive, untouched
        model.catalogDidChange()
        #expect(model.canRewind)
    }

    @Test func vanishedFrontCardIsSkippedWithoutAVerdict() async {
        let (model, catalog, library) = await make(shots: Fixtures.shots(2))
        model.beginDrag()
        await library.remove("s1")
        await catalog.refresh()
        model.catalogDidChange()
        await model.commit(.trash, exitDuration: 0.3)
        #expect(model.deck.map(\.id) == ["s2"])
        #expect(catalog.trashed.isEmpty)
        #expect(!model.canRewind)
    }

    // MARK: - ADR-032: only screenshots at least 30 days old are reviewed

    /// A library whose screenshots are all under 30 days old is done for now, not empty: nothing to
    /// count, a date for the block, no burst for a queue nobody finished. It leaves `allDone` when the
    /// first one comes due.
    @Test func onlyWaitingScreenshotsIsAllDoneUntilOneComesDue() async {
        let clock = TickingClock()
        let r1 = Fixtures.shot("r1", takenAt: Fixtures.clockStart - 1 * Fixtures.day)
        let (model, catalog, _) = await make(shots: [r1], now: { clock.next() })
        #expect(model.phase == .allDone)
        #expect(model.total == 0 && catalog.total == 1)
        #expect(catalog.nextArrival == Date(timeIntervalSince1970: Fixtures.clockStart + 29 * Fixtures.day))
        #expect(model.queueDoneCount == 0)

        clock.advance(by: 30 * Fixtures.day)
        await catalog.refresh()
        model.catalogDidChange()
        #expect(model.phase == .reviewing && model.deck.map(\.id) == ["r1"])
        #expect(model.position == 1 && model.total == 1)
    }

    /// A first screenshot taken into an empty library waits, so `noScreenshots` becomes `allDone`,
    /// and that is not a finished queue: no burst, no haptic.
    @Test func aFirstScreenshotThatWaitsLeavesNoScreenshotsWithoutABurst() async {
        let clock = TickingClock()
        let (model, catalog, library) = await make(shots: [], now: { clock.next() })
        #expect(model.phase == .noScreenshots)
        await library.add(Fixtures.shot("r1", takenAt: Fixtures.clockStart))
        await catalog.refresh()
        model.catalogDidChange()
        #expect(model.phase == .allDone)
        #expect(model.queueDoneCount == 0)
        #expect(catalog.nextArrival == Date(timeIntervalSince1970: Fixtures.clockStart + 30 * Fixtures.day))
    }

    /// A verdict that empties the queue while other screenshots wait is a finished queue: `allDone`,
    /// one burst, and the block can name the day the next one comes due.
    @Test func finishingTheQueueWhileOthersWaitCountsAsDone() async {
        let clock = TickingClock()
        let r1 = Fixtures.shot("r1", takenAt: Fixtures.clockStart - 10 * Fixtures.day)
        let (model, catalog, _) = await make(shots: Fixtures.shots(1) + [r1], now: { clock.next() })
        #expect(model.phase == .reviewing && model.deck.map(\.id) == ["s1"])
        await model.commit(.archive, exitDuration: 0)
        #expect(model.phase == .allDone)
        #expect(model.queueDoneCount == 1)
        #expect(catalog.nextArrival == Date(timeIntervalSince1970: Fixtures.clockStart + 20 * Fixtures.day))
    }

    /// IA §5: a screenshot that comes due mid-session is the newest due one, so it would sort to the
    /// front; it joins behind the card under review instead, and the verdict brings it forward.
    @Test func aScreenshotThatComesDueJoinsBehindTheFrontCard() async {
        let clock = TickingClock()
        let r1 = Fixtures.shot("r1", takenAt: Fixtures.clockStart - 29 * Fixtures.day)
        let (model, catalog, _) = await make(shots: Fixtures.shots(3) + [r1], now: { clock.next() })
        #expect(model.deck.map(\.id) == ["s1", "s2", "s3"])
        #expect(model.position == 1 && model.total == 3)

        clock.advance(by: 2 * Fixtures.day)
        await catalog.refresh()
        model.catalogDidChange()
        #expect(catalog.queue.first?.id == "r1")               // newest due screenshot
        #expect(model.deck.map(\.id) == ["s1", "r1", "s2"])   // behind the front, never under the thumb
        #expect(model.position == 1 && model.total == 4)

        await model.commit(.trash, exitDuration: 0)
        #expect(model.deck.map(\.id) == ["r1", "s2", "s3"])
        #expect(model.lastAnnouncement == "Trashed. 2 of 4")
    }

    // MARK: - ADR-034: the cleanup reminder

    /// Where `FakeReminderScheduler`'s clock starts.
    private static let start = Date(timeIntervalSince1970: Fixtures.clockStart)
    private static let interval = FakeReminderScheduler.interval

    /// "Remind me" from an undetermined state shows the one prompt. Allowed, the reminder is on a full
    /// interval from now, the success haptic's trigger moves once, and VoiceOver hears the date (P-22).
    /// Reading it never asks (ADR-010).
    @Test func remindMeAsksOnceAndTurnsTheReminderOn() async {
        let reminders = FakeReminderScheduler()
        let (model, _, _) = await make(shots: Fixtures.shots(1, favorite: ["s1"]), reminders: reminders)
        await model.refreshReminder()
        #expect(model.phase == .allDone && model.reminder == .off)
        #expect(await reminders.promptCount == 0)

        await model.enableReminder()
        let next = Self.start.addingTimeInterval(Self.interval)
        #expect(await reminders.promptCount == 1)
        #expect(model.reminder == .on(next: next))
        #expect(model.reminderOnCount == 1)
        #expect(model.lastAnnouncement == "Reminder on. Next reminder: \(EmptyState.arrivalDay(next)).")
    }

    /// Declined, the reminder is denied, nothing celebrates, and VoiceOver hears where to fix it. A
    /// second tap asks nothing: iOS shows the prompt once.
    @Test func decliningThePromptLeavesTheReminderDenied() async {
        let reminders = FakeReminderScheduler(allowsWhenAsked: false)
        let (model, _, _) = await make(shots: Fixtures.shots(1, favorite: ["s1"]), reminders: reminders)
        await model.enableReminder()
        #expect(model.reminder == .denied)
        #expect(model.reminderOnCount == 0)
        #expect(model.lastAnnouncement == "Notifications are off. Turn on reminders in Settings.")
        await model.enableReminder()
        #expect(await reminders.promptCount == 1)
        #expect(model.reminder == .denied)
    }

    /// While the prompt holds "Remind me", the app goes inactive and back and refreshes. That refresh
    /// must leave the block alone; the answer comes from "Remind me" once the prompt is answered.
    @Test func aRefreshWhileRemindMeWaitsLeavesTheAnswerToIt() async {
        let reminders = FakeReminderScheduler()
        let (model, _, _) = await make(shots: Fixtures.shots(1, favorite: ["s1"]), reminders: reminders)
        await reminders.hold(.enable)
        let enabling = Task { await model.enableReminder() }
        await waitUntil { await reminders.isWaiting(.enable) }
        await model.refreshReminder()
        #expect(model.reminder == nil)
        await reminders.release(.enable)
        await enabling.value
        #expect(model.reminder == .on(next: Self.start.addingTimeInterval(Self.interval)))
    }

    /// A refresh that read "off" just before "Remind me" and answers after it must not undo it.
    @Test func aRefreshThatReadBeforeRemindMeCannotUndoIt() async {
        let reminders = FakeReminderScheduler()
        let (model, _, _) = await make(shots: Fixtures.shots(1, favorite: ["s1"]), reminders: reminders)
        await reminders.hold(.status)
        let refreshing = Task { await model.refreshReminder() }
        await waitUntil { await reminders.isWaiting(.status) }
        await model.enableReminder()
        let on = ReminderStatus.on(next: Self.start.addingTimeInterval(Self.interval))
        #expect(model.reminder == on)
        await reminders.release(.status)
        await refreshing.value
        #expect(model.reminder == on)
    }

    /// Yields until `condition` holds, so a test can wait for a fake's call to reach its gate.
    private func waitUntil(_ condition: () async -> Bool) async {
        for _ in 0..<10_000 {
            if await condition() { return }
            await Task.yield()
        }
        Issue.record("the condition never held")
    }

    /// The reminder moves to a full interval from the verdict that empties the queue: not on a partial
    /// session, and again every time the queue runs out.
    @Test func aVerdictThatEmptiesTheQueueReanchorsTheReminder() async {
        let reminders = FakeReminderScheduler(authorization: .authorized, anchor: Self.start)
        let (model, _, _) = await make(shots: Fixtures.shots(2), reminders: reminders)
        await reminders.advance(by: 5 * Fixtures.day)

        await model.commit(.trash, exitDuration: 0)          // one card left: a partial session
        await model.refreshReminder()
        #expect(await reminders.reanchorCalls == 0)
        #expect(model.reminder == .on(next: Self.start.addingTimeInterval(Self.interval)))

        await model.commit(.archive, exitDuration: 0)        // the queue is empty
        await model.refreshReminder()
        #expect(model.phase == .allDone)
        #expect(await reminders.reanchorCalls == 1)
        let sifted = Self.start.addingTimeInterval(5 * Fixtures.day)
        #expect(model.reminder == .on(next: sifted.addingTimeInterval(Self.interval)))

        await model.rewind(landDuration: 0)                  // under review again, then done again
        await model.commit(.archive, exitDuration: 0)
        await model.refreshReminder()
        #expect(await reminders.reanchorCalls == 2)
    }

    /// A launch that opens on the all-done block finished nothing, so the reminder stays put.
    @Test func launchingIntoAllDoneDoesNotReanchor() async {
        let reminders = FakeReminderScheduler(authorization: .authorized, anchor: Self.start)
        let (model, _, _) = await make(shots: Fixtures.shots(1, favorite: ["s1"]), reminders: reminders)
        await model.refreshReminder()
        #expect(model.phase == .allDone)
        #expect(await reminders.reanchorCalls == 0)
        #expect(model.reminder == .on(next: Self.start.addingTimeInterval(Self.interval)))
    }

    /// Finishing the queue while the reminder is off or declined schedules nothing and asks nothing.
    @Test func finishingTheQueueWhileTheReminderIsOffSchedulesNothing() async {
        for authorization in [FakeReminderScheduler.Authorization.notDetermined, .denied] {
            let reminders = FakeReminderScheduler(authorization: authorization)
            let (model, _, _) = await make(shots: Fixtures.shots(1), reminders: reminders)
            await model.commit(.trash, exitDuration: 0)
            await model.refreshReminder()
            #expect(model.phase == .allDone)
            #expect(await reminders.reanchorCalls == 1)
            #expect(await reminders.anchor == nil)
            #expect(await reminders.promptCount == 0)
            #expect(model.reminder == (authorization == .denied ? .denied : .off))
        }
    }
}
