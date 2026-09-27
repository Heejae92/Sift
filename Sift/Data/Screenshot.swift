import Foundation

/// One screenshot the app can see. A value type built from a `PHAsset` by the photo service; no
/// PhotoKit type crosses into the catalog or a screen (ARCHITECTURE §7).
struct Screenshot: Identifiable, Hashable, Sendable {
    /// `PHAsset.localIdentifier` — the identity every list is keyed by (IA §1).
    let id: String
    let creationDate: Date
    let pixelWidth: Int
    let pixelHeight: Int
    /// Photos is the truth for the heart; the app never keeps a copy (A1).
    let isFavorite: Bool

    var pixelSize: CGSize { CGSize(width: pixelWidth, height: pixelHeight) }
}
