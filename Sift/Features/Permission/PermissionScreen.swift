import SwiftUI

/// UI_DESIGN §11.1 "Permission": the two-step gate. The app explains itself first and asks second;
/// the system dialog appears only when "Show me the screenshots" is tapped, never on launch
/// (ADR-010). `RootView` shows this screen while authorization is not usable (IA §4) and re-reads
/// authorization on every return to the foreground; the screen picks its own state from
/// `catalog.authorization`.
///
/// - Onboarding, on `DSBlock.onboarding`: `DemoStack` fills the space the copy leaves (the spec's top
///   55 %), then the headline, `SwipeLegend`, the block CTA and the footer link to Credits. The demo
///   takes the block's figure slot, so no face is set here. When the copy alone no longer fits
///   (accessibility text sizes) the demo steps aside and the copy scrolls (P-20).
/// - Denied (`.denied`, `.restricted`), on `DSBlock.denied`: "Open Settings" and "Not now". There
///   is nowhere else to go, so "Not now" only stops asking: the actions give way to a one-line hint
///   saying where the setting lives, and the next return to the foreground brings them back.
/// - VoiceOver: the demo is hidden; the CTA is the first element after the headline, then the
///   legend, then the footer (§10).
struct PermissionScreen: View {
    @Environment(Catalog.self) private var catalog
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Directions the user has completed on the demo; each checks its legend row.
    @State private var tried: Set<Verdict> = []
    @State private var isRequesting = false
    @State private var showsCredits = false
    /// "Not now" was tapped on the denied block.
    @State private var settingsDeferred = false

    var body: some View {
        NavigationStack {
            Group {
                switch gate {
                case .onboarding: onboarding
                case .denied: denied
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showsCredits) { CreditsScreen() }
        }
        // The grant haptic and the status-bar scheme for the violet denied block both live on
        // RootView: this screen is gone by the time access is usable, and a child's
        // preferredColorScheme loses to the root's (P-16).
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { settingsDeferred = false }
        }
    }

    // MARK: - State

    private enum Gate {
        /// `.notDetermined`. `.limited` and `.authorized` never reach this screen — `RootView` routes
        /// them away — and read as this case for the instant before it does.
        case onboarding
        /// `.denied` and `.restricted`.
        case denied
    }

    private var gate: Gate {
        switch catalog.authorization {
        case .denied, .restricted: return .denied
        case .notDetermined, .limited, .authorized: return .onboarding
        }
    }

    // MARK: - Onboarding

    private var onboarding: some View {
        let block = DSBlock.onboarding
        return ViewThatFits(in: .vertical) {
            VStack(spacing: 0) {
                DemoStack(completed: $tried, on: block)
                    // A card dragged or thrown across the copy passes over it, not under it.
                    .zIndex(DSLayer.sticky)
                onboardingCopy(block)
            }
            ScrollView {
                onboardingCopy(block)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(block.fill, ignoresSafeAreaEdges: .all)
    }

    private func onboardingCopy(_ block: DSBlock) -> some View {
        VStack(alignment: .leading, spacing: DSSpace.s5) {
            Text("\(Brand.name) your screenshots.")
                .dsType(.headline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilitySortPriority(3)
            SwipeLegend(checked: tried, on: block)
                .accessibilityElement(children: .contain)
                .accessibilitySortPriority(1)
            VStack(alignment: .leading, spacing: 0) {
                DSButton("Show me the screenshots", kind: .blockCTA(block), isLoading: isRequesting) {
                    requestAccess()
                }
                .accessibilitySortPriority(2)
                DSButton("Icons", kind: .blockText(block)) {
                    showsCredits = true
                }
            }
        }
        .foregroundStyle(block.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DSGrid.mobileMargin)
        .padding(.bottom, DSSpace.s4)
        .accessibilityElement(children: .contain)
    }

    private func requestAccess() {
        guard !isRequesting else { return }
        isRequesting = true
        Task {
            await catalog.requestAuthorization()
            isRequesting = false
        }
    }

    // MARK: - Denied

    private static let deniedHeadline = "\(Brand.name) can't see your screenshots yet."
    /// True for `.restricted` as well, where the user may not be able to change the setting.
    private static let deferredHint = "Photos access for \(Brand.name) is set in Settings."

    @ViewBuilder
    private var denied: some View {
        let block = DSBlock.denied
        if settingsDeferred {
            BlockView(block, headline: Self.deniedHeadline, body: Self.deferredHint) {
                EmptyView()
            }
        } else {
            BlockView(block, headline: Self.deniedHeadline) {
                DSButton("Open Settings", kind: .blockCTA(block)) {
                    SystemUI.openSettings()
                }
                DSButton("Not now", kind: .blockText(block)) {
                    deferSettings()
                }
            }
        }
    }

    private func deferSettings() {
        withAnimation(DSMotion.gated(DSMotion.standard, reduce: reduceMotion)) {
            settingsDeferred = true
        }
        AccessibilityNotification.Announcement(Self.deferredHint).post()
    }
}
