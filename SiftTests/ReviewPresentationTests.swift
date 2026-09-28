import Foundation
import Testing
@testable import Sift

/// The pure functions behind what Review shows (ADR-032): the all-done body and the header counter.
@MainActor
struct ReviewPresentationTests {
    /// Each body line stands on its own, and a block with neither has no body.
    @Test func allDoneBodyPutsEachLineOnItsOwn() throws {
        let day = try Date("2026-10-12T12:00:00Z", strategy: .iso8601)
        let english = Locale(identifier: "en_US")
        #expect(EmptyState.allDoneBody(trashCount: 0, nextArrival: nil, locale: english) == nil)
        #expect(EmptyState.allDoneBody(trashCount: 27, nextArrival: nil, locale: english)
                == "Trash is holding 27 — empty it whenever.")
        #expect(EmptyState.allDoneBody(trashCount: 0, nextArrival: day, locale: english)
                == "Next screenshot: Oct 12.")
        #expect(EmptyState.allDoneBody(trashCount: 27, nextArrival: day, locale: english)
                == "Trash is holding 27 — empty it whenever.\nNext screenshot: Oct 12.")
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
