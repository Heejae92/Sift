import Foundation
import Testing
@testable import Sift

/// The pure functions behind what Review shows (ADR-032): the all-done body and the header counter.
@MainActor
struct ReviewPresentationTests {
    /// Each body line stands on its own, and a block with neither has no body. The date is pinned to
    /// `en_US` and one time zone.
    @Test func allDoneBodyPutsEachLineOnItsOwn() throws {
        let day = try Date("2026-10-12T12:00:00Z", strategy: .iso8601)
        let english = Locale(identifier: "en_US")
        let zone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt
        func body(_ trashCount: Int, _ nextArrival: Date?) -> String? {
            EmptyState.allDoneBody(trashCount: trashCount, nextArrival: nextArrival, locale: english, timeZone: zone)
        }
        #expect(body(0, nil) == nil)
        #expect(body(27, nil) == "Trash is holding 27 — empty it whenever.")
        #expect(body(0, day) == "Next screenshot: Oct 12.")
        #expect(body(27, day) == "Trash is holding 27 — empty it whenever.\nNext screenshot: Oct 12.")
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
