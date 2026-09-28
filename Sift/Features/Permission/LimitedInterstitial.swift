import SwiftUI

/// UI_DESIGN §11.1, outcome "Limited": the notice shown on `DSBlock.limited` (`fave.soft`) when access
/// is limited and the selection differs from the one last acknowledged (IA §4, A2). `RootView`
/// decides when; this view only states the count and offers the two ways on.
///
/// One action acknowledges the selection, storing the number picked, which sends `RootView` on to
/// Review; the other opens the system picker. The counts re-read through the catalog's change
/// observer and `RootView`'s foreground pass, and this view follows the catalog. When some of the
/// picked screenshots are unreviewed and under 30 days old, a body line says they wait and how many
/// are ready now (ADR-033). A block carries exactly one filled action (P-19): acknowledging, except
/// when none of the picked items is a screenshot, where picking more is the one worth filling.
struct LimitedInterstitial: View {
    @Environment(Catalog.self) private var catalog

    var body: some View {
        let block = DSBlock.limited
        let copy = Self.copy(picked: catalog.total, ready: catalog.queue.count, waiting: catalog.waiting.count,
                             nextArrival: catalog.nextArrival, waitDays: catalog.minimumAgeDays)
        BlockView(block, headline: copy.headline, body: copy.body) {
            DSButton(copy.primary.title, kind: .blockCTA(block)) { perform(copy.primary.action) }
            DSButton(copy.secondary.title, kind: .blockText(block)) { perform(copy.secondary.action) }
        }
    }

    private func perform(_ action: Copy.Action) {
        switch action {
        case .acknowledge: catalog.acknowledgeLimitedSelection()
        case .pickMore: SystemUI.presentLimitedLibraryPicker()
        }
    }

    /// What the block says and what its two actions do.
    struct Copy: Equatable {
        enum Action: Equatable {
            /// Store the selection as acknowledged and go on to Review.
            case acknowledge
            /// Open the limited-library picker.
            case pickMore
        }

        struct Button: Equatable {
            let title: String
            let action: Action
        }

        let headline: String
        let body: String?
        /// The block's one filled action.
        let primary: Button
        /// The bare-text action beside it.
        let secondary: Button
    }

    /// §11.1 and §12. The headline counts everything picked, one screenshot singular; with nothing
    /// picked that is a screenshot it says so, "Pick more" takes the fill and "Continue" is the text
    /// action. With nothing waiting there is no body and the CTA counts everything picked, as before
    /// ADR-033. With some waiting, the body says so, "Screenshots wait 30 days before \(Brand.name)
    /// asks. 3 are ready now.", and the CTA counts the ready ones; with none ready the body ends on
    /// the day the first one comes due, "It's ready …" when only one waits, and the CTA only moves on.
    static func copy(picked: Int, ready: Int, waiting: Int, nextArrival: Date?, waitDays: Int,
                     locale: Locale = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent) -> Copy {
        let pickMore = Copy.Button(title: "Pick more", action: .pickMore)
        guard picked > 0 else {
            return Copy(headline: "None of these are screenshots.", body: nil, primary: pickMore,
                        secondary: Copy.Button(title: "Continue", action: .acknowledge))
        }
        let headline = picked == 1
            ? "You picked 1 screenshot. \(Brand.name) only sees that one."
            : "You picked \(picked) screenshots. \(Brand.name) only sees those."
        guard waiting > 0 else {
            return Copy(headline: headline, body: nil, primary: siftButton(picked), secondary: pickMore)
        }
        let span = waitDays == 1 ? "1 day" : "\(waitDays) days"
        let wait = "Screenshots wait \(span) before \(Brand.name) asks."
        if ready > 0 {
            let now = ready == 1 ? "1 is ready now." : "\(ready) are ready now."
            return Copy(headline: headline, body: "\(wait) \(now)", primary: siftButton(ready), secondary: pickMore)
        }
        let first = nextArrival.map { date in
            let day = EmptyState.arrivalDay(date, locale: locale, timeZone: timeZone)
            return waiting == 1 ? " It's ready \(day)." : " The first is ready \(day)."
        } ?? ""
        return Copy(headline: headline, body: wait + first,
                    primary: Copy.Button(title: "Continue", action: .acknowledge), secondary: pickMore)
    }

    /// §12: "\(Brand.name) these 14", or "\(Brand.name) this one"; it acknowledges the selection.
    private static func siftButton(_ count: Int) -> Copy.Button {
        Copy.Button(title: count == 1 ? "\(Brand.name) this one" : "\(Brand.name) these \(count)",
                    action: .acknowledge)
    }
}
