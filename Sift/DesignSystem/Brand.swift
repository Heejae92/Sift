import Foundation

/// The ONLY place the product name appears in the design system.
/// Tokens are brand-neutral (`DS*`), so a rename is one line here plus the prose that names the
/// product: the header lines of `docs/knowledge/UI_DESIGN.md` and `README.md`, the ADR bodies that
/// quote screen copy, and `design-system.html`, which carries the word in its title, wordmark and
/// the screen strings it demonstrates. `scripts/ds_tokens.py lint` enforces only the Swift half —
/// it fails if the name leaks into any other file under `DesignSystem/`.
enum Brand {
    /// Provisional product name (ADR-002).
    static let name = "Sift"
    /// Title of the Photos album the app creates for right-swiped screenshots (ADR-014).
    static let archiveAlbumTitle = "\(name) Archive"
}
