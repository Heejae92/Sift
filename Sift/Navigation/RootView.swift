import SwiftUI

/// The routing table of IA §4, re-evaluated on launch and on every return to the foreground.
struct RootView: View {
    @Environment(Catalog.self) private var catalog
    @Environment(\.scenePhase) private var scenePhase
    /// The cleanup reminder (ADR-034), passed on to Review, the one screen that uses it.
    let reminders: any ReminderScheduler
    @State private var path: [Route] = []

    private var showsDeniedBlock: Bool {
        catalog.isLoaded && !catalog.authorization.isUsable && catalog.authorization != .notDetermined
    }

    var body: some View {
        Group {
            if !catalog.isLoaded {
                DSColor.canvas.ignoresSafeArea()
            } else if !catalog.authorization.isUsable {
                PermissionScreen()
            } else if catalog.limitedSelectionChanged {
                LimitedInterstitial()
            } else {
                NavigationStack(path: $path) {
                    ReviewScreen(path: $path, reminders: reminders)
                        .navigationDestination(for: Route.self) { route in
                            switch route {
                            case .trash: TrashScreen()
                            case .library: LibraryScreen(path: $path)
                            case .credits: CreditsScreen()
                            }
                        }
                }
            }
        }
        .background(DSColor.canvas.ignoresSafeArea())
        // P-16: the root pins the scheme, light. The one exception is the denied block: violet with
        // white ink, and the status bar takes its style from the scheme, so dark text would vanish
        // there. Every color in the app is a token, so `.dark` changes nothing but the system bar.
        .preferredColorScheme(showsDeniedBlock ? .dark : .light)
        // Here and not on PermissionScreen: that screen is removed in the same update that makes
        // access usable, so a trigger on it never fires. `grantCount` changes only on a grant.
        .dsHaptic(.permissionGranted, trigger: catalog.grantCount)
        .task {
            await catalog.load()  // observing starts inside, once access is usable (ADR-010)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, catalog.isLoaded else { return }
            Task {
                await catalog.refreshAuthorization()
                if !catalog.authorization.isUsable { path.removeAll() }
            }
        }
    }
}
