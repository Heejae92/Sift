import Foundation
import Photos

/// The PhotoKit implementation of `PhotoLibrary` (ARCHITECTURE §4, §7). Slow synchronous reads run
/// detached and return value types; writes go through `performChanges` capturing identifiers only.
final class PhotoKitLibrary: PhotoLibrary {

    func authorizationStatus() async -> PhotoAuthorization {
        Self.map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func requestAuthorization() async -> PhotoAuthorization {
        Self.map(await PHPhotoLibrary.requestAuthorization(for: .readWrite))
    }

    func fetchScreenshots() async -> [Screenshot] {
        await Task.detached(priority: .userInitiated) {
            let options = PHFetchOptions()
            // Simulator escape hatch (ADR-027): a simulator cannot take screenshots and its stock
            // photos are not screenshots, so `-SiftAllImages` on the launch arguments reviews every
            // image instead. A device build ignores it, even a Debug run the scheme passes it to.
            if !Self.reviewAllImages {
                options.predicate = NSPredicate(format: "(mediaSubtypes & %d) != 0",
                                                PHAssetMediaSubtype.photoScreenshot.rawValue)
            }
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let result = PHAsset.fetchAssets(with: .image, options: options)
            var shots: [Screenshot] = []
            shots.reserveCapacity(result.count)
            result.enumerateObjects { asset, _, _ in
                shots.append(Screenshot(id: asset.localIdentifier,
                                        creationDate: asset.creationDate ?? .distantPast,
                                        pixelWidth: asset.pixelWidth,
                                        pixelHeight: asset.pixelHeight,
                                        isFavorite: asset.isFavorite))
            }
            return shots
        }.value
    }

    func changes() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let observer = ChangeObserver { continuation.yield() }
            PHPhotoLibrary.shared().register(observer)
            continuation.onTermination = { _ in
                PHPhotoLibrary.shared().unregisterChangeObserver(observer)
            }
        }
    }

    func setFavorite(_ id: String, _ value: Bool) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return }
            PHAssetChangeRequest(for: asset).isFavorite = value
        }
    }

    func ensureArchiveAlbum(existingID: String?, title: String) async throws -> String {
        if let existingID,
           let existing = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [existingID], options: nil).firstObject {
            return existing.localIdentifier
        }
        let byTitle = PHFetchOptions()
        byTitle.predicate = NSPredicate(format: "title = %@", title)
        if let found = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: byTitle).firstObject {
            return found.localIdentifier
        }
        let box = PlaceholderBox()
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
                box.id = request.placeholderForCreatedAssetCollection.localIdentifier
            }
        } catch {
            throw PhotoLibraryError.albumWriteRefused
        }
        guard let id = box.id else { throw PhotoLibraryError.albumWriteRefused }
        return id
    }

    func albumMembers(albumID: String) async -> [String] {
        await Task.detached(priority: .utility) {
            guard let album = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumID], options: nil).firstObject else { return [] }
            let result = PHAsset.fetchAssets(in: album, options: nil)
            var ids: [String] = []
            result.enumerateObjects { asset, _, _ in ids.append(asset.localIdentifier) }
            return ids
        }.value
    }

    func addToAlbum(_ ids: [String], albumID: String) async throws {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                guard let album = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumID], options: nil).firstObject,
                      let request = PHAssetCollectionChangeRequest(for: album) else { return }
                request.addAssets(PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil))
            }
        } catch {
            throw PhotoLibraryError.albumWriteRefused
        }
    }

    func removeFromAlbum(_ ids: [String], albumID: String) async throws {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                guard let album = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumID], options: nil).firstObject,
                      let request = PHAssetCollectionChangeRequest(for: album) else { return }
                request.removeAssets(PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil))
            }
        } catch {
            throw PhotoLibraryError.albumWriteRefused
        }
    }

    func delete(_ ids: [String]) async throws {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil))
            }
        } catch let error as NSError {
            if error.domain == PHPhotosErrorDomain, error.code == PHPhotosError.Code.userCancelled.rawValue {
                throw PhotoLibraryError.cancelled
            }
            throw PhotoLibraryError.failed(error.localizedDescription)
        }
    }

    func fileSizeBytes(for id: String) async -> Int64? {
        await Task.detached(priority: .utility) {
            guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject,
                  let resource = PHAssetResource.assetResources(for: asset).first(where: { $0.type == .photo })
                    ?? PHAssetResource.assetResources(for: asset).first else { return nil }
            return (resource.value(forKey: "fileSize") as? Int64)
        }.value
    }

    // MARK: - Private

    private static let reviewAllImages: Bool = {
        #if DEBUG && targetEnvironment(simulator)
        return ProcessInfo.processInfo.arguments.contains("-SiftAllImages")
        #else
        return false
        #endif
    }()

    private static func map(_ status: PHAuthorizationStatus) -> PhotoAuthorization {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .limited: return .limited
        case .authorized: return .authorized
        @unknown default: return .denied
        }
    }

    private final class ChangeObserver: NSObject, PHPhotoLibraryChangeObserver, Sendable {
        private let onChange: @Sendable () -> Void
        init(onChange: @escaping @Sendable () -> Void) { self.onChange = onChange }
        func photoLibraryDidChange(_ changeInstance: PHChange) { onChange() }
    }

    /// `performChanges` blocks are `@Sendable`; the placeholder identifier comes out through a box.
    private final class PlaceholderBox: @unchecked Sendable {
        var id: String?
    }
}
