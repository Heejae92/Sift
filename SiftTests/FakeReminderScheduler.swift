import Foundation
@testable import Sift

/// In-memory stand-in for the notification center behind `ReminderScheduler` (ADR-034). An actor,
/// like `FakePhotoLibrary`. It keeps what iOS keeps: the authorization, the answer the user will give
/// to the one permission prompt, and the pending request, reduced to the moment it was added. It
/// follows the protocol's contract: `enable()` prompts only while undetermined, and `reanchor()`
/// does nothing unless the reminder is on. A test can hold a call at its gate to line up an
/// interleaving, the way the permission prompt holds `enable()` on a device.
actor FakeReminderScheduler: ReminderScheduler {
    enum Authorization { case notDetermined, denied, authorized }
    enum Call { case status, enable }

    private(set) var authorization: Authorization
    /// When the pending request was added; nil when nothing is pending.
    private(set) var anchor: Date?
    /// How many times the permission prompt was shown.
    private(set) var promptCount = 0
    /// Every `reanchor()` call, whether or not it moved the reminder.
    private(set) var reanchorCalls = 0
    /// What the user answers when the prompt shows.
    private let allowsWhenAsked: Bool
    private var now: Date
    private var held: Set<Call> = []
    private var waiting: [Call: CheckedContinuation<Void, Never>] = [:]

    /// The owner's 30 days, given explicitly rather than read from `ReminderPolicy.interval`, which
    /// honours `-SiftReminderSeconds` on a simulator (the same reason as `Fixtures.minimumAge`).
    static let interval = TimeInterval(ReminderPolicy.intervalDays) * Fixtures.day

    init(authorization: Authorization = .notDetermined, allowsWhenAsked: Bool = true, anchor: Date? = nil,
         now: Date = Date(timeIntervalSince1970: Fixtures.clockStart)) {
        self.authorization = authorization
        self.allowsWhenAsked = allowsWhenAsked
        self.anchor = anchor
        self.now = now
    }

    /// Moves the fake's clock on, for a sift finished later than the reminder was turned on.
    func advance(by interval: TimeInterval) { now += interval }

    /// The next `call` waits at its gate until `release(_:)`. A held `status()` has read already, so it
    /// answers what was true before it waited, like a reply from iOS that arrives late.
    func hold(_ call: Call) { held.insert(call) }
    func release(_ call: Call) {
        held.remove(call)
        waiting.removeValue(forKey: call)?.resume()
    }
    func isWaiting(_ call: Call) -> Bool { waiting[call] != nil }

    func status() async -> ReminderStatus {
        let reading = current()
        await gate(.status)
        return reading
    }

    func enable() async -> ReminderStatus {
        await gate(.enable)
        if authorization == .notDetermined {
            promptCount += 1
            authorization = allowsWhenAsked ? .authorized : .denied
        }
        if authorization == .authorized { anchor = now }
        return current()
    }

    func reanchor() async {
        reanchorCalls += 1
        guard case .on = current() else { return }
        anchor = now
    }

    private func current() -> ReminderStatus {
        switch authorization {
        case .denied: return .denied
        case .notDetermined: return .off
        case .authorized:
            return anchor.map { .on(next: ReminderPolicy.nextDate(anchor: $0, interval: Self.interval, now: now)) } ?? .off
        }
    }

    private func gate(_ call: Call) async {
        guard held.contains(call) else { return }
        await withCheckedContinuation { waiting[call] = $0 }
    }
}
