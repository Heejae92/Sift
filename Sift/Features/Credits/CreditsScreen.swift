import SwiftUI

/// One row per Noun Project icon (ADR-017). Empty until the assets land; the lint warns until then.
struct CreditsScreen: View {
    var body: some View {
        List {
            if DSIconCredits.hasEntries {
                ForEach(DSIconCredits.entries) { credit in
                    Text(credit.line).dsType(.body)
                }
            } else {
                Text("No third-party icons ship in this build yet.").dsType(.body).foregroundStyle(DSColor.ink2)
            }
        }
        .navigationTitle("Icons")
    }
}
