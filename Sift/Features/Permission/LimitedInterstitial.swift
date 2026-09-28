import SwiftUI

/// UI_DESIGN §11.1, outcome "Limited": the notice shown on `DSBlock.limited` (`fave.soft`) when access
/// is limited and the selection differs from the one last acknowledged (IA §4, A2). `RootView`
/// decides when; this view only states the count and offers the two ways on.
///
/// "\(Brand.name) these N" is the block's one filled action and stores N as acknowledged, which
/// sends `RootView` on to Review. "Pick more" is the bare-text action and opens the system picker;
/// the count re-reads through the catalog's change observer and `RootView`'s foreground pass, and
/// this view follows `catalog.total`.
struct LimitedInterstitial: View {
    @Environment(Catalog.self) private var catalog

    var body: some View {
        let block = DSBlock.limited
        let count = catalog.total
        BlockView(block, headline: headline(count)) {
            DSButton(ctaTitle(count), kind: .blockCTA(block)) {
                catalog.acknowledgeLimitedSelection()
            }
            DSButton("Pick more", kind: .blockText(block)) {
                SystemUI.presentLimitedLibraryPicker()
            }
        }
    }

    /// §12: "You picked 14 screenshots. \(Brand.name) only sees those." One screenshot is singular.
    private func headline(_ count: Int) -> String {
        count == 1
            ? "You picked 1 screenshot. \(Brand.name) only sees that one."
            : "You picked \(count) screenshots. \(Brand.name) only sees those."
    }

    /// §12: "\(Brand.name) these 14".
    private func ctaTitle(_ count: Int) -> String {
        count == 1 ? "\(Brand.name) this one" : "\(Brand.name) these \(count)"
    }
}
