import Foundation
import Testing
@testable import Sift

@MainActor
struct CatalogTests {
    private func make(shots: [Screenshot], state: StoreState? = nil, status: PhotoAuthorization = .authorized,
                      clock: TickingClock = TickingClock()) -> (Catalog, FakePhotoLibrary, InMemoryPersistence) {
        let library = FakePhotoLibrary(status: status, shots: shots)
        let persistence = InMemoryPersistence(initial: state)
        let catalog = Catalog(library: library, persistence: persistence, now: { clock.next() },
                              minimumAge: Fixtures.minimumAge)
        return (catalog, library, persistence)
    }

    @Test func queueIsNewestFirstAndSkipsPreexistingHearts() async {
        let (catalog, _, _) = make(shots: Fixtures.shots(5, favorite: ["s3"]))
        await catalog.load()
        #expect(catalog.queue.map(\.id) == ["s1", "s2", "s4", "s5"])   // A1: s3 never enters
        #expect(catalog.favorites.map(\.id) == ["s3"])
        #expect(catalog.total == 5)
        #expect(catalog.reviewedCount == 1)
    }

    @Test func trashLeavesQueueAndShowsInTrashNewestTrashedFirst() async {
        let (catalog, _, persistence) = make(shots: Fixtures.shots(3))
        await catalog.load()
        await catalog.trash("s1")
        await catalog.trash("s3")
        #expect(catalog.queue.map(\.id) == ["s2"])
        #expect(catalog.trashed.map(\.id) == ["s3", "s1"])
        #expect(persistence.current?.trash.map(\.id) == ["s1", "s3"])
    }

    @Test func archiveMirrorsToAlbumAndFavoriteWritesPhotos() async {
        let (catalog, library, _) = make(shots: Fixtures.shots(2))
        await catalog.load()
        await catalog.archive("s1")
        await catalog.favorite("s2")
        #expect(catalog.queue.isEmpty)
        #expect(catalog.archived.map(\.id) == ["s1"])
        #expect(catalog.favorites.map(\.id) == ["s2"])
        let albumID = catalog.state.archiveAlbumID
        #expect(albumID != nil)
        #expect(await library.members(of: albumID ?? "") == ["s1"])
        #expect(await library.favoriteWrites.map(\.id) == ["s2"])
    }

    @Test func rewindUndoesExactlyOneVerdict() async {
        let (catalog, library, _) = make(shots: Fixtures.shots(3))
        await catalog.load()
        let t = await catalog.trash("s1")
        let a = await catalog.archive("s2")
        let f = await catalog.favorite("s3")
        await catalog.rewind(f!)
        #expect(catalog.queue.map(\.id) == ["s3"])
        await catalog.rewind(a!)
        #expect(catalog.queue.map(\.id) == ["s2", "s3"])
        #expect(await library.members(of: catalog.state.archiveAlbumID ?? "").isEmpty)
        await catalog.rewind(t!)
        #expect(catalog.queue.map(\.id) == ["s1", "s2", "s3"])
        #expect(catalog.state.trash.isEmpty && catalog.state.archive.isEmpty)
    }

    @Test func restoreReturnsByDate() async {
        let (catalog, _, _) = make(shots: Fixtures.shots(3))
        await catalog.load()
        await catalog.trash("s2")
        #expect(catalog.queue.map(\.id) == ["s1", "s3"])
        catalog.restore("s2")
        #expect(catalog.queue.map(\.id) == ["s1", "s2", "s3"])
    }

    @Test func moveClearsTheSource() async {
        let (catalog, library, _) = make(shots: Fixtures.shots(2, favorite: ["s1"]))
        await catalog.load()
        await catalog.move("s1", to: .archive)
        #expect(catalog.favorites.isEmpty)
        #expect(catalog.archived.map(\.id) == ["s1"])
        await catalog.move("s1", to: .favorites)
        #expect(catalog.archived.isEmpty)
        #expect(catalog.favorites.map(\.id) == ["s1"])
        #expect(await library.members(of: catalog.state.archiveAlbumID ?? "").isEmpty)
    }

    @Test func trashFromLibraryWinsOverBothMemberships() async {
        let (catalog, _, _) = make(shots: Fixtures.shots(1, favorite: ["s1"]))
        await catalog.load()
        await catalog.trashFromLibrary("s1")
        #expect(catalog.trashed.map(\.id) == ["s1"])
        #expect(catalog.favorites.isEmpty && catalog.archived.isEmpty && catalog.queue.isEmpty)
    }

    @Test func purgeOutcomes() async {
        let (catalog, library, _) = make(shots: Fixtures.shots(3))
        await catalog.load()
        await catalog.trash("s1"); await catalog.trash("s2")
        await library.set(deleteBehavior: .cancel)
        #expect(await catalog.purge(["s1"]) == .cancelled)
        #expect(catalog.trashed.count == 2)
        await library.set(deleteBehavior: .succeed)
        #expect(await catalog.purge(["s1", "s2"]) == .deleted(count: 2))
        #expect(catalog.trashed.isEmpty)
        #expect(catalog.total == 1)
        #expect(await library.deletedIDs == ["s1", "s2"])
    }

    @Test func emptyStoreAdoptsExistingAlbum() async {
        let (catalog, library, _) = make(shots: Fixtures.shots(3))
        await library.seedAlbum(title: Brand.archiveAlbumTitle, members: ["s2"])
        await catalog.load()
        #expect(catalog.archived.map(\.id) == ["s2"])
        #expect(catalog.queue.map(\.id) == ["s1", "s3"])
    }

    @Test func handRemovedMemberIsUnarchived() async {
        let (catalog, library, _) = make(shots: Fixtures.shots(2))
        await catalog.load()
        await catalog.archive("s1"); await catalog.archive("s2")
        let albumID = catalog.state.archiveAlbumID!
        try? await library.removeFromAlbum(["s1"], albumID: albumID)
        await catalog.adoptArchiveAlbumIfNeeded()
        #expect(catalog.archived.map(\.id) == ["s2"])
        #expect(catalog.queue.map(\.id) == ["s1"])
    }

    @Test func refusedAlbumWriteKeepsTheListAsTruth() async {
        let (catalog, library, _) = make(shots: Fixtures.shots(1), status: .limited)
        await library.set(refuseAlbumWrites: true)
        await catalog.load()
        await catalog.archive("s1")
        #expect(catalog.archived.map(\.id) == ["s1"])
        #expect(catalog.albumMirrorRefused)
    }

    @Test func limitedInterstitialShowsOnlyWhenSelectionChanged() async {
        let (catalog, library, _) = make(shots: Fixtures.shots(2), status: .limited)
        await catalog.load()
        #expect(catalog.limitedSelectionChanged)
        catalog.acknowledgeLimitedSelection()
        #expect(!catalog.limitedSelectionChanged)
        await library.add(Fixtures.newer("s9"))
        await catalog.refresh()
        #expect(catalog.limitedSelectionChanged)
    }

    /// ADR-010: the access prompt comes from the tap on the Permission screen, never from launch.
    /// Registering a PhotoKit change observer prompts while access is undetermined, so the catalog
    /// must not open its change stream until access is usable, and must open it exactly once after.
    @Test func observingWaitsForUsableAccess() async {
        let (catalog, library, _) = make(shots: Fixtures.shots(2), status: .notDetermined)
        await catalog.load()
        catalog.startObserving()  // an explicit call is a no-op too
        for _ in 0..<20 { await Task.yield() }
        #expect(await library.changeStreamCount == 0)
        #expect(catalog.isLoaded && !catalog.authorization.isUsable)

        await catalog.requestAuthorization()  // the fake grants on request
        #expect(catalog.authorization == .authorized)
        var tries = 0
        while await library.changeStreamCount == 0, tries < 200 { await Task.yield(); tries += 1 }
        #expect(await library.changeStreamCount == 1)

        await catalog.refreshAuthorization()  // idempotent: no second stream
        for _ in 0..<20 { await Task.yield() }
        #expect(await library.changeStreamCount == 1)

        await library.remove("s1")  // and the stream is live: an external change refreshes
        await library.emitChange()
        tries = 0
        while catalog.screenshots.count == 2, tries < 200 { await Task.yield(); tries += 1 }
        #expect(catalog.screenshots.count == 1)
    }

    @Test func externalDeleteDropsFromEveryList() async {
        let (catalog, library, _) = make(shots: Fixtures.shots(2))
        await catalog.load()
        await catalog.trash("s1")
        await library.remove("s1")
        await catalog.refresh()
        #expect(catalog.trashed.isEmpty)
        #expect(catalog.state.trash.isEmpty)
    }

    // MARK: - ADR-032: only screenshots at least 30 days old are reviewed

    /// Screenshots under 30 days old wait: out of the queue and out of the counter's denominator, but
    /// in `total`, which the limited-access interstitial counts. A reviewed one (hearted) does not
    /// wait, and the oldest waiting one is the next to arrive.
    @Test func recentScreenshotsWaitOutsideTheQueue() async {
        let recent = [Fixtures.shot("r1", takenAt: Fixtures.clockStart - 1 * Fixtures.day),
                      Fixtures.shot("r2", takenAt: Fixtures.clockStart - 10 * Fixtures.day),
                      Fixtures.shot("r3", takenAt: Fixtures.clockStart - 5 * Fixtures.day, favorite: true)]
        let (catalog, _, _) = make(shots: Fixtures.shots(2) + recent)
        await catalog.load()
        #expect(catalog.queue.map(\.id) == ["s1", "s2"])
        #expect(catalog.waiting.map(\.id) == ["r2", "r1"])   // oldest first
        #expect(catalog.nextArrival == Date(timeIntervalSince1970: Fixtures.clockStart + 20 * Fixtures.day))
        #expect(catalog.total == 5)
        #expect(catalog.reviewTotal == 2)
        #expect(catalog.reviewedCount == 0)
        #expect(catalog.favorites.map(\.id) == ["r3"])        // Library does not wait
    }

    /// The queue holds still between refreshes; a screenshot that has come of age joins it on the next
    /// refresh, as the newest due screenshot.
    @Test func aScreenshotAgesInOnTheNextRefresh() async {
        let clock = TickingClock()
        let r1 = Fixtures.shot("r1", takenAt: Fixtures.clockStart - 29 * Fixtures.day)
        let (catalog, _, _) = make(shots: Fixtures.shots(2) + [r1], clock: clock)
        await catalog.load()
        #expect(catalog.waiting.map(\.id) == ["r1"])
        let loadedAt = catalog.referenceDate
        clock.advance(by: 2 * Fixtures.day)                    // r1 is past 30 days now
        #expect(catalog.queue.map(\.id) == ["s1", "s2"])      // still measured at the last refresh
        await catalog.refresh()
        #expect(catalog.referenceDate > loadedAt)
        #expect(catalog.queue.map(\.id) == ["r1", "s1", "s2"])
        #expect(catalog.waiting.isEmpty && catalog.nextArrival == nil)
        #expect(catalog.reviewTotal == 3 && catalog.reviewedCount == 0)
    }

    /// A device clock set back does not move the reference date back, so a due card stays due.
    @Test func settingTheClockBackKeepsADueScreenshotDue() async {
        let clock = TickingClock()
        let r1 = Fixtures.shot("r1", takenAt: Fixtures.clockStart - 30.5 * Fixtures.day)
        let (catalog, _, _) = make(shots: [r1], clock: clock)
        await catalog.load()
        let loadedAt = catalog.referenceDate
        clock.advance(by: -Fixtures.day)                       // r1 would read 29.5 days old
        await catalog.refresh()
        #expect(catalog.referenceDate == loadedAt)
        #expect(catalog.queue.map(\.id) == ["r1"] && catalog.waiting.isEmpty)
    }

    /// The boundary belongs to the queue: exactly 30 days old is due, one second younger waits.
    @Test func exactlyThirtyDaysOldIsDue() async {
        let reference = Date(timeIntervalSince1970: Fixtures.clockStart)
        let edge = Fixtures.shot("edge", takenAt: Fixtures.clockStart - Fixtures.minimumAge)
        let inside = Fixtures.shot("inside", takenAt: Fixtures.clockStart - Fixtures.minimumAge + 1)
        let catalog = Catalog(library: FakePhotoLibrary(shots: [edge, inside]), persistence: InMemoryPersistence(),
                              now: { reference }, minimumAge: Fixtures.minimumAge)
        await catalog.load()
        #expect(Fixtures.minimumAge == 30 * 86_400)
        #expect(catalog.referenceDate == reference)
        #expect(catalog.queue.map(\.id) == ["edge"])
        #expect(catalog.waiting.map(\.id) == ["inside"])
        #expect(catalog.nextArrival == reference.addingTimeInterval(1))
    }
}
