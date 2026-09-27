import Foundation
import Testing
@testable import Sift

@MainActor
struct CatalogTests {
    private func make(shots: [Screenshot], state: StoreState? = nil, status: PhotoAuthorization = .authorized)
        -> (Catalog, FakePhotoLibrary, InMemoryPersistence) {
        let library = FakePhotoLibrary(status: status, shots: shots)
        let persistence = InMemoryPersistence(initial: state)
        let clock = TickingClock()
        let catalog = Catalog(library: library, persistence: persistence, now: { clock.next() })
        return (catalog, library, persistence)
    }

    /// Strictly increasing timestamps so "most recently trashed first" is deterministic.
    private final class TickingClock: @unchecked Sendable {
        private let lock = NSLock()
        private var t = 0.0
        func next() -> Date { lock.withLock { t += 1; return Date(timeIntervalSince1970: t) } }
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
        let library = FakePhotoLibrary(shots: Fixtures.shots(3))
        await library.seedAlbum(title: Brand.archiveAlbumTitle, members: ["s2"])
        let catalog = Catalog(library: library, persistence: InMemoryPersistence())
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

    @Test func externalDeleteDropsFromEveryList() async {
        let (catalog, library, _) = make(shots: Fixtures.shots(2))
        await catalog.load()
        await catalog.trash("s1")
        await library.remove("s1")
        await catalog.refresh()
        #expect(catalog.trashed.isEmpty)
        #expect(catalog.state.trash.isEmpty)
    }
}
