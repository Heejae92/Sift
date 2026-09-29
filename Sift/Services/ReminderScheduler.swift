import Foundation
import UserNotifications

/// The cleanup reminder as iOS reports it (ADR-034). The app stores nothing for it: on is notification
/// authorization plus a pending request, and the next date comes from that request, the moment it was
/// added and its trigger's interval.
enum ReminderStatus: Sendable, Equatable {
    /// Nothing is scheduled. Notifications are allowed or have not been asked for yet, so the all-done
    /// block offers to turn the reminder on.
    case off
    /// Scheduled; `next` is when it fires next.
    case on(next: Date)
    /// Notifications were declined, or are allowed with alerts, the lock screen and Notification Center
    /// all switched off, so nothing would show. iOS never asks twice: only Settings can fix either.
    case denied
}

/// The one cleanup reminder (ADR-034, ARCHITECTURE §4). Async only, `Sendable`, no UserNotifications
/// type in any signature, so `UserNotificationsReminderScheduler` and the test fake are
/// interchangeable.
protocol ReminderScheduler: Sendable {
    /// Reads authorization, the notification settings and the pending request. Never asks for
    /// permission.
    func status() async -> ReminderStatus
    /// Asks for alerts and sound when iOS has never asked (ADR-010: on a tap, never at launch), then
    /// schedules the reminder `ReminderPolicy.interval` from now. Returns what iOS reports afterwards.
    func enable() async -> ReminderStatus
    /// A finished sift: moves a scheduled reminder to a full interval from now. Does nothing while the
    /// reminder is off or denied.
    func reanchor() async
}

/// The UserNotifications implementation of `ReminderScheduler`, isolated the way `PhotoKitLibrary`
/// isolates PhotoKit: no stored state, every call goes to the current notification center, and only
/// `ReminderStatus` values come back out.
///
/// The reminder is one request, `identifier`, with a repeating `UNTimeIntervalNotificationTrigger`
/// of `ReminderPolicy.interval`. Adding a request replaces the pending one with the same identifier
/// (`UNUserNotificationCenter.h`), so scheduling again is the re-anchor: the old request goes, the
/// new one counts a full interval from now. The moment it was added rides in its `userInfo`, because
/// the trigger's own `nextTriggerDate()` only ever answers "an interval from now"
/// (`ReminderPolicy.nextDate`). The app sets no notification-center delegate, so a reminder that fires
/// while the app is open is not shown, and tapping one simply opens the app.
final class UserNotificationsReminderScheduler: ReminderScheduler {
    /// Not copy: it stays the same across a rename (ADR-002), so a pending reminder is always found.
    static let identifier = "sift.reminder"
    /// §12. The product name is the verb, as in "Keep sifting", so it comes from `Brand` (P-11).
    static let title = "Time to \(Brand.name.lowercased())"
    /// §12. The age is the review rule's (ADR-032), not a literal (P-12).
    static let body = "See which screenshots are over \(ReviewPolicy.minimumAgeDays) days old. One swipe each."
    /// The `userInfo` key for the moment the request was added, in seconds since 1970.
    static let anchorKey = "anchor"

    /// Read-only: two reads, then `status(authorization:alert:lockScreen:notificationCenter:pendingInterval:userInfo:now:)`.
    func status() async -> ReminderStatus {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let request = await center.pendingNotificationRequests().first { $0.identifier == Self.identifier }
        return Self.status(authorization: settings.authorizationStatus, alert: settings.alertSetting,
                           lockScreen: settings.lockScreenSetting,
                           notificationCenter: settings.notificationCenterSetting,
                           pendingInterval: (request?.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval,
                           userInfo: request?.content.userInfo ?? [:], now: Date())
    }

    /// What `status()` reports, from what it reads (ARCHITECTURE §4). Declined is `.denied`, and so is
    /// allowed with alerts, the lock screen and Notification Center all switched off, because nothing
    /// would show and Settings is the remedy; `reanchor()` then leaves the request alone. Undetermined
    /// is `.off`. Otherwise the pending request decides: none is `.off`, one is `.on`, dated by
    /// `ReminderPolicy.nextDate` from the moment in its `userInfo`. A request without that moment, or
    /// with something else there, reports an interval from now, which is also all iOS would answer;
    /// the app writes the moment on every request, so that case is not reached.
    static func status(authorization: UNAuthorizationStatus, alert: UNNotificationSetting,
                       lockScreen: UNNotificationSetting, notificationCenter: UNNotificationSetting,
                       pendingInterval: TimeInterval?, userInfo: [AnyHashable: Any], now: Date) -> ReminderStatus {
        switch authorization {
        case .denied: return .denied
        case .notDetermined: return .off
        default: break
        }
        if [alert, lockScreen, notificationCenter].allSatisfy({ $0 != .enabled }) { return .denied }
        guard let interval = pendingInterval else { return .off }
        guard let anchor = userInfo[anchorKey] as? TimeInterval else {
            return .on(next: now.addingTimeInterval(interval))
        }
        return .on(next: ReminderPolicy.nextDate(anchor: Date(timeIntervalSince1970: anchor), interval: interval, now: now))
    }

    func enable() async -> ReminderStatus {
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard granted else { return await status() }
        case .denied:
            return .denied
        default:
            break
        }
        await schedule()
        return await status()
    }

    func reanchor() async {
        guard case .on = await status() else { return }
        await schedule()
    }

    /// Title, body and the default sound; no badge (§12, ADR-034).
    private func schedule() async {
        let content = UNMutableNotificationContent()
        content.title = Self.title
        content.body = Self.body
        content.sound = .default
        content.userInfo = [Self.anchorKey: Date().timeIntervalSince1970]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: ReminderPolicy.interval, repeats: true)
        let request = UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger)
        // On failure the earlier request, if any, stays pending, and `status()` reports whatever is.
        try? await UNUserNotificationCenter.current().add(request)
    }
}
