import Foundation
import Observation
import Photos
import UIKit

/// Thumbnails and card images through `PHCachingImageManager` (ARCHITECTURE §4). One image per
/// request: high-quality format with network access, so the completion fires once.
@MainActor
@Observable
final class ImageLoader {
    @ObservationIgnored private let manager = PHCachingImageManager()

    init() {
        manager.allowsCachingHighQualityImages = false
    }

    func image(for id: String, targetSize: CGSize, contentMode: PHImageContentMode = .aspectFit) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return nil }
        let options = Self.requestOptions()
        let guardBox = ResumeGuard()
        return await withCheckedContinuation { continuation in
            manager.requestImage(for: asset, targetSize: targetSize, contentMode: contentMode, options: options) { image, _ in
                guard guardBox.claim() else { return }
                continuation.resume(returning: image)
            }
        }
    }

    func startCaching(ids: [String], targetSize: CGSize, contentMode: PHImageContentMode = .aspectFill) {
        let assets = Self.assets(ids)
        guard !assets.isEmpty else { return }
        manager.startCachingImages(for: assets, targetSize: targetSize, contentMode: contentMode, options: Self.requestOptions())
    }

    func stopCaching(ids: [String], targetSize: CGSize, contentMode: PHImageContentMode = .aspectFill) {
        let assets = Self.assets(ids)
        guard !assets.isEmpty else { return }
        manager.stopCachingImages(for: assets, targetSize: targetSize, contentMode: contentMode, options: Self.requestOptions())
    }

    func stopCachingAll() { manager.stopCachingImagesForAllAssets() }

    /// One options object for requests and for caching: `PHCachingImageManager` serves a cached image
    /// only when target size, content mode and options all match, so prefetching with different
    /// options would warm a cache the request can never hit.
    private static func requestOptions() -> PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast
        return options
    }

    private static func assets(_ ids: [String]) -> [PHAsset] {
        var out: [PHAsset] = []
        PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil).enumerateObjects { asset, _, _ in out.append(asset) }
        return out
    }

    /// PhotoKit may call a completion more than once; a continuation may resume once.
    private final class ResumeGuard: @unchecked Sendable {
        private let lock = NSLock()
        private var claimed = false
        func claim() -> Bool { lock.withLock { if claimed { return false }; claimed = true; return true } }
    }
}
