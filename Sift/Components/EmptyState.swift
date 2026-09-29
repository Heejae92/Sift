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
/// then one date. While the cleanup reminder is on the date is the next reminder's (ADR-034);
/// otherwise it is the day the next waiting screenshot comes due, when one waits (ADR-032).
///
/// `primaryAction` becomes the block's one filled action where the state has one: "Open Trash (N)"
/// on `allDone` when N > 0, and "Keep sifting" on `trashEmpty`. The other three states have no
/// action and ignore it. `allDone` also has the reminder's bare-text action, handed to
/// `reminderAction` (P-19, ADR-023): "Remind me every 30 days" while the reminder is off, "Turn on
/// reminders in Settings" once notifications are declined, and none while it is on or not read yet.
/// The face is hidden from VoiceOver; the headline is the element that speaks for the block, and each
/// action is a button with its own label.
struct EmptyState: View {
    enum Kind: Equatable {
        case noScreenshots
        /// `nextArrival` is `Catalog.nextArrival`: nil when no screenshot is waiting. `reminder` is
        /// `ReviewModel.reminder`: nil until it has been read (ADR-034).
        case allDone(trashCount: Int, nextArrival: Date?, reminder: ReminderStatus?)
        case trashEmpty
        case noFavorites
        case noArchived
    }

    /// The all-done block's bare-text action, which belongs to the cleanup reminder (ADR-034).
    enum ReminderAction: Equatable {
        /// The reminder is off: iOS asks for notifications if it never has, then it is scheduled.
        case remindMe
        /// Notifications were declined, and only Settings can turn them back on.
        case openSettings

        var title: String {
            switch self {
            // The reminder's own number, not a literal (P-12).
            case .remindMe:     return "Remind me every \(ReminderPolicy.intervalDays) days"
            case .openSettings: return "Turn on reminders in Settings"
            }
        }
    }

    /// What the all-done block offers: at most one filled action, and at most one bare-text action
    /// beside it (P-19, ADR-023).
    struct AllDoneActions: Equatable {
        /// The filled CTA.
        let cta: String?
        /// The bare-text action.
        let reminder: ReminderAction?
    }

    private let kind: Kind
    private let primaryAction: (() -> Void)?
    private let reminderAction: ((ReminderAction) -> Void)?

    init(_ kind: Kind, primaryAction: (() -> Void)? = nil, reminderAction: ((ReminderAction) -> Void)? = nil) {
        self.kind = kind
        self.primaryAction = primaryAction
        self.reminderAction = reminderAction
    }

    var body: some View {
        let cta = primaryAction == nil ? nil : ctaTitle
        let text = reminderAction == nil ? nil : textAction
        if cta == nil, text == nil {
            BlockView(block, headline: headline, body: bodyText) {
                EmptyView()
            }
        } else {
            BlockView(block, headline: headline, body: bodyText) {
                if let cta, let primaryAction {
                    DSButton(cta, kind: .blockCTA(block), action: primaryAction)
                }
                if let text, let reminderAction {
                    DSButton(text.title, kind: .blockText(block)) { reminderAction(text) }
                }
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
        guard case .allDone(let trashCount, let nextArrival, let reminder) = kind else { return nil }
        return Self.allDoneBody(trashCount: trashCount, nextArrival: nextArrival, reminder: reminder)
    }

    /// The all-done body (§11.2, ADR-032, ADR-034): the Trash line when Trash holds anything, then one
    /// date line, "Next reminder: Nov 28." while the reminder is on, otherwise "Next screenshot:
    /// Oct 12." when a screenshot is waiting. Each on its own line; nil when neither applies. Dates
    /// are `arrivalDay`, in `locale` and `timeZone`.
    static func allDoneBody(trashCount: Int, nextArrival: Date?, reminder: ReminderStatus?,
                            locale: Locale = .autoupdatingCurrent,
                            timeZone: TimeZone = .autoupdatingCurrent) -> String? {
        var lines: [String] = []
        if trashCount > 0 { lines.append("Trash is holding \(trashCount) — empty it whenever.") }
        if case .on(let next) = reminder {
            lines.append("Next reminder: \(arrivalDay(next, locale: locale, timeZone: timeZone)).")
        } else if let nextArrival {
            lines.append("Next screenshot: \(arrivalDay(nextArrival, locale: locale, timeZone: timeZone)).")
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    /// The all-done actions (§11.2, ADR-023, ADR-034): "Open Trash (N)" filled when Trash holds
    /// anything, and the reminder's bare-text action while the reminder is off or declined. While it
    /// is on, or not read yet, there is no reminder action, so with Trash empty the block has none.
    static func allDoneActions(trashCount: Int, reminder: ReminderStatus?) -> AllDoneActions {
        let text: ReminderAction?
        switch reminder {
        case .some(.off):       text = .remindMe
        case .some(.denied):    text = .openSettings
        case .some(.on), .none: text = nil
        }
        return AllDoneActions(cta: trashCount > 0 ? "Open Trash (\(trashCount))" : nil, reminder: text)
    }

    /// A day as the copy names it: "Oct 12", a `Date.FormatStyle` with the month abbreviated and the
    /// day, in `locale` and `timeZone`. The day a waiting screenshot comes due here and on the
    /// limited-access interstitial (ADR-033), and the next reminder's day (ADR-034), so they never drift.
    static func arrivalDay(_ date: Date, locale: Locale = .autoupdatingCurrent,
                           timeZone: TimeZone = .autoupdatingCurrent) -> String {
        date.formatted(Date.FormatStyle(locale: locale, timeZone: timeZone).month(.abbreviated).day())
    }

    private var ctaTitle: String? {
        switch kind {
        case .allDone(let trashCount, _, let reminder):
            return Self.allDoneActions(trashCount: trashCount, reminder: reminder).cta
        case .trashEmpty:
            // The product name is a verb in the copy (§12), so it comes from `Brand` (P-11, ADR-002).
            return "Keep \(Brand.name.lowercased())ing"
        case .noScreenshots, .noFavorites, .noArchived:
            return nil
        }
    }

    private var textAction: ReminderAction? {
        guard case .allDone(let trashCount, _, let reminder) = kind else { return nil }
        return Self.allDoneActions(trashCount: trashCount, reminder: reminder).reminder
    }
}
