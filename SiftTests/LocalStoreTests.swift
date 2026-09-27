import Foundation
import Testing
@testable import Sift

struct LocalStoreTests {
    @Test func roundTripThroughAFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("store-\(UUID().uuidString).json")
        let store = FileStorePersistence(url: url)
        #expect(try store.load() == nil)
        var state = StoreState()
        state.trash = [TrashEntry(id: "a", trashedAt: Date(timeIntervalSince1970: 10))]
        state.archive = [ArchiveEntry(id: "b", archivedAt: Date(timeIntervalSince1970: 20))]
        state.archiveAlbumID = "album"
        state.acknowledgedSelectionCount = 14
        try store.save(state)
        let loaded = try store.load()
        #expect(loaded == state)
        #expect(loaded?.version == StoreState.currentVersion)
        try? FileManager.default.removeItem(at: url)
    }

    @Test func membershipHelpers() {
        var state = StoreState()
        state.trash = [TrashEntry(id: "a", trashedAt: .now)]
        state.archive = [ArchiveEntry(id: "b", archivedAt: .now)]
        #expect(state.isTrashed("a") && !state.isTrashed("b"))
        #expect(state.isArchived("b") && !state.isArchived("a"))
    }
}
