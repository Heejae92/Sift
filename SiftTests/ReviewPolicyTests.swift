import Foundation
import Testing
@testable import Sift

/// ADR-032: `-SiftMinimumAgeDays` counts only as a whole number of days, 0 or more; anything else
/// leaves the rule at 30 days.
struct ReviewPolicyTests {
    @Test func overrideDaysReadsOnlyAWholeNumberOfDays() {
        let flag = "-SiftMinimumAgeDays"
        #expect(ReviewPolicy.overrideDays(in: ["app", flag, "0"]) == 0)
        #expect(ReviewPolicy.overrideDays(in: ["app", "-SiftAllImages", flag, "7"]) == 7)
        #expect(ReviewPolicy.overrideDays(in: ["app", "-SiftAllImages"]) == nil)             // missing
        #expect(ReviewPolicy.overrideDays(in: ["app", flag]) == nil)                         // no value
        #expect(ReviewPolicy.overrideDays(in: ["app", flag, "ten"]) == nil)                  // not a number
        #expect(ReviewPolicy.overrideDays(in: ["app", flag, "1.5"]) == nil)                  // not whole
        #expect(ReviewPolicy.overrideDays(in: ["app", flag, "-1"]) == nil)                   // negative
        #expect(ReviewPolicy.overrideDays(in: ["app", flag, "99999999999999999999"]) == nil) // overflows Int
    }
}
