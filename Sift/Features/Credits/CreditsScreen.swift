import SwiftUI

/// UI_DESIGN §10 "Credits screen": a pushed screen listing one CC BY line per
/// `DSIconCredits.entries` element (ADR-017). Pushed from the Permission footer before access is
/// granted and from the Library footer after (IA A3).
///
/// - Anatomy: a `DSTextRole.title` header, then one row per credit — the line in `DSTextRole.body`,
///   `DSIcon.chevron` trailing at `DSSize.iconInline` — on `canvas`. Rows sit on `surface` and are
///   separated by whitespace only; the system draws no borders (P-09).
/// - States: `populated` · `empty`. While `DSIconCredits.hasEntries` is false the screen says that
///   no third-party icons ship yet, which is the current state.
/// - Accessibility: each row is one element with the link trait and the full credit line as its
///   label; the chevron is decoration.
struct CreditsScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpace.s4) {
                Text("Icons")
                    .dsType(.title)
                    .foregroundStyle(DSColor.ink)
                    .accessibilityAddTraits(.isHeader)
                if DSIconCredits.hasEntries {
                    ForEach(DSIconCredits.entries) { credit in
                        CreditRow(credit: credit)
                    }
                } else {
                    Text("No third-party icons ship yet.")
                        .dsType(.body)
                        .foregroundStyle(DSColor.ink2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DSGrid.mobileMargin)
            .padding(.vertical, DSSpace.s5)
        }
        .background(DSColor.canvas, ignoresSafeAreaEdges: .all)
        .navigationBarTitleDisplayMode(.inline)
        // The Permission stack hides its bar at the root; a pushed screen needs its back button.
        .toolbar(.visible, for: .navigationBar)
    }
}

/// One credit, opening the stored Noun Project URL.
private struct CreditRow: View {
    let credit: DSIconCredit

    @ScaledMetric(relativeTo: .body) private var chevronSize = DSSize.iconInline
    @FocusState private var isFocused: Bool

    var body: some View {
        Link(destination: credit.url) {
            HStack(spacing: DSSpace.s3) {
                Text(credit.line)
                    .dsType(.body)
                    .foregroundStyle(DSColor.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                DSIcon.chevron.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: chevronSize, height: chevronSize)
                    .foregroundStyle(DSColor.ink2)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, DSSpace.s3)
            .frame(minHeight: DSSize.tapMin)
            .background(DSColor.surface)
            .contentShape(Rectangle())
        }
        .buttonStyle(.dsPress)
        .focused($isFocused)
        // Padded by `s3`, so the ring takes `DSRadius.md` (P-10).
        .dsFocusRing(isFocused, cornerRadius: DSRadius.md)
        // A `Link` is already one element with the link trait; the label is stated outright.
        .accessibilityLabel(credit.line)
    }
}
