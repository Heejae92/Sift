import SwiftUI

/// Phase-C placeholder: the two segments as lists with move and trash.
struct LibraryScreen: View {
    @Environment(Catalog.self) private var catalog
    @Binding var path: [Route]
    @State private var segment: LibrarySegment = .favorites

    var body: some View {
        VStack(spacing: DSSpace.s4) {
            Picker("Segment", selection: $segment) {
                Text("Favorites (\(catalog.favorites.count))").tag(LibrarySegment.favorites)
                Text("Archive (\(catalog.archived.count))").tag(LibrarySegment.archive)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DSGrid.mobileMargin)
            List {
                ForEach(segment == .favorites ? catalog.favorites : catalog.archived) { shot in
                    HStack {
                        Text(shot.creationDate.formatted(date: .abbreviated, time: .shortened)).dsType(.body)
                        Spacer()
                        Button(segment == .favorites ? "Move to Archive" : "Move to Favorites") {
                            Task { await catalog.move(shot.id, to: segment == .favorites ? .archive : .favorites) }
                        }
                        .buttonStyle(.dsPress).dsType(.labelSmall)
                        Button("Trash") { Task { await catalog.trashFromLibrary(shot.id) } }
                            .buttonStyle(.dsPress).dsType(.labelSmall).foregroundStyle(DSColor.trash.main)
                    }
                }
            }
            Button("Icons") { path.append(.credits) }.buttonStyle(.dsPress).dsType(.caption).foregroundStyle(DSColor.inkMuted)
        }
        .navigationTitle("Library")
    }
}
