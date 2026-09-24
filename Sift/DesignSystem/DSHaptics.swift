import SwiftUI

/// Haptic vocabulary (ADR-007). Meaning → feedback, wired through `.dsHaptic(_:trigger:)`,
/// the single choke point. Rule inherited from the previous app: a verdict is an `.impact`,
/// a completed success is `.success`, a destructive confirmation is `.warning`.
/// Impact WEIGHT encodes direction so eyes-off swiping still confirms which verdict landed.
/// There is no sound in v1 (ADR-012).
enum DSHaptic {
    /// Drag crossed the commit threshold (rising edge only).
    case thresholdArmed
    /// Swipe left committed — a thud into the bin.
    case trash
    /// Swipe right committed.
    case archive
    /// Swipe up committed — two light taps 90 ms apart, a heartbeat.
    case fave
    case rewind
    case restore
    /// "Delete permanently" tapped, fired just before the system dialog.
    case purgeArmed
    case purgeDone
    case queueDone
    case permissionGranted
    case segment
    case error

    var feedback: SensoryFeedback {
        switch self {
        case .thresholdArmed, .segment: return .selection
        case .trash:                    return .impact(weight: .heavy)
        case .archive:                  return .impact(weight: .medium)
        case .fave, .rewind:            return .impact(weight: .light)
        case .restore, .purgeDone, .queueDone, .permissionGranted:
                                        return .success
        case .purgeArmed:               return .warning
        case .error:                    return .error
        }
    }

    /// Number of pulses. Only `fave` repeats.
    var pulses: Int { self == .fave ? 2 : 1 }
    /// Gap between pulses in milliseconds.
    static let pulseGapMilliseconds = 90
}

private struct DSHapticModifier<Trigger: Equatable>: ViewModifier {
    let haptic: DSHaptic
    let trigger: Trigger
    @State private var echo = 0

    func body(content: Content) -> some View {
        content
            .sensoryFeedback(haptic.feedback, trigger: trigger)
            .sensoryFeedback(haptic.feedback, trigger: echo)
            .onChange(of: trigger) { _, _ in
                guard haptic.pulses > 1 else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(DSHaptic.pulseGapMilliseconds))
                    echo += 1
                }
            }
    }
}

extension View {
    /// Fire `haptic` whenever `trigger` changes. Use a counter or the committed asset id as the trigger.
    func dsHaptic<T: Equatable>(_ haptic: DSHaptic, trigger: T) -> some View {
        modifier(DSHapticModifier(haptic: haptic, trigger: trigger))
    }
}
