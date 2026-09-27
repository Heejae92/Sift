import Foundation

/// The three piles. Not a stored field: a verdict is which membership a screenshot holds (IA §1).
enum Verdict: String, Codable, Sendable, CaseIterable {
    case trash, archive, fave
}

enum LibrarySegment: Sendable, CaseIterable {
    case favorites, archive
}

/// What `Catalog.rewind` needs to undo the last commit exactly (ADR-008): the screenshot, the
/// verdict, and the flags that were true before it. Verdicts only ever come from the queue, so the
/// prior flags are false in practice; recording them keeps the undo honest if that ever changes.
struct RewindEntry: Sendable, Equatable {
    let id: String
    let verdict: Verdict
    let wasFavorite: Bool
    let wasArchived: Bool
}

/// Outcome of a permanent deletion, which always goes through the iOS dialog (ADR-009).
enum PurgeResult: Sendable, Equatable {
    case deleted(count: Int)
    case cancelled
    case failed(remaining: Int)
}
