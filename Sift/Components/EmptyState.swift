import SwiftUI

/// UI_DESIGN §10 "EmptyState": five states and no others, each a full-bleed `BlockView` with the
/// copy of §11 and §12. Blocks come from §10: `allDone` → `DSBlock.allDone`, `trashEmpty` →
/// `DSBlock.trashEmpty`, `noFavorites` → `DSBlock.favoritesEmpty`, `noArchived` →
/// `DSBlock.archiveEmpty`.
///
/// `noScreenshots` has no `DSBlock` of its own (UI_DESIGN §15, open question 5). Until the design
/// system decides, it borrows `DSBlock.allDone`, the other Review state, so both ends of the queue
/// look the same and only the headline differs.
///
/// `allDone` has up to two body lines, each on its own: the Trash count when Trash holds anything,
/// and the day the next waiting screenshot comes due when one waits (ADR-032).
///
/// `primaryAction` becomes the block's one filled action where the state has one: "Open Trash (N)"
/// on `allDone` when N > 0, and "Keep sifting" on `trashEmpty`. The other three states have no
/// action and ignore it. The face is hidden from VoiceOver; the headline is the element that
/// speaks for the block, and the CTA is a button with its own label.
struct EmptyState: View {
    enum Kind: Equatable {
        case noScreenshots
        /// `nextArrival` is `Catalog.nextArrival`: nil when no screenshot is waiting.
        case allDone(trashCount: Int, nextArrival: Date?)
        case trashEmpty
        case noFavorites
        case noArchived
    }

    private let kind: Kind
    private let primaryAction: (() -> Void)?

    init(_ kind: Kind, primaryAction: (() -> Void)? = nil) {
        self.kind = kind
        self.primaryAction = primaryAction
    }

    var body: some View {
        if let ctaTitle, let primaryAction {
            BlockView(block, headline: headline, body: bodyText) {
                DSButton(ctaTitle, kind: .blockCTA(block), action: primaryAction)
            }
        } else {
            BlockView(block, headline: headline, body: bodyText) {
                EmptyView()
            }
        }
    }

    // MARK: - State → block and copy

    private var block: DSBlock {
        switch kind {
        case .noScreenshots: return .allDone
        case .allDone:       return .allDone
        case .trashEmpty:    return .trashEmpty
        case .noFavorites:   return .favoritesEmpty
        case .noArchived:    return .archiveEmpty
        }
    }

    private var headline: String {
        switch kind {
        case .noScreenshots: return "No screenshots. Honestly, impressive."
        case .allDone:       return "Inbox zero, screenshot edition."
        case .trashEmpty:    return "Trash is empty. Squeaky."
        case .noFavorites:   return "No faves yet. Swipe up on the good ones."
        case .noArchived:    return "Nothing archived. Swipe right to stash keepers."
        }
    }

    private var bodyText: String? {
        guard case .allDone(let trashCount, let nextArrival) = kind else { return nil }
        return Self.allDoneBody(trashCount: trashCount, nextArrival: nextArrival)
    }

    /// The all-done body (§11.2, ADR-032): the Trash line when Trash holds anything, then
    /// "Next screenshot: Oct 12." when a screenshot is waiting, each on its own line; nil when neither
    /// applies. The date is a `Date.FormatStyle`, month abbreviated and day, in `locale`.
    static func allDoneBody(trashCount: Int, nextArrival: Date?, locale: Locale = .autoupdatingCurrent) -> String? {
        var lines: [String] = []
        if trashCount > 0 { lines.append("Trash is holding \(trashCount) — empty it whenever.") }
        if let nextArrival {
            lines.append("Next screenshot: \(nextArrival.formatted(.dateTime.month(.abbreviated).day().locale(locale))).")
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    private var ctaTitle: String? {
        switch kind {
        case .allDone(let trashCount, _):
            return trashCount > 0 ? "Open Trash (\(trashCount))" : nil
        case .trashEmpty:
            // The product name is a verb in the copy (§12), so it comes from `Brand` (P-11, ADR-002).
            return "Keep \(Brand.name.lowercased())ing"
        case .noScreenshots, .noFavorites, .noArchived:
            return nil
        }
    }
}
