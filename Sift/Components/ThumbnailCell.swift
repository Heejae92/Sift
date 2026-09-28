import SwiftUI
import Photos

/// UI_DESIGN §10 "ThumbnailCell": a square, center-cropped thumbnail at `DSRadius.xs` for the Trash
/// and Library grids. The owning grid sizes it — `DSSize.gridColumns` columns with a
/// `DSSize.thumbnailGutter` gutter — and passes the resulting `side`.
///
/// - Loading: `surfaceRaised` until `ImageLoader` returns an image at `side` × the display scale;
///   an asset that cannot load stays on that fill. A thumbnail does not float, so no shadow (P-09).
/// - Pressed: the owner wraps the cell in a `Button` with `.buttonStyle(.dsPress)`.
/// - Removing: the cell carries an opacity transition. The owning grid removes it inside
///   `withAnimation(DSMotion.gated(_:reduce:))` over `DSMotion.fade`, staggered across the grid.
/// - Variants: `.trash` and `.library` render identically. Per §10 they differ only in their
///   context menu and viewer action set, which the owning screen attaches, together with the same
///   actions as accessibility custom actions so they are reachable without a long press.
/// - VoiceOver: one image element labelled with the screenshot's date.
struct ThumbnailCell: View {
    enum Variant {
        case trash
        case library
    }

    @Environment(ImageLoader.self) private var images
    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    private let screenshot: Screenshot
    private let variant: Variant
    private let side: CGFloat

    init(screenshot: Screenshot, variant: Variant, side: CGFloat) {
        self.screenshot = screenshot
        self.variant = variant
        self.side = side
    }

    var body: some View {
        DSColor.surfaceRaised
            .frame(width: side, height: side)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipShape(shape)
            .contentShape(shape)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(screenshot.creationDate.formatted(date: .abbreviated, time: .shortened))
            .accessibilityAddTraits(.isImage)
            .transition(.opacity)
            .task(id: Request(id: screenshot.id, side: side)) {
                await load()
            }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DSRadius.xs, style: .continuous)
    }

    private func load() async {
        guard side > 0 else { return }
        let pixels = side * displayScale
        let loaded = await images.image(for: screenshot.id,
                                        targetSize: CGSize(width: pixels, height: pixels),
                                        contentMode: .aspectFill)
        guard !Task.isCancelled else { return }
        image = loaded
    }

    /// Reload when the asset or the cell's size changes.
    private struct Request: Equatable {
        let id: String
        let side: CGFloat
    }
}
