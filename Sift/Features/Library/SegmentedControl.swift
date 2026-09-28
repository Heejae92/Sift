import SwiftUI

/// UI_DESIGN §10 "SegmentedControl": Favorites and Archive in a `surfaceRaised` track, the selected
/// one on a `surface` thumb inset by `DSSpace.s1`. Nesting rule (P-10): the track is `DSRadius.md`
/// (12) and the inset is 6, so the thumb takes 12 − 6 = 6, which is exactly `DSRadius.xs`. Neither
/// the track nor the thumb floats, so neither casts a shadow (P-09). An empty side is not disabled;
/// the screen shows its empty state instead.
///
/// Each segment's hit area is its whole half of the track, at least `DSSize.tapMin` tall (P-21): the
/// thumb is drawn inside the inset, and a tap anywhere in the half lands. VoiceOver reads it as a
/// tab-like group of two, each labelled with its count ("Favorites, 12") and the selected one
/// carrying the selected trait.
///
/// At accessibility text sizes the two segments stack instead of sitting side by side, so a label
/// wraps between words and never inside one (P-20).
struct SegmentedControl: View {
    @Binding private var selection: LibrarySegment
    private let favoritesCount: Int
    private let archivedCount: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Namespace private var thumb
    @FocusState private var focused: LibrarySegment?

    init(selection: Binding<LibrarySegment>, favoritesCount: Int, archivedCount: Int) {
        _selection = selection
        self.favoritesCount = favoritesCount
        self.archivedCount = archivedCount
    }

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 0))
            : AnyLayout(HStackLayout(spacing: 0))
        layout {
            ForEach(LibrarySegment.allCases, id: \.self) { segment in
                button(for: segment)
            }
        }
        .background(DSColor.surfaceRaised, in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
        .animation(DSMotion.gated(DSMotion.standard, reduce: reduceMotion), value: selection)
        .dsHaptic(.segment, trigger: selection)
        .accessibilityElement(children: .contain)
    }

    private func button(for segment: LibrarySegment) -> some View {
        let isSelected = selection == segment
        return Button {
            selection = segment
        } label: {
            Text("\(title(segment)) (\(count(segment)))")
                .dsType(.label)
                .foregroundStyle(isSelected ? DSColor.ink : DSColor.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DSSpace.s2)
                // The thumb plus its inset on both sides is the 44 pt hit area.
                .frame(maxWidth: .infinity, minHeight: DSSize.tapMin - 2 * DSSpace.s1)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: DSRadius.xs, style: .continuous)
                            .fill(DSColor.surface)
                            .matchedGeometryEffect(id: "thumb", in: thumb)
                    }
                }
                .padding(DSSpace.s1)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($focused, equals: segment)
        .dsFocusRing(focused == segment, cornerRadius: DSRadius.md)
        .accessibilityLabel("\(title(segment)), \(count(segment))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func title(_ segment: LibrarySegment) -> String {
        segment == .favorites ? "Favorites" : "Archive"
    }

    private func count(_ segment: LibrarySegment) -> Int {
        segment == .favorites ? favoritesCount : archivedCount
    }
}
