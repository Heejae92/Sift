import SwiftUI
import UIKit

/// Icons (ADR-017): bold SOLID glyphs from the Noun Project, exported as template PDFs into the
/// asset catalog under the `asset` names below. The free plan is CC BY, so every shipped icon
/// needs a credit line — `DSIconCredits` feeds the credits screen. Until an asset is dropped in,
/// `image` falls back to the listed SF Symbol so the app runs during development.
/// Color is always inherited (`foregroundStyle`); never a filled icon box behind a glyph.
struct DSIconRef {
    /// Asset-catalog name (template rendering).
    let asset: String
    /// Development fallback.
    let fallbackSymbol: String
    /// Search term on thenounproject.com.
    let query: String

    var image: Image {
        if UIImage(named: asset) != nil {
            return Image(asset).renderingMode(.template)
        }
        return Image(systemName: fallbackSymbol)
    }
}

enum DSIcon {
    static let trash       = DSIconRef(asset: "icon-trash",      fallbackSymbol: "trash.fill",                 query: "trash solid")
    static let archive     = DSIconRef(asset: "icon-archive",    fallbackSymbol: "archivebox.fill",            query: "archive box solid")
    static let fave        = DSIconRef(asset: "icon-heart",      fallbackSymbol: "heart.fill",                 query: "heart solid")
    static let rewind      = DSIconRef(asset: "icon-rewind",     fallbackSymbol: "arrow.uturn.backward",       query: "undo arrow bold")
    static let restore     = DSIconRef(asset: "icon-restore",    fallbackSymbol: "arrow.counterclockwise",     query: "restore arrow bold")
    static let library     = DSIconRef(asset: "icon-library",    fallbackSymbol: "photo.on.rectangle.angled",  query: "photo stack solid")
    static let settings    = DSIconRef(asset: "icon-settings",   fallbackSymbol: "gear",                       query: "gear solid")
    static let close       = DSIconRef(asset: "icon-close",      fallbackSymbol: "xmark",                      query: "close x bold")
    static let warning     = DSIconRef(asset: "icon-warning",    fallbackSymbol: "exclamationmark.triangle.fill", query: "warning triangle solid")
    static let check       = DSIconRef(asset: "icon-check",      fallbackSymbol: "checkmark.circle.fill",      query: "check circle solid")
    static let chevron     = DSIconRef(asset: "icon-chevron",    fallbackSymbol: "chevron.right",              query: "chevron right bold")
    static let photoAccess = DSIconRef(asset: "icon-photos",     fallbackSymbol: "photo.badge.checkmark.fill", query: "photo permission solid")

    static let all: [DSIconRef] = [trash, archive, fave, rewind, restore, library, settings, close,
                                   warning, check, chevron, photoAccess]
}

/// One CC BY credit line: "<title> by <author> from Noun Project".
struct DSIconCredit: Identifiable {
    let asset: String
    let title: String
    let author: String
    let url: URL
    var id: String { asset }

    var line: String { "\(title) by \(author) from Noun Project" }
}

enum DSIconCredits {
    /// Fill one entry per downloaded icon (the Noun Project download dialog shows title + author).
    /// The credits screen lists these; when the array is empty it says no third-party icons ship yet.
    static let entries: [DSIconCredit] = []

    static var hasEntries: Bool { !entries.isEmpty }
}
