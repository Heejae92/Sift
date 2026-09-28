import SwiftUI

/// UI_DESIGN §10 "ProgressCounter": position, slash, total in `DSTextRole.counter`, `ink`, leading in
/// the Review header. The role's tabular digits keep the slash still. The changed digit rolls
/// through `.contentTransition(.numericText())` unless Reduce Motion is on. VoiceOver reads
/// "12 of 340", not "12 slash 340".
struct ProgressCounter: View {
    enum Phase: Equatable {
        /// "— / —" until the queue is known.
        case loading
        /// "12 / 340".
        case counting(position: Int, total: Int)
        /// Replaced by the all-done block, so nothing is drawn.
        case done
    }

    let phase: Phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        switch phase {
        case .loading:
            Text("— / —")
                .dsType(.counter)
                .foregroundStyle(DSColor.ink)
                .accessibilityLabel("Loading screenshots")
        case .counting(let position, let total):
            Text("\(position) / \(total)")
                .dsType(.counter)
                .foregroundStyle(DSColor.ink)
                .contentTransition(.numericText(value: Double(position)))
                .animation(DSMotion.gated(DSMotion.standard, reduce: reduceMotion), value: phase)
                .accessibilityLabel("\(position) of \(total)")
        case .done:
            EmptyView()
        }
    }
}
