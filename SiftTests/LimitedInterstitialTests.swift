import Foundation
import Testing
@testable import Sift

/// ADR-033: the limited-access interstitial says when some picked screenshots wait, and its CTA
/// counts what can be sifted now. English copy, so the date is pinned to `en_US` and one time zone.
@MainActor
struct LimitedInterstitialTests {
    private typealias Copy = LimitedInterstitial.Copy
    private let name = Brand.name
    private let pickMore = Copy.Button(title: "Pick more", action: .pickMore)
    /// 2026-10-27 12:00 UTC: Oct 27 in the pinned time zone.
    private let day = Date(timeIntervalSince1970: 1_793_102_400)

    private func copy(picked: Int, ready: Int, waiting: Int, nextArrival: Date? = nil,
                      waitDays: Int = ReviewPolicy.minimumAgeDays) -> Copy {
        LimitedInterstitial.copy(picked: picked, ready: ready, waiting: waiting, nextArrival: nextArrival,
                                 waitDays: waitDays, locale: Locale(identifier: "en_US"),
                                 timeZone: TimeZone(identifier: "America/Los_Angeles") ?? .gmt)
    }

    private func acknowledge(_ title: String) -> Copy.Button { .init(title: title, action: .acknowledge) }

    /// Nothing waiting: the block is what it was before ADR-033, and the CTA counts everything picked.
    @Test func nothingWaitingIsUnchanged() {
        #expect(copy(picked: 14, ready: 14, waiting: 0)
                == Copy(headline: "You picked 14 screenshots. \(name) only sees those.", body: nil,
                        primary: acknowledge("\(name) these 14"), secondary: pickMore))
        #expect(copy(picked: 1, ready: 1, waiting: 0)
                == Copy(headline: "You picked 1 screenshot. \(name) only sees that one.", body: nil,
                        primary: acknowledge("\(name) this one"), secondary: pickMore))
    }

    /// Some waiting, some ready: one line says so, and the CTA counts the ready ones. No date, even
    /// when one is known.
    @Test func someReadyCountsTheReadyOnes() {
        #expect(copy(picked: 14, ready: 3, waiting: 11, nextArrival: day)
                == Copy(headline: "You picked 14 screenshots. \(name) only sees those.",
                        body: "Screenshots wait 30 days before \(name) asks. 3 are ready now.",
                        primary: acknowledge("\(name) these 3"), secondary: pickMore))
        #expect(copy(picked: 5, ready: 1, waiting: 4, nextArrival: day)
                == Copy(headline: "You picked 5 screenshots. \(name) only sees those.",
                        body: "Screenshots wait 30 days before \(name) asks. 1 is ready now.",
                        primary: acknowledge("\(name) this one"), secondary: pickMore))
    }

    /// None ready: the line ends on the day the first one comes due, "It's ready" when only one
    /// waits, and the CTA only moves on.
    @Test func noneReadyNamesTheDay() {
        #expect(copy(picked: 2, ready: 0, waiting: 2, nextArrival: day)
                == Copy(headline: "You picked 2 screenshots. \(name) only sees those.",
                        body: "Screenshots wait 30 days before \(name) asks. The first is ready Oct 27.",
                        primary: acknowledge("Continue"), secondary: pickMore))
        #expect(copy(picked: 1, ready: 0, waiting: 1, nextArrival: day)
                == Copy(headline: "You picked 1 screenshot. \(name) only sees that one.",
                        body: "Screenshots wait 30 days before \(name) asks. It's ready Oct 27.",
                        primary: acknowledge("Continue"), secondary: pickMore))
    }

    /// Nothing picked is a screenshot: the block says so, picking more takes the fill, and "Continue"
    /// is the bare-text action. Still one filled action.
    @Test func noScreenshotsPickedPutsPickMoreFirst() {
        #expect(copy(picked: 0, ready: 0, waiting: 0)
                == Copy(headline: "None of these are screenshots.", body: nil,
                        primary: pickMore, secondary: acknowledge("Continue")))
    }

    /// The wait is the catalog's rule, so a simulator override of one day reads in the singular.
    @Test func aOneDayWaitIsSingular() {
        #expect(copy(picked: 3, ready: 2, waiting: 1, waitDays: 1).body
                == "Screenshots wait 1 day before \(name) asks. 2 are ready now.")
    }
}
