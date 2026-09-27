import Foundation
@testable import Sift

/// In-memory stand-in for Photos. An actor, so it is `Sendable` without locks.
actor FakePhotoLibrary: PhotoLibrary {
    enum DeleteBehavior { case succeed, cancel, fail }

    var status: PhotoAuthorization
    var shots: [Screenshot]
    var albums: [String: (title: String, members: [String])] = [:]
    var deletedIDs: [String] = []
    var deleteBehavior: DeleteBehavior = .succeed
    var refuseAlbumWrites = false
    var favoriteWrites: [(id: String, value: Bool)] = []
    private var continuations: [AsyncStream<Void>.Continuation] = []
    private var albumCounter = 0

    init(status: PhotoAuthorization = .authorized, shots: [Screenshot] = []) {
        self.status = status
        self.shots = shots
    }

    // MARK: test controls

    func set(status: PhotoAuthorization) { self.status = status }
    func set(shots: [Screenshot]) { self.shots = shots }
    func add(_ shot: Screenshot) { shots.append(shot) }
    func remove(_ id: String) { shots.removeAll { $0.id == id } }
    func setFavoriteFlag(_ id: String, _ value: Bool) {
        guard let i = shots.firstIndex(where: { $0.id == id }) else { return }
        let s = shots[i]
        shots[i] = Screenshot(id: s.id, creationDate: s.creationDate, pixelWidth: s.pixelWidth, pixelHeight: s.pixelHeight, isFavorite: value)
    }
    func set(deleteBehavior: DeleteBehavior) { self.deleteBehavior = deleteBehavior }
    func set(refuseAlbumWrites: Bool) { self.refuseAlbumWrites = refuseAlbumWrites }
    @discardableResult
    func seedAlbum(title: String, members: [String]) -> String {
        albumCounter += 1
        let id = "album-\(albumCounter)"
        albums[id] = (title, members)
        return id
    }
    func members(of albumID: String) -> [String] { albums[albumID]?.members ?? [] }
    func deleteAlbum(_ albumID: String) { albums[albumID] = nil }
    func emitChange() { for c in continuations { c.yield() } }

    // MARK: PhotoLibrary

    func authorizationStatus() async -> PhotoAuthorization { status }
    func requestAuthorization() async -> PhotoAuthorization {
        if status == .notDetermined { status = .authorized }
        return status
    }
    func fetchScreenshots() async -> [Screenshot] { shots.shuffled() }

    nonisolated func changes() -> AsyncStream<Void> {
        AsyncStream { continuation in
            Task { await self.register(continuation) }
        }
    }
    private func register(_ c: AsyncStream<Void>.Continuation) { continuations.append(c) }

    func setFavorite(_ id: String, _ value: Bool) async throws {
        favoriteWrites.append((id, value))
        setFavoriteFlag(id, value)
    }

    func ensureArchiveAlbum(existingID: String?, title: String) async throws -> String {
        if let existingID, albums[existingID] != nil { return existingID }
        if let found = albums.first(where: { $0.value.title == title }) { return found.key }
        if refuseAlbumWrites { throw PhotoLibraryError.albumWriteRefused }
        return seedAlbum(title: title, members: [])
    }

    func albumMembers(albumID: String) async -> [String] { albums[albumID]?.members ?? [] }

    func addToAlbum(_ ids: [String], albumID: String) async throws {
        if refuseAlbumWrites { throw PhotoLibraryError.albumWriteRefused }
        guard var album = albums[albumID] else { return }
        album.members.append(contentsOf: ids.filter { !album.members.contains($0) })
        albums[albumID] = album
    }

    func removeFromAlbum(_ ids: [String], albumID: String) async throws {
        if refuseAlbumWrites { throw PhotoLibraryError.albumWriteRefused }
        guard var album = albums[albumID] else { return }
        album.members.removeAll { ids.contains($0) }
        albums[albumID] = album
    }

    func delete(_ ids: [String]) async throws {
        switch deleteBehavior {
        case .cancel: throw PhotoLibraryError.cancelled
        case .fail: throw PhotoLibraryError.failed("simulated")
        case .succeed:
            deletedIDs.append(contentsOf: ids)
            shots.removeAll { ids.contains($0.id) }
        }
    }

    func fileSizeBytes(for id: String) async -> Int64? { nil }
}

enum Fixtures {
    /// A fixed moment in the past (2023-11-14) so fixtures never sort against the wall clock.
    static let base: TimeInterval = 1_700_000_000
    /// A screenshot taken after every fixture: the newest of all.
    static func newer(_ id: String) -> Screenshot {
        Screenshot(id: id, creationDate: Date(timeIntervalSince1970: base + 60), pixelWidth: 1179, pixelHeight: 2556, isFavorite: false)
    }

    /// `count` screenshots, newest first: id "s1" is the newest.
    static func shots(_ count: Int, favorite: Set<String> = []) -> [Screenshot] {
        (1...count).map { i in
            Screenshot(id: "s\(i)", creationDate: Date(timeIntervalSince1970: base - Double(i) * 3600),
                       pixelWidth: 1179, pixelHeight: 2556, isFavorite: favorite.contains("s\(i)"))
        }
    }
}
