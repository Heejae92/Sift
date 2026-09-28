import Foundation
import Observation

/// Trash, the holding pen (UI_DESIGN §11.3, IA §6). Reads `catalog.trashed`, totals the sizes the
/// header and the docked button name, and runs restore and both purge rungs of ADR-009. The screen
/// owns the order of presentations (the sheet, the viewer, then the iOS dialog); the model owns
/// what happened and the haptic triggers that report it.
@MainActor
@Observable
final class TrashModel {
    let catalog: Catalog

    /// Bytes per trashed screenshot, read through `catalog.fileSizeBytes(for:)`. A screenshot Photos
    /// reports no size for counts as 0, so the total can complete; it is then a floor, not a guess.
    private(set) var sizes: [String: Int64] = [:]
    /// "Not deleted" after the iOS dialog is cancelled. The toast sets it back to nil.
    var toast: String?
    /// "Couldn't delete 3. Try again." after a partial failure, until the next attempt.
    private(set) var inlineError: String?
    /// A purge is out: the iOS dialog is up or Photos is deleting.
    private(set) var isPurging = false

    // Haptic triggers (UI_DESIGN §7): each count changes once per event.
    private(set) var purgeArmedCount = 0
    private(set) var purgeDoneCount = 0
    private(set) var restoreCount = 0
    private(set) var errorCount = 0

    init(catalog: Catalog) {
        self.catalog = catalog
    }

    // MARK: - Reads

    /// Most recently trashed first (IA §1).
    var items: [Screenshot] { catalog.trashed }

    /// The sum of the sizes read so far; complete once `sizeText` is non-nil.
    var totalBytes: Int64 {
        items.reduce(0) { $0 + (sizes[$1.id] ?? 0) }
    }

    /// "Trash · 27 items · 48 MB" (UI_DESIGN §11.3). The size joins once every size is read, so a
    /// count is never paired with the size of only part of the pile.
    var headerText: String {
        let count = items.count
        let noun = count == 1 ? "item" : "items"
        return (["Trash", "\(count) \(noun)"] + [sizeText].compactMap { $0 }).joined(separator: " · ")
    }

    /// "Delete all (27)": the count is always there (§12); the size stays in the header, so the
    /// button reads at a glance (owner, 2026-09-27: "버튼명 짧고 명확하게").
    var purgeButtonTitle: String { "Delete all (\(items.count))" }

    /// `ByteCountFormatter` in `.file` style; nil while any size is still unread, and for an empty
    /// trash, which has no size to name.
    private var sizeText: String? {
        let current = items
        guard !current.isEmpty else { return nil }
        var total: Int64 = 0
        for shot in current {
            guard let bytes = sizes[shot.id] else { return nil }
            total += bytes
        }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    // MARK: - Sizes

    /// Reads every missing size in display order, so the rows on screen come first and the total
    /// completes without the user scrolling. The screen runs it as one task keyed on the list;
    /// SwiftUI cancels it when the list changes or Trash goes away.
    func loadSizes() async {
        for shot in items where sizes[shot.id] == nil {
            guard !Task.isCancelled else { return }
            sizes[shot.id] = await catalog.fileSizeBytes(for: shot.id) ?? 0
        }
    }

    // MARK: - Actions

    /// Back to the queue, in date order (IA §6). Rung 0: no confirmation; `.restore` on return.
    func restore(_ id: String) {
        catalog.restore(id)
        restoreCount += 1
    }

    /// Rung 1 (ADR-009): no in-app confirmation. The iOS dialog is the one confirmation.
    func purgeOne(_ id: String) async {
        await purge([id])
    }

    /// Rung 2 (ADR-009). Call only once `PurgeAllSheet` has fully dismissed, so the iOS dialog
    /// never stacks on the sheet.
    func purgeAll() async {
        await purge(items.map(\.id))
    }

    private func purge(_ ids: [String]) async {
        guard !ids.isEmpty, !isPurging else { return }
        isPurging = true
        inlineError = nil
        purgeArmedCount += 1 // `.warning`, fired just before the iOS dialog (UI_DESIGN §7)
        let result = await catalog.purge(ids)
        isPurging = false
        switch result {
        case .deleted:
            purgeDoneCount += 1
        case .cancelled:
            toast = "Not deleted"
        case .failed(let remaining) where remaining > 0:
            inlineError = "Couldn't delete \(remaining). Try again."
            errorCount += 1
        case .failed:
            // Photos reported an error, yet none of the screenshots is left: they are gone.
            purgeDoneCount += 1
        }
    }
}
