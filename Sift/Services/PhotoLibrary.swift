import Foundation

enum PhotoAuthorization: Sendable, Equatable {
    case notDetermined, restricted, denied, limited, authorized

    /// The app can read something.
    var isUsable: Bool { self == .limited || self == .authorized }
}

enum PhotoLibraryError: Error, Sendable, Equatable {
    /// The user cancelled the iOS delete dialog (ADR-009).
    case cancelled
    /// PhotoKit refused a write to the mirror album, typically under limited access (A4).
    case albumWriteRefused
    case failed(String)
}

/// Everything the app asks of Photos (ARCHITECTURE §4). Async only, `Sendable`, no PhotoKit type
/// in any signature, so `PhotoKitLibrary` and the test fake are interchangeable.
protocol PhotoLibrary: Sendable {
    func authorizationStatus() async -> PhotoAuthorization
    func requestAuthorization() async -> PhotoAuthorization
    /// Every screenshot the app can see, in any order; the catalog sorts.
    func fetchScreenshots() async -> [Screenshot]
    /// Yields whenever the library changes. The catalog re-fetches on every value.
    func changes() -> AsyncStream<Void>
    func setFavorite(_ id: String, _ value: Bool) async throws
    /// Returns the album's identifier: the existing one if it still exists, an album with that title
    /// if one does, otherwise a newly created one.
    func ensureArchiveAlbum(existingID: String?, title: String) async throws -> String
    func albumMembers(albumID: String) async -> [String]
    func addToAlbum(_ ids: [String], albumID: String) async throws
    func removeFromAlbum(_ ids: [String], albumID: String) async throws
    /// Presents the iOS confirmation. Throws `.cancelled` when the user declines.
    func delete(_ ids: [String]) async throws
    func fileSizeBytes(for id: String) async -> Int64?
}
