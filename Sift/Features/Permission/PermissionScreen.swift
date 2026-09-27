import SwiftUI

/// Phase-C placeholder: the two-step permission gate of UI_DESIGN §11.1, minus the demo stack.
struct PermissionScreen: View {
    @Environment(Catalog.self) private var catalog

    var body: some View {
        let block: DSBlock = catalog.authorization == .denied || catalog.authorization == .restricted ? .denied : .onboarding
        VStack(alignment: .leading, spacing: DSSpace.s4) {
            Spacer()
            Text(block.face.text).dsType(.display).foregroundStyle(block.ink).accessibilityHidden(true)
            if block == .denied {
                Text("\(Brand.name) can't see your screenshots yet.").dsType(.headline).foregroundStyle(block.ink)
                Button("Open Settings") { SystemUI.openSettings() }
                    .buttonStyle(.dsPress).dsType(.label)
                    .padding(.horizontal, DSSpace.s5).padding(.vertical, DSSpace.s3)
                    .background(block.ctaFill, in: Capsule()).foregroundStyle(block.ctaLabel)
            } else {
                Text("\(Brand.name) your screenshots.").dsType(.headline).foregroundStyle(block.ink)
                Button("Show me the screenshots") { Task { await catalog.requestAuthorization() } }
                    .buttonStyle(.dsPress).dsType(.label)
                    .padding(.horizontal, DSSpace.s5).padding(.vertical, DSSpace.s3)
                    .background(block.ctaFill, in: Capsule()).foregroundStyle(block.ctaLabel)
            }
            Spacer().frame(height: DSSpace.s7)
        }
        .padding(.horizontal, DSGrid.mobileMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(block.fill.ignoresSafeArea())
    }
}

/// Phase-C placeholder for the limited-access interstitial (A2).
struct LimitedInterstitial: View {
    @Environment(Catalog.self) private var catalog

    var body: some View {
        let block: DSBlock = .limited
        VStack(alignment: .leading, spacing: DSSpace.s4) {
            Spacer()
            Text(block.face.text).dsType(.display).foregroundStyle(block.ink).accessibilityHidden(true)
            Text("You picked \(catalog.total) screenshots. \(Brand.name) only sees those.").dsType(.headline).foregroundStyle(block.ink)
            HStack(spacing: DSSpace.s4) {
                Button("\(Brand.name) these \(catalog.total)") { catalog.acknowledgeLimitedSelection() }
                    .buttonStyle(.dsPress).dsType(.label)
                    .padding(.horizontal, DSSpace.s5).padding(.vertical, DSSpace.s3)
                    .background(block.ctaFill, in: Capsule()).foregroundStyle(block.ctaLabel)
                Button("Pick more") { SystemUI.presentLimitedLibraryPicker() }
                    .buttonStyle(.dsPress).dsType(.label).foregroundStyle(block.ink)
            }
            Spacer().frame(height: DSSpace.s7)
        }
        .padding(.horizontal, DSGrid.mobileMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(block.fill.ignoresSafeArea())
    }
}
