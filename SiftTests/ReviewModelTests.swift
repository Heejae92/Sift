import Foundation
import Testing
@testable import Sift

@MainActor
struct ReviewModelTests {
    private func make(shots: [Screenshot]) async -> (ReviewModel, Catalog, FakePhotoLibrary) {
        let library = FakePhotoLibrary(shots: shots)
        let catalog = Catalog(library: library, persistence: InMemoryPersistence())
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
}
