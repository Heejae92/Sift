import Photos
import PhotosUI
import UIKit

/// The two places the system forces UIKit on us (ARCHITECTURE §4).
@MainActor
enum SystemUI {
    /// "Open Settings" on the denied state (IA §9).
    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    /// "Pick more" under limited access. The catalog re-reads on the next foreground pass.
    static func presentLimitedLibraryPicker() {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }),
              let root = scene.keyWindow?.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: top)
    }
}
