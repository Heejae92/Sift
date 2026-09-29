import Foundation
import Testing
@testable import Sift

/// The pure functions behind what Review shows (ADR-032, ADR-034): the all-done body and actions, and
/// the header counter.
@MainActor
struct ReviewPresentationTests {
    /// Dates are pinned to `en_US` and one time zone.
    private let english = Locale(identifier: "en_US")
    private let zone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt

    private func body(_ trashCount: Int, _ nextArrival: Date?, _ reminder: ReminderStatus? = .off) -> String? {
        EmptyState.allDoneBody(trashCount: trashCount, nextArrival: nextArrival, reminder: reminder,
                               locale: english, timeZone: zone)
    }

    /// Each body line stands on its own, and a block with neither has no body.
    @Test func allDoneBodyPutsEachLineOnItsOwn() throws {
        let day = try Date("2026-10-12T12:00:00Z", strategy: .iso8601)
        #expect(body(0, nil) == nil)
        #expect(body(27, nil) == "Trash is holding 27 — empty it whenever.")
        #expect(body(0, day) == "Next screenshot: Oct 12.")
        #expect(body(27, day) == "Trash is holding 27 — empty it whenever.\nNext screenshot: Oct 12.")
    }

    /// While the reminder is on, its date takes the date line, whether or not a screenshot waits. Off,
    /// declined or not read yet, the line is the next screenshot's, as before (ADR-034).
    @Test func theReminderDateReplacesTheNextScreenshotLine() throws {
        let day = try Date("2026-10-12T12:00:00Z", strategy: .iso8601)
        let on = ReminderStatus.on(next: try Date("2026-11-28T20:00:00Z", strategy: .iso8601))
        #expect(body(0, nil, on) == "Next reminder: Nov 28.")
        #expect(body(0, day, on) == "Next reminder: Nov 28.")
        #expect(body(27, day, on) == "Trash is holding 27 — empty it whenever.\nNext reminder: Nov 28.")
        #expect(body(27, day, .denied) == "Trash is holding 27 — empty it whenever.\nNext screenshot: Oct 12.")
        #expect(body(0, day, nil) == "Next screenshot: Oct 12.")
        #expect(body(0, nil, .denied) == nil)
    }

    /// The three reminder variants of the block. "Open Trash (N)" stays the one filled action while
    /// Trash holds anything; the reminder's action is bare text: "Remind me" while off, Settings once
    /// declined, none while on or not read yet (ADR-023, ADR-034).
    @Test func allDoneActionsFollowTheReminder() {
        typealias Actions = EmptyState.AllDoneActions
        let on = ReminderStatus.on(next: Date(timeIntervalSince1970: Fixtures.clockStart))
        func actions(_ trashCount: Int, _ reminder: ReminderStatus?) -> Actions {
            EmptyState.allDoneActions(trashCount: trashCount, reminder: reminder)
        }
        #expect(actions(27, .off) == Actions(cta: "Open Trash (27)", reminder: .remindMe))
        #expect(actions(0, .off) == Actions(cta: nil, reminder: .remindMe))
        #expect(actions(27, .denied) == Actions(cta: "Open Trash (27)", reminder: .openSettings))
        #expect(actions(0, .denied) == Actions(cta: nil, reminder: .openSettings))
        #expect(actions(27, on) == Actions(cta: "Open Trash (27)", reminder: nil))
        #expect(actions(0, on) == Actions(cta: nil, reminder: nil))
        #expect(actions(27, nil) == Actions(cta: "Open Trash (27)", reminder: nil))
        #expect(EmptyState.ReminderAction.remindMe.title == "Remind me every 30 days")
        #expect(EmptyState.ReminderAction.openSettings.title == "Turn on reminders in Settings")
    }

    /// The header counts only while something is due and a card is up: never "0 / 0".
    @Test func counterShowsACountOnlyWhenSomethingIsDue() {
        #expect(ReviewScreen.counterPhase(nil, position: 1, total: 1) == .loading)
        #expect(ReviewScreen.counterPhase(.loading, position: 1, total: 1) == .loading)
        #expect(ReviewScreen.counterPhase(.reviewing, position: 12, total: 340) == .counting(position: 12, total: 340))
        #expect(ReviewScreen.counterPhase(.dragging, position: .zero, total: .zero) == .done)
        #expect(ReviewScreen.counterPhase(.allDone, position: .zero, total: .zero) == .done)
        #expect(ReviewScreen.counterPhase(.allDone, position: 6, total: 6) == .done)
        #expect(ReviewScreen.counterPhase(.noScreenshots, position: .zero, total: .zero) == .done)
    }
}
