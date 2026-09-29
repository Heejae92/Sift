import Foundation

/// How often the cleanup reminder comes back (ADR-034). The owner's request of 2026-09-29: a
/// reminder every 30 days that it is time to sift. It is one repeating local notification that
/// `ReminderScheduler` re-anchors each time a sift is finished, so it fires `intervalDays` after the
/// last finished sift, at the time of day the user sifted, and again every `intervalDays` if ignored.
/// Nothing is stored in the app for it: whether it is on, and when it fires next, are read back from
/// the pending request in iOS.
enum ReminderPolicy {
    /// The owner's number.
    static let intervalDays = 30

    /// When a repeating reminder added at `anchor` fires next, seen at `now`: the first of
    /// `anchor + interval`, `anchor + 2 × interval`, … that is later than `now`. A moment it fires at
    /// counts as passed, and a `now` before `anchor` (a clock set back) gives the first one.
    ///
    /// iOS does not keep this date. Asked for `nextTriggerDate()`, a pending repeating
    /// `UNTimeIntervalNotificationTrigger` answers `now + interval` at every reading: measured on the
    /// simulator on 2026-09-29, a 3600 s trigger read 3600.04 s ahead and, six seconds later,
    /// 3606.11 s after the moment it was added. So the scheduler writes the moment it adds the request
    /// into the request itself and asks this instead (ADR-034).
    static func nextDate(anchor: Date, interval: TimeInterval, now: Date) -> Date {
        guard interval > 0 else { return anchor }
        let fired = max(0, (now.timeIntervalSince(anchor) / interval).rounded(.down))
        return anchor.addingTimeInterval((fired + 1) * interval)
    }

    /// The interval the app schedules: `intervalDays` in plain seconds, the day of
    /// `ReviewPolicy.secondsPerDay`, unless a DEBUG simulator build was launched with
    /// `-SiftReminderSeconds <n>`.
    static let interval: TimeInterval = launchOverrideSeconds.map { TimeInterval($0) }
        ?? TimeInterval(intervalDays) * ReviewPolicy.secondsPerDay

    /// The shortest interval iOS accepts for a repeating time-interval trigger.
    static let minimumRepeatingSeconds = 60

    /// Read on a DEBUG simulator build only, so the reminder can be watched arriving within minutes
    /// (docs/DEVELOPMENT.md "Running on the simulator"). A release build and every build for a device
    /// ignore it, the same gate as `-SiftAllImages` and `-SiftMinimumAgeDays`. The scheme does not
    /// pass it.
    private static var launchOverrideSeconds: Int? {
        #if DEBUG && targetEnvironment(simulator)
        return overrideSeconds(in: ProcessInfo.processInfo.arguments)
        #else
        return nil
        #endif
    }

    /// The value after `-SiftReminderSeconds` in `arguments`, when it is a whole number of seconds,
    /// `minimumRepeatingSeconds` or more. A missing flag or value, a non-number, a number under 60 or
    /// one too large for `Int` gives nil, and the interval stays at `intervalDays`.
    static func overrideSeconds(in arguments: [String]) -> Int? {
        guard let flag = arguments.firstIndex(of: "-SiftReminderSeconds"), flag + 1 < arguments.count,
              let seconds = Int(arguments[flag + 1]), seconds >= minimumRepeatingSeconds else { return nil }
        return seconds
    }
}
