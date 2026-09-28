import Foundation
import Observation

/// The single source of truth (ARCHITECTURE §3). Owns the screenshots the app can see and the
/// persisted memberships; every list a screen shows is derived here and nowhere else.
@MainActor
@Observable
final class Catalog {
    private(set) var screenshots: [Screenshot] = []
    private(set) var state: StoreState
    private(set) var authorization: PhotoAuthorization = .notDetermined
    private(set) var isLoaded = false
    /// Set when the mirror album could not be written (limited access); the list stays the truth.
    private(set) var albumMirrorRefused = false

    private let library: any PhotoLibrary
    private let persistence: any StorePersistence
    private let now: @Sendable () -> Date
    private var changeTask: Task<Void, Never>?

    init(library: any PhotoLibrary, persistence: any StorePersistence,
         now: @escaping @Sendable () -> Date = { Date() }) {
        self.library = library
        self.persistence = persistence
        self.now = now
        self.state = (try? persistence.load()) ?? StoreState()
    }

    // MARK: - Derived lists (IA §1)

    /// Not trashed, not archived, not favorited. Newest first.
    var queue: [Screenshot] {
        screenshots.filter { !state.isTrashed($0.id) && !state.isArchived($0.id) && !$0.isFavorite }
    }

    /// Most recently trashed first. Trash wins on display over the other two memberships.
    var trashed: [Screenshot] {
        let order = Dictionary(uniqueKeysWithValues: state.trash.map { ($0.id, $0.trashedAt) })
        return screenshots
            .filter { order[$0.id] != nil }
            .sorted { (order[$0.id] ?? .distantPast) > (order[$1.id] ?? .distantPast) }
    }

    var favorites: [Screenshot] { screenshots.filter { $0.isFavorite && !state.isTrashed($0.id) } }
    var archived: [Screenshot] { screenshots.filter { state.isArchived($0.id) && !state.isTrashed($0.id) } }

    var total: Int { screenshots.count }
    var reviewedCount: Int { total - queue.count }

    func screenshot(_ id: String) -> Screenshot? { screenshots.first { $0.id == id } }

    /// File size for a card chip or a Trash header; `nil` while unknown. Cached per identifier.
    func fileSizeBytes(for id: String) async -> Int64? {
        if let cached = fileSizes[id] { return cached }
        guard let size = await library.fileSizeBytes(for: id) else { return nil }
        fileSizes[id] = size
        return size
    }
    private var fileSizes: [String: Int64] = [:]

    // MARK: - Lifecycle

    /// Load persisted state, read authorization, fetch what Photos allows, adopt an existing album.
    func load() async {
        authorization = await library.authorizationStatus()
        if authorization.isUsable {
            await refresh()
            await adoptArchiveAlbumIfNeeded()
            startObserving()
        }
        isLoaded = true
    }

    func requestAuthorization() async {
        authorization = await library.requestAuthorization()
        if authorization.isUsable {
            await refresh()
            await adoptArchiveAlbumIfNeeded()
            if authorization == .authorized { state.acknowledgedSelectionCount = nil; persist() }
            startObserving()
        }
        isLoaded = true
    }

    /// Re-read authorization and the library. Called on every return to the foreground (IA §4).
    func refreshAuthorization() async {
        let before = authorization
        authorization = await library.authorizationStatus()
        if authorization.isUsable {
            await refresh()
            if before == .limited, authorization == .authorized {
                state.acknowledgedSelectionCount = nil; persist()
            }
            startObserving()
        }
    }

    func refresh() async {
        let fresh = await library.fetchScreenshots()
        screenshots = fresh.sorted { $0.creationDate > $1.creationDate }
        pruneMissing()
    }

    /// Subscribe to Photos changes for the life of the app. Idempotent.
    /// Registers for library changes. Runs only once access is usable: `PHPhotoLibrary.register(_:)`
    /// prompts for access while the status is undetermined, and ADR-010 requires the prompt to come
    /// from the tap on the Permission screen, never from launch. The lifecycle methods call this
    /// themselves the moment access becomes usable; it is idempotent.
    func startObserving() {
        guard authorization.isUsable, changeTask == nil else { return }
        let stream = library.changes()
        changeTask = Task { [weak self] in
            for await _ in stream {
                guard let self else { return }
                await self.refresh()
            }
        }
    }

    // MARK: - Limited access (A2)

    /// The interstitial shows when the number of screenshots the app can see differs from the
    /// number the user last acknowledged.
    var limitedSelectionChanged: Bool {
        authorization == .limited && state.acknowledgedSelectionCount != screenshots.count
    }

    func acknowledgeLimitedSelection() {
        state.acknowledgedSelectionCount = screenshots.count
        persist()
    }

    // MARK: - Verdicts (IA §6)

    @discardableResult
    func trash(_ id: String) async -> RewindEntry? {
        guard let shot = screenshot(id) else { return nil }
        let entry = RewindEntry(id: id, verdict: .trash, wasFavorite: shot.isFavorite, wasArchived: state.isArchived(id))
        state.trash.removeAll { $0.id == id }
        state.trash.append(TrashEntry(id: id, trashedAt: now()))
        persist()
        return entry
    }

    @discardableResult
    func archive(_ id: String) async -> RewindEntry? {
        guard let shot = screenshot(id) else { return nil }
        let entry = RewindEntry(id: id, verdict: .archive, wasFavorite: shot.isFavorite, wasArchived: state.isArchived(id))
        if !state.isArchived(id) {
            state.archive.append(ArchiveEntry(id: id, archivedAt: now()))
            persist()
        }
        await mirrorAdd([id])
        return entry
    }

    @discardableResult
    func favorite(_ id: String) async -> RewindEntry? {
        guard let shot = screenshot(id) else { return nil }
        let entry = RewindEntry(id: id, verdict: .fave, wasFavorite: shot.isFavorite, wasArchived: state.isArchived(id))
        await setFavoriteLocally(id, true)
        return entry
    }

    /// Undo exactly one commit (ADR-008).
    func rewind(_ entry: RewindEntry) async {
        switch entry.verdict {
        case .trash:
            state.trash.removeAll { $0.id == entry.id }
            persist()
        case .archive:
            if !entry.wasArchived {
                state.archive.removeAll { $0.id == entry.id }
                persist()
                await mirrorRemove([entry.id])
            }
        case .fave:
            await setFavoriteLocally(entry.id, entry.wasFavorite)
        }
    }

    // MARK: - Trash screen

    /// Back to unreviewed, in date order (IA §5).
    func restore(_ id: String) {
        state.trash.removeAll { $0.id == id }
        persist()
    }

    /// Permanent deletion. Photos presents its own dialog; the list is cleared only for what is gone.
    func purge(_ ids: [String]) async -> PurgeResult {
        guard !ids.isEmpty else { return .deleted(count: 0) }
        do {
            try await library.delete(ids)
            state.trash.removeAll { ids.contains($0.id) }
            state.archive.removeAll { ids.contains($0.id) }
            persist()
            await refresh()
            return .deleted(count: ids.count)
        } catch PhotoLibraryError.cancelled {
            return .cancelled
        } catch {
            await refresh()
            let remaining = ids.filter { screenshot($0) != nil }
            state.trash.removeAll { ids.contains($0.id) && !remaining.contains($0.id) }
            persist()
            return .failed(remaining: remaining.count)
        }
    }

    // MARK: - Library screen

    /// Sets the destination and clears the source (IA §6).
    func move(_ id: String, to segment: LibrarySegment) async {
        switch segment {
        case .archive:
            if !state.isArchived(id) {
                state.archive.append(ArchiveEntry(id: id, archivedAt: now()))
                persist()
            }
            await mirrorAdd([id])
            await setFavoriteLocally(id, false)
        case .favorites:
            if state.isArchived(id) {
                state.archive.removeAll { $0.id == id }
                persist()
                await mirrorRemove([id])
            }
            await setFavoriteLocally(id, true)
        }
    }

    /// Trash from the viewer: the trash list wins, so the other memberships are cleared too.
    func trashFromLibrary(_ id: String) async {
        let wasArchived = state.isArchived(id)
        state.archive.removeAll { $0.id == id }
        state.trash.removeAll { $0.id == id }
        state.trash.append(TrashEntry(id: id, trashedAt: now()))
        persist()
        if wasArchived { await mirrorRemove([id]) }
        await setFavoriteLocally(id, false)
    }

    // MARK: - Album mirror (A4)

    private func ensureAlbum() async -> String? {
        do {
            let albumID = try await library.ensureArchiveAlbum(existingID: state.archiveAlbumID, title: Brand.archiveAlbumTitle)
            if albumID != state.archiveAlbumID { state.archiveAlbumID = albumID; persist() }
            albumMirrorRefused = false
            return albumID
        } catch {
            albumMirrorRefused = true
            return nil
        }
    }

    private func mirrorAdd(_ ids: [String]) async {
        guard let albumID = await ensureAlbum() else { return }
        do { try await library.addToAlbum(ids, albumID: albumID) } catch { albumMirrorRefused = true }
    }

    private func mirrorRemove(_ ids: [String]) async {
        guard let albumID = state.archiveAlbumID else { return }
        do { try await library.removeFromAlbum(ids, albumID: albumID) } catch { albumMirrorRefused = true }
    }

    /// Fresh install with an album already in Photos: adopt it and seed the list from its members.
    /// Also reconciles a hand-edited album: a member removed in Photos is un-archived (IA §8).
    func adoptArchiveAlbumIfNeeded() async {
        let hadList = !state.archive.isEmpty
        guard let albumID = await ensureAlbum() else { return }
        let members = Set(await library.albumMembers(albumID: albumID))
        if !hadList {
            let stamp = now()
            state.archive = members.map { ArchiveEntry(id: $0, archivedAt: stamp) }
            persist()
        } else if !albumMirrorRefused {
            // a member removed from the album by hand in Photos is un-archived (IA §8)
            let before = state.archive.count
            state.archive.removeAll { !members.contains($0.id) && screenshot($0.id) != nil }
            if state.archive.count != before { persist() }
        }
    }

    // MARK: - Helpers

    private func setFavoriteLocally(_ id: String, _ value: Bool) async {
        if let index = screenshots.firstIndex(where: { $0.id == id }) {
            let s = screenshots[index]
            screenshots[index] = Screenshot(id: s.id, creationDate: s.creationDate, pixelWidth: s.pixelWidth,
                                            pixelHeight: s.pixelHeight, isFavorite: value)
        }
        do { try await library.setFavorite(id, value) } catch { await refresh() }
    }

    private func pruneMissing() {
        let visible = Set(screenshots.map(\.id))
        let trashBefore = state.trash.count, archiveBefore = state.archive.count
        state.trash.removeAll { !visible.contains($0.id) }
        // archive entries for assets the app cannot see are kept: under limited access they may
        // simply be outside the selection, and the album still holds them
        if authorization == .authorized { state.archive.removeAll { !visible.contains($0.id) } }
        if state.trash.count != trashBefore || state.archive.count != archiveBefore { persist() }
    }

    private func persist() {
        do { try persistence.save(state) } catch { /* surfaced by the next load; nothing to do here */ }
    }
}
