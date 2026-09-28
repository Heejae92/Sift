import Foundation
import Observation

/// Library (UI_DESIGN §11.4): Favorites and Archive over one grid. Favorites is the Photos heart;
/// Archive is the app's own list, which the album mirrors (ADR-025, A4). An asset in both appears in
/// both. A move sets the destination and clears the source; Trash clears both (IA §6). All of it is
/// rung 0 of ADR-009: no confirmation.
@MainActor
@Observable
final class LibraryModel {
    let catalog: Catalog

    /// The visible segment. Favorites first, the way the control reads.
    var segment: LibrarySegment = .favorites

    // Haptic triggers (UI_DESIGN §7). A move lands as its destination's verdict; Trash is `.trash`.
    // The segment switch has no counter here: `SegmentedControl` fires `.segment` itself.
    private(set) var moveCount = 0
    private(set) var trashCount = 0

    init(catalog: Catalog) {
        self.catalog = catalog
    }

    /// The visible segment's screenshots, in the catalog's order (newest first).
    var items: [Screenshot] {
        segment == .favorites ? catalog.favorites : catalog.archived
    }

    var favoritesCount: Int { catalog.favorites.count }
    var archivedCount: Int { catalog.archived.count }

    /// Where a move from the visible segment lands: the other one.
    var moveDestination: LibrarySegment {
        segment == .favorites ? .archive : .favorites
    }

    func move(_ id: String) async {
        moveCount += 1
        await catalog.move(id, to: moveDestination)
    }

    func trash(_ id: String) async {
        trashCount += 1
        await catalog.trashFromLibrary(id)
    }
}
