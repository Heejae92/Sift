import SwiftUI

/// The routing table of IA §4, re-evaluated on launch and on every return to the foreground.
struct RootView: View {
    @Environment(Catalog.self) private var catalog
    @Environment(\.scenePhase) private var scenePhase
    @State private var path: [Route] = []

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
                    ReviewScreen(path: $path)
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
