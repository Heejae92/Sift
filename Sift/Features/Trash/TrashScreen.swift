import SwiftUI

/// Phase-C placeholder: the holding pen as a list with Restore and Delete permanently.
struct TrashScreen: View {
    @Environment(Catalog.self) private var catalog
    @State private var toast: String?

    var body: some View {
        List {
            ForEach(catalog.trashed) { shot in
                HStack {
                    Text(shot.creationDate.formatted(date: .abbreviated, time: .shortened)).dsType(.body)
                    Spacer()
                    Button("Restore") { catalog.restore(shot.id) }.buttonStyle(.dsPress).dsType(.labelSmall)
                    Button("Delete permanently") { Task { toast = describe(await catalog.purge([shot.id])) } }
                        .buttonStyle(.dsPress).dsType(.labelSmall).foregroundStyle(DSColor.trash.main)
                }
            }
        }
        .overlay(alignment: .center) {
            if catalog.trashed.isEmpty {
                Text("Trash is empty. Squeaky.").dsType(.headline).foregroundStyle(DSColor.ink)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !catalog.trashed.isEmpty {
                Button("Delete all permanently (\(catalog.trashed.count))") {
                    Task { toast = describe(await catalog.purge(catalog.trashed.map(\.id))) }
                }
                .buttonStyle(.dsPress).dsType(.label)
                .padding(.horizontal, DSSpace.s5).padding(.vertical, DSSpace.s3)
                .background(DSColor.trash.main, in: Capsule()).foregroundStyle(DSColor.ink)
                .padding(DSSpace.s4)
            }
        }
        .navigationTitle("Trash")
        .overlay(alignment: .top) {
            if let toast { Text(toast).dsType(.labelSmall).foregroundStyle(DSColor.onToast).padding(DSSpace.s3).background(DSColor.toast, in: Capsule()) }
        }
    }

    private func describe(_ result: PurgeResult) -> String? {
        switch result {
        case .deleted: return nil
        case .cancelled: return "Not deleted"
        case .failed(let remaining): return "Couldn't delete \(remaining). Try again."
        }
    }
}
