import Foundation

struct TrashEntry: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let trashedAt: Date
}

struct ArchiveEntry: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let archivedAt: Date
}

/// Everything the app persists (IA §7). Two lists, two scalars, a version. Nothing else.
struct StoreState: Codable, Sendable, Equatable {
    static let currentVersion = 1

    var version: Int = StoreState.currentVersion
    var trash: [TrashEntry] = []
    var archive: [ArchiveEntry] = []
    var archiveAlbumID: String? = nil
    /// Under limited access: the number of screenshots the user last dismissed the interstitial
    /// for (A2). `nil` means the interstitial has not been acknowledged since access became limited.
    var acknowledgedSelectionCount: Int? = nil

    func isTrashed(_ id: String) -> Bool { trash.contains { $0.id == id } }
    func isArchived(_ id: String) -> Bool { archive.contains { $0.id == id } }
}

protocol StorePersistence: Sendable {
    /// `nil` means no store exists yet — a fresh install (IA §7 recovery).
    func load() throws -> StoreState?
    func save(_ state: StoreState) throws
}

/// The production store: one JSON file, written atomically, in Application Support.
struct FileStorePersistence: StorePersistence {
    let url: URL

    static func applicationSupport(fileManager: FileManager = .default) throws -> FileStorePersistence {
        let base = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                       appropriateFor: nil, create: true)
        let dir = base.appendingPathComponent(Bundle.main.bundleIdentifier ?? "app", isDirectory: true)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return FileStorePersistence(url: dir.appendingPathComponent("store.json"))
    }

    func load() throws -> StoreState? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(StoreState.self, from: data)
    }

    func save(_ state: StoreState) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: url, options: .atomic)
    }
}

/// Test double. A class so tests can inspect what was saved; the lock keeps it `Sendable`.
final class InMemoryPersistence: StorePersistence, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: StoreState?
    private(set) var saveCount = 0

    init(initial: StoreState? = nil) { stored = initial }

    func load() throws -> StoreState? { lock.withLock { stored } }
    func save(_ state: StoreState) throws { lock.withLock { stored = state; saveCount += 1 } }
    var current: StoreState? { lock.withLock { stored } }
}
