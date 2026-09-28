import Foundation

/// When a screenshot is due for review (ADR-032, IA §1 rule 2). The owner's rule of 2026-09-28:
/// Review asks only about screenshots taken at least `minimumAgeDays` days ago. A newer one, such as
/// yesterday's ticket, is probably still in use, so it waits outside the queue and joins it by
/// itself once it is old enough. Nothing is stored for it: `Catalog` compares each `creationDate`
/// with its reference date.
enum ReviewPolicy {
    /// The owner's number.
    static let minimumAgeDays = 30

    /// A day as plain seconds. The rule uses no `Calendar`, so the threshold does not move with a
    /// time zone or a daylight-saving change, and a test can hit it to the second.
    static let secondsPerDay: TimeInterval = 86_400

    /// The age the app runs with: `minimumAgeDays`, unless a DEBUG simulator build was launched with
    /// `-SiftMinimumAgeDays <n>`, a whole number of days, 0 or more.
    static let minimumAge: TimeInterval = TimeInterval(launchOverrideDays ?? minimumAgeDays) * secondsPerDay

    /// Read on a DEBUG simulator build only, where the seeded images are recent and would otherwise
    /// wait a month (README "Running on the simulator"). A release build and every build for a device
    /// ignore it, the same gate as `-SiftAllImages` (ADR-027). The scheme does not pass it, so a
    /// simulator shows the real rule unless someone asks otherwise.
    private static var launchOverrideDays: Int? {
        #if DEBUG && targetEnvironment(simulator)
        return overrideDays(in: ProcessInfo.processInfo.arguments)
        #else
        return nil
        #endif
    }

    /// The value after `-SiftMinimumAgeDays` in `arguments`, when it is a whole number of days, 0 or
    /// more. A missing flag or value, a non-number, a negative number or one too large for `Int`
    /// gives nil, and the rule stays at `minimumAgeDays`.
    static func overrideDays(in arguments: [String]) -> Int? {
        guard let flag = arguments.firstIndex(of: "-SiftMinimumAgeDays"), flag + 1 < arguments.count,
              let days = Int(arguments[flag + 1]), days >= 0 else { return nil }
        return days
    }
}
