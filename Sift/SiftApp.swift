import SwiftUI

@main
struct SiftApp: App {
    @State private var catalog: Catalog
    @State private var images = ImageLoader()
    /// The cleanup reminder (ADR-034): the notification center behind a protocol, as Photos is.
    private let reminders: any ReminderScheduler = UserNotificationsReminderScheduler()

    init() {
        let persistence: any StorePersistence
        if let store = try? FileStorePersistence.applicationSupport() {
            persistence = store
        } else {
            persistence = FileStorePersistence(url: FileManager.default.temporaryDirectory.appendingPathComponent("store.json"))
        }
        _catalog = State(initialValue: Catalog(library: PhotoKitLibrary(), persistence: persistence))
    }

    var body: some Scene {
        WindowGroup {
            RootView(reminders: reminders)
                .environment(catalog)
                .environment(images)
                 // P-16, ADR-006
        }
    }
}
