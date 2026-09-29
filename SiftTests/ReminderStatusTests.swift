import Foundation
import Testing
import UserNotifications
@testable import Sift

/// ADR-034: what the UserNotifications scheduler reports, from what it reads. The mapping is a pure
/// function, so every case is checked here without a device or a prompt.
struct ReminderStatusTests {
    private let now = Date(timeIntervalSince1970: Fixtures.clockStart)
    private let interval = 30 * Fixtures.day
    private let key = UserNotificationsReminderScheduler.anchorKey

    private func status(_ authorization: UNAuthorizationStatus,
                        alert: UNNotificationSetting = .enabled, lockScreen: UNNotificationSetting = .enabled,
                        notificationCenter: UNNotificationSetting = .enabled,
                        pending: TimeInterval? = nil, userInfo: [AnyHashable: Any] = [:]) -> ReminderStatus {
        UserNotificationsReminderScheduler.status(authorization: authorization, alert: alert, lockScreen: lockScreen,
                                                  notificationCenter: notificationCenter, pendingInterval: pending,
                                                  userInfo: userInfo, now: now)
    }

    /// Declined is denied and undetermined is off, whatever is pending.
    @Test func authorizationComesFirst() {
        let anchored: [AnyHashable: Any] = [key: now.timeIntervalSince1970]
        #expect(status(.denied, pending: interval, userInfo: anchored) == .denied)
        #expect(status(.notDetermined) == .off)
        #expect(status(.notDetermined, pending: interval, userInfo: anchored) == .off)
    }

    /// Allowed, but alerts, the lock screen and Notification Center are all off: nothing would show,
    /// so it is denied, whose remedy is Settings. One place still on is enough to count as allowed.
    @Test func everyPlaceSwitchedOffIsDenied() {
        let anchored: [AnyHashable: Any] = [key: now.timeIntervalSince1970]
        #expect(status(.authorized, alert: .disabled, lockScreen: .disabled, notificationCenter: .disabled,
                       pending: interval, userInfo: anchored) == .denied)
        #expect(status(.authorized, alert: .disabled, lockScreen: .notSupported, notificationCenter: .disabled) == .denied)
        #expect(status(.authorized, alert: .disabled, lockScreen: .disabled, notificationCenter: .enabled,
                       pending: interval, userInfo: anchored) == .on(next: now.addingTimeInterval(interval)))
    }

    /// Allowed: no pending request is off; one is on, dated from the moment in its `userInfo`, which
    /// iOS hands back as a number.
    @Test func thePendingRequestDecides() {
        let added = now.addingTimeInterval(-10 * Fixtures.day)
        #expect(status(.authorized) == .off)
        #expect(status(.provisional) == .off)
        #expect(status(.authorized, pending: interval, userInfo: [key: added.timeIntervalSince1970])
                == .on(next: added.addingTimeInterval(interval)))
        #expect(status(.authorized, pending: interval, userInfo: [key: NSNumber(value: added.timeIntervalSince1970)])
                == .on(next: added.addingTimeInterval(interval)))
    }

    /// A request without the moment, or with something else under its key, reports an interval from
    /// now, which is what iOS itself would answer.
    @Test func aMissingOrMalformedAnchorReportsAnIntervalFromNow() {
        let fromNow = ReminderStatus.on(next: now.addingTimeInterval(interval))
        #expect(status(.authorized, pending: interval) == fromNow)
        #expect(status(.authorized, pending: interval, userInfo: [key: "yesterday"]) == fromNow)
        #expect(status(.authorized, pending: interval, userInfo: ["other": now.timeIntervalSince1970]) == fromNow)
    }
}
