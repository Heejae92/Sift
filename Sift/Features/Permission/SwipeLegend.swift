import SwiftUI

/// UI_DESIGN §10 "PermissionScreen, SwipeLegend, DemoStack" and §11.1 "Legend": what each swipe
/// does, written out, so the demo above it can stay decorative (P-22).
///
/// Three rows — Left → TRASH, Right → ARCHIVE, Up → FAVE — each carrying the verdict glyph, the
/// direction, the verdict word and where the screenshot goes, so no row depends on colour (P-02).
/// The rows sit on a full-bleed block, and a colour placed on a block follows the block's ink (P-19);
/// the verdict hues reach this screen through the demo's stamps, one of the four places P-06 allows
/// them. A direction the user has completed on the demo shows `DSIcon.check`.
struct SwipeLegend: View {
    private let checked: Set<Verdict>
    private let block: DSBlock

    /// Inline glyphs grow with the text they sit in (P-20); `DSSize.iconInline` is the base.
    @ScaledMetric(relativeTo: .body) private var glyphSize = DSSize.iconInline
    @Environment(\.dynamicTypeSize) private var typeSize

    init(checked: Set<Verdict>, on block: DSBlock = .onboarding) {
        self.checked = checked
        self.block = block
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpace.s3) {
            ForEach(Entry.all) { entry in
                row(entry)
            }
        }
        // Hugs its widest row so the parent can centre it as a column; at accessibility sizes the
        // rows need the full width to wrap, so the column goes edge to edge instead.
        .fixedSize(horizontal: !typeSize.isAccessibilitySize, vertical: false)
        .foregroundStyle(block.ink)
    }

    private func row(_ entry: Entry) -> some View {
        let isChecked = checked.contains(entry.verdict)
        return HStack(spacing: DSSpace.s3) {
            glyph(entry.icon)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(entry.direction) \(entry.arrow) \(entry.word)")
                    .dsType(.label)
                Text(entry.destination)
                    .dsType(.body)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            // Held in place while unchecked so the rows never reflow when a check lands; at
            // accessibility sizes the text needs the width more than the rows need to hold still.
            if isChecked || !typeSize.isAccessibilitySize {
                glyph(DSIcon.check)
                    .opacity(isChecked ? 1 : 0)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Swipe \(entry.direction.lowercased()): \(entry.spokenWord). \(entry.destination).")
        .accessibilityValue(isChecked ? "Done" : "")
    }

    private func glyph(_ icon: DSIconRef) -> some View {
        icon.image
            .resizable()
            .scaledToFit()
            .frame(width: glyphSize, height: glyphSize)
    }
}

extension SwipeLegend {
    /// One verdict as the Permission screen presents it. `all` is also the demo's loop order:
    /// card one goes left, card two right, card three up.
    struct Entry: Identifiable {
        let verdict: Verdict
        /// The direction word of §11.1: Left, Right, Up.
        let direction: String
        /// The same direction, typeset (P-08). The legend and the Reduce Motion panels print it.
        let arrow: String
        /// The stamp word (ADR-013).
        let word: String
        /// What VoiceOver says: the stamp reads FAVE, the action is "Favorite" (UI_DESIGN §13).
        let spokenWord: String
        let destination: String
        let icon: DSIconRef

        var id: Verdict { verdict }

        static let all: [Entry] = [
            Entry(verdict: .trash, direction: "Left", arrow: "←", word: "TRASH", spokenWord: "Trash",
                  destination: "The app's Trash until you empty it", icon: DSIcon.trash),
            Entry(verdict: .archive, direction: "Right", arrow: "→", word: "ARCHIVE", spokenWord: "Archive",
                  destination: "The \(Brand.archiveAlbumTitle) album in Photos", icon: DSIcon.archive),
            Entry(verdict: .fave, direction: "Up", arrow: "↑", word: "FAVE", spokenWord: "Favorite",
                  destination: "Your Photos favorites", icon: DSIcon.fave),
        ]

        static func of(_ verdict: Verdict) -> Entry {
            all.first { $0.verdict == verdict } ?? all[0]
        }
    }
}
