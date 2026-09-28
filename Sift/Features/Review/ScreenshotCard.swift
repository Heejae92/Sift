import SwiftUI
import UIKit

/// UI_DESIGN §10 "ScreenshotCard": a `surface` card at `DSRadius.xl` holding the screenshot inside a
/// `DSSize.cardInset` letterbox. The screenshot is fitted and never cropped, because the cropped part
/// may be the part being judged (P-01). The date chip sits bottom-left and the three stamps are
/// overlaid. The card only draws; `CardStack` moves it (drag, stack position, throw, landing).
///
/// States: `loading` (the screenshot's footprint in `surfaceRaised`), loaded, and `unloadable` (the
/// same footprint with the warning glyph). The front and flying cards float on
/// `DSShadow.floating`; cards behind lie under them on `DSShadow.stack`.
///
/// VoiceOver sees one element: "Screenshot, Sep 21, 2:14 PM, 1.2 MB, 12 of 340" (P-22).
struct ScreenshotCard: View {
    let screenshot: Screenshot
    let size: CGSize
    /// Front and flying cards float; the cards behind them do not.
    let floats: Bool
    /// Front and flying cards carry the three stamps; the cards behind them never show one.
    let showsStamps: Bool
    /// The one stamp showing and how strongly; nil leaves all three at zero.
    let stamp: CardStamp?
    /// "12 of 340" on the front card. VoiceOver never reaches the others.
    let position: String?

    @Environment(ImageLoader.self) private var images
    @Environment(Catalog.self) private var catalog
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var picture: Picture = .loading
    @State private var fileSize: Int64?

    private enum Picture {
        case loading
        case loaded(UIImage)
        case unloadable
    }

    private struct PictureRequest: Equatable {
        let id: String
        let pixelSize: CGSize
    }

    /// The size the screenshot is requested at: the letterbox inside `DSSize.cardInset`, in pixels.
    /// `CardStack` prefetches at the same size so the cache is actually hit.
    static func pixelSize(forCard size: CGSize, scale: CGFloat) -> CGSize {
        CGSize(width: max(size.width - 2 * DSSize.cardInset, .zero) * scale,
               height: max(size.height - 2 * DSSize.cardInset, .zero) * scale)
    }

    var body: some View {
        content
            .padding(DSSize.cardInset)
            .frame(width: size.width, height: size.height)
            .background {
                RoundedRectangle(cornerRadius: DSRadius.xl, style: .continuous)
                    .fill(DSColor.surface)
                    .dsShadow(floats ? .floating : .stack)
            }
            .overlay(alignment: .bottomLeading) {
                chip.padding(DSSpace.s5)
            }
            .overlay {
                if showsStamps { stamps }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
            .task(id: PictureRequest(id: screenshot.id, pixelSize: pixelSize)) {
                await loadPicture()
            }
            .task(id: screenshot.id) {
                fileSize = await catalog.fileSizeBytes(for: screenshot.id)
            }
    }

    // MARK: - Screenshot

    @ViewBuilder private var content: some View {
        switch picture {
        case .loaded(let image):
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(letterboxShape)
        case .loading:
            footprint
        case .unloadable:
            footprint.overlay {
                DSIcon.warning.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: DSSize.iconChrome, height: DSSize.iconChrome)
                    .foregroundStyle(DSColor.ink2)
            }
        }
    }

    /// The screenshot's own aspect ratio in `surfaceRaised`, so the picture lands exactly where the
    /// placeholder was.
    private var footprint: some View {
        letterboxShape
            .fill(DSColor.surfaceRaised)
            .aspectRatio(aspectRatio, contentMode: .fit)
    }

    private var aspectRatio: CGFloat? {
        guard screenshot.pixelWidth > 0, screenshot.pixelHeight > 0 else { return nil }
        return CGFloat(screenshot.pixelWidth) / CGFloat(screenshot.pixelHeight)
    }

    /// Nested radius (P-10): `DSRadius.xl` 24 minus the `DSSize.cardInset` 12 gap is 12, `DSRadius.md`.
    private var letterboxShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
    }

    private var pixelSize: CGSize {
        Self.pixelSize(forCard: size, scale: displayScale)
    }

    private func loadPicture() async {
        let target = pixelSize
        guard target.width > .zero, target.height > .zero else { return }
        let image = await images.image(for: screenshot.id, targetSize: target)
        guard !Task.isCancelled else { return }
        if let image {
            picture = .loaded(image)
        } else if case .loading = picture {
            picture = .unloadable
        }
    }

    // MARK: - Chip

    /// `chip` over a system blur, `ink` in `DSTextRole.caption`, `DSRadius.xs`. Inset by `DSSpace.s5`,
    /// the stamps' inset, where the nested radius clamps up to `xs` (P-10). Under Reduce Transparency
    /// it becomes solid `surface` (§13).
    private var chip: some View {
        Text(chipText)
            .dsType(.caption)
            .foregroundStyle(DSColor.ink)
            .padding(.vertical, DSSpace.s1)
            .padding(.horizontal, DSSpace.s2)
            .background { chipFill }
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var chipFill: some View {
        let shape = RoundedRectangle(cornerRadius: DSRadius.xs, style: .continuous)
        if reduceTransparency {
            shape.fill(DSColor.surface)
        } else {
            shape.fill(DSColor.chip).background(.ultraThinMaterial, in: shape)
        }
    }

    private var dateText: String {
        screenshot.creationDate.formatted(.dateTime.month(.abbreviated).day())
    }

    private var timeText: String {
        screenshot.creationDate.formatted(date: .omitted, time: .shortened)
    }

    /// "1.2 MB" or "860 KB". Blank until PhotoKit has answered (§15 item 4).
    private var sizeText: String? {
        fileSize.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }
    }

    /// "Sep 21 · 2:14 PM · 1.2 MB"
    private var chipText: String {
        ([dateText, timeText] + [sizeText].compactMap { $0 }).joined(separator: " · ")
    }

    /// "Screenshot, Sep 21, 2:14 PM, 1.2 MB, 12 of 340"
    private var accessibilityText: String {
        (["Screenshot", dateText, timeText] + [sizeText, position].compactMap { $0 }).joined(separator: ", ")
    }

    // MARK: - Stamps

    /// ARCHIVE top-left, TRASH top-right, each inset by `DSSpace.s5`. FAVE is centred, raised by
    /// `DSSize.stampFaveRaise` of the card's height (§10 VerdictStamp). Each side stamp sits on the side
    /// its card is not leaving toward, so it stays in view as the card goes.
    private var stamps: some View {
        ZStack {
            VerdictStamp(verdict: .archive, opacity: stampOpacity(.archive))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            VerdictStamp(verdict: .trash, opacity: stampOpacity(.trash))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            VerdictStamp(verdict: .fave, opacity: stampOpacity(.fave))
                .offset(y: -DSSize.stampFaveRaise * size.height)
        }
        .padding(DSSpace.s5)
    }

    private func stampOpacity(_ verdict: Verdict) -> Double {
        guard let stamp, stamp.verdict == verdict else { return .zero }
        return stamp.opacity
    }
}
