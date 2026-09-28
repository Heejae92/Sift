import Foundation
import Testing
@testable import Sift

@MainActor
struct ReviewModelTests {
    private func make(shots: [Screenshot], now: @escaping @Sendable () -> Date = { Date() }) async
        -> (ReviewModel, Catalog, FakePhotoLibrary) {
        let library = FakePhotoLibrary(shots: shots)
        let catalog = Catalog(library: library, persistence: InMemoryPersistence(), now: now,
                              minimumAge: Fixtures.minimumAge)
        await catalog.load()
        let model = ReviewModel(catalog: catalog, sleep: { _ in })
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
}
