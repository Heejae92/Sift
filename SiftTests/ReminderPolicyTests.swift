import Foundation
import Testing
@testable import Sift

/// ADR-034: `-SiftReminderSeconds` counts only as a whole number of seconds, 60 or more, the shortest
/// repeating interval iOS accepts; anything else leaves the reminder at 30 days.
struct ReminderPolicyTests {
    @Test func overrideSecondsReadsOnlyAWholeNumberFromSixty() {
        let flag = "-SiftReminderSeconds"
        #expect(ReminderPolicy.overrideSeconds(in: ["app", flag, "60"]) == 60)
        #expect(ReminderPolicy.overrideSeconds(in: ["app", "-SiftAllImages", flag, "3600"]) == 3600)
        #expect(ReminderPolicy.overrideSeconds(in: ["app", "-SiftAllImages"]) == nil)              // missing
        #expect(ReminderPolicy.overrideSeconds(in: ["app", flag]) == nil)                          // no value
        #expect(ReminderPolicy.overrideSeconds(in: ["app", flag, "ninety"]) == nil)                // not a number
        #expect(ReminderPolicy.overrideSeconds(in: ["app", flag, "90.5"]) == nil)                  // not whole
        #expect(ReminderPolicy.overrideSeconds(in: ["app", flag, "59"]) == nil)                    // under 60
        #expect(ReminderPolicy.overrideSeconds(in: ["app", flag, "-60"]) == nil)                   // negative
        #expect(ReminderPolicy.overrideSeconds(in: ["app", flag, "99999999999999999999"]) == nil)  // overflows Int
    }

    /// The next reminder is a whole number of intervals after the moment it was added: the first one
    /// until it fires, then the one after, and after an ignored one the next in the series.
    @Test func nextDateCountsWholeIntervalsFromTheAnchor() {
        let anchor = Date(timeIntervalSince1970: Fixtures.clockStart)
        let interval = 30 * Fixtures.day
        func next(after days: Double) -> Date {
            ReminderPolicy.nextDate(anchor: anchor, interval: interval, now: anchor.addingTimeInterval(days * Fixtures.day))
        }
        #expect(next(after: 0) == anchor.addingTimeInterval(interval))
        #expect(next(after: 29) == anchor.addingTimeInterval(interval))
        #expect(next(after: 30) == anchor.addingTimeInterval(2 * interval))       // fired at that moment
        #expect(next(after: 45) == anchor.addingTimeInterval(2 * interval))       // ignored once
        #expect(next(after: 95) == anchor.addingTimeInterval(4 * interval))
        #expect(next(after: -1) == anchor.addingTimeInterval(interval))           // a clock set back
    }
}
