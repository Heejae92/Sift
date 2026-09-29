import SwiftUI

/// UI_DESIGN §11.2 "Review", the root of the stack (IA §3).
///
/// - Header: `ProgressCounter` leading; Trash, with its count badge, and Library trailing, each
///   pushing its route onto `path`.
/// - Body: the `CardStack`.
/// - Bottom: `VerdictButtonRow` centred with `RewindButton` pinned leading, docked in a
///   `safeAreaInset`.
/// - `allDone` and `noScreenshots` are `EmptyState` blocks. They run full-bleed under the header and
///   the dock, which take the block's ink. Rewind stays available in `allDone`, and reaching it plays
///   the `DSMotion.confetti` burst unless Reduce Motion is on.
/// - The all-done block carries the cleanup reminder (ADR-034): its bare-text action and, while it is
///   on, its date. The reminder is read from iOS when the block appears and on every return to the
///   foreground, which is how a change made in Settings shows up.
struct ReviewScreen: View {
    @Environment(Catalog.self) private var catalog
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Binding var path: [Route]
    /// Built by `SiftApp`, like the photo library, and handed to the model.
    let reminders: any ReminderScheduler
    @State private var model: ReviewModel?
    @State private var motion = DeckMotion()

    var body: some View {
        ZStack {
            if let emptyState {
                EmptyState(emptyState, primaryAction: { path.append(.trash) }, reminderAction: { perform($0) })
                    .transition(.opacity)
            }
            if let burst {
                AllDoneBurst(ink: DSBlock.allDone.ink)
                    .id(burst)
                    .transition(.identity)
            }
            if let model {
                CardStack(model: model, motion: motion, position: "\(model.position) of \(model.total)")
            } else {
                CardSkeleton()
            }
        }
        .animation(stateChange, value: block)
        .animation(stateChange, value: model?.reminder)
        .safeAreaInset(edge: .top, spacing: .zero) {
            ReviewHeader(counter: counter, trashCount: catalog.trashed.count, block: block,
                         openTrash: { path.append(.trash) }, openLibrary: { path.append(.library) })
        }
        .safeAreaInset(edge: .bottom, spacing: .zero) { dock }
        .background(DSColor.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .dsHaptic(model?.lastVerdict?.haptic ?? .trash, trigger: model?.commitCount ?? 0)
        .dsHaptic(.rewind, trigger: model?.rewindCount ?? 0)
        .dsHaptic(.queueDone, trigger: model?.queueDoneCount ?? 0)
        .dsHaptic(.thresholdArmed, trigger: motion.armedCount)
        .dsHaptic(.permissionGranted, trigger: model?.reminderOnCount ?? 0)
        .task(id: catalog.isLoaded) {
            guard catalog.isLoaded else { return }
            if model == nil { model = ReviewModel(catalog: catalog, reminders: reminders) }
            model?.sync()
        }
        .task(id: isAllDone) {
            guard isAllDone else { return }
            await model?.refreshReminder()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, isAllDone else { return }
            Task { await model?.refreshReminder() }
        }
        .onChange(of: catalog.screenshots) { _, _ in model?.catalogDidChange() }
        .onChange(of: catalog.state) { _, _ in model?.catalogDidChange() }
        // A refresh of an unchanged library moves neither of the two above, but a waiting screenshot
        // may have come due against the new reference date (ADR-032).
        .onChange(of: catalog.referenceDate) { _, _ in model?.catalogDidChange() }
        .onChange(of: model?.lastAnnouncement) { _, text in announce(text) }
    }

    // MARK: - Regions

    /// The docked row keeps its height in every phase, so the card and the block never jump. The three
    /// circles give way in `allDone`, because a block carries one filled action, its own CTA
    /// (ADR-023). In `noScreenshots` the whole row does, since there is nothing to rewind.
    private var dock: some View {
        let phase = model?.phase ?? .loading
        let showsVerdicts = phase != .allDone && phase != .noScreenshots
        let showsDock = phase != .noScreenshots
        return ZStack(alignment: .bottomLeading) {
            VerdictButtonRow(isEnabled: model?.acceptsInput ?? false) { verdict in
                guard let model else { return }
                motion.flick(verdict, model: model, reduceMotion: reduceMotion)
            }
            .frame(maxWidth: .infinity)
            .opacity(showsVerdicts ? 1 : .zero)
            .allowsHitTesting(showsVerdicts)
            .accessibilityHidden(!showsVerdicts)
            RewindButton(isEnabled: model?.canRewind ?? false, block: block) {
                guard let model else { return }
                motion.rewind(model: model, reduceMotion: reduceMotion)
            }
            .padding(.leading, DSGrid.mobileMargin)
        }
        .padding(.vertical, DSSpace.s2)
        .opacity(showsDock ? 1 : .zero)
        .allowsHitTesting(showsDock)
        .accessibilityHidden(!showsDock)
        .animation(stateChange, value: showsVerdicts)
    }

    // MARK: - Phase → what is shown

    private var counter: ProgressCounter.Phase {
        Self.counterPhase(model?.phase, position: model?.position ?? .zero, total: model?.total ?? .zero)
    }

    /// The header counter for a deck phase: "— / —" while loading, nothing once a block is up, and
    /// nothing while no screenshot is due yet (ADR-032), so it never reads "0 / 0", even mid-flight.
    /// Position and total are read only when there is a count to show.
    static func counterPhase(_ phase: ReviewModel.Phase?, position: @autoclosure () -> Int,
                             total: @autoclosure () -> Int) -> ProgressCounter.Phase {
        switch phase {
        case .none, .some(.loading): return .loading
        case .some(.allDone), .some(.noScreenshots): return .done
        default:
            let total = total()
            return total == 0 ? .done : .counting(position: position(), total: total)
        }
    }

    /// The block that replaces the deck: `allDone` (the queue is empty and the library is not: every
    /// screenshot is reviewed or still waiting) or `noScreenshots`.
    private var emptyState: EmptyState.Kind? {
        switch model?.phase {
        case .some(.allDone):
            return .allDone(trashCount: catalog.trashed.count, nextArrival: catalog.nextArrival, reminder: model?.reminder)
        case .some(.noScreenshots): return .noScreenshots
        default: return nil
        }
    }

    private var isAllDone: Bool { model?.phase == .allDone }

    /// The all-done block's bare-text action (ADR-034). "Remind me" is the one place the app asks for
    /// notifications (ADR-010); a declined answer leads to the app's notification settings, and the
    /// return re-reads it.
    private func perform(_ action: EmptyState.ReminderAction) {
        switch action {
        case .remindMe: Task { await model?.enableReminder() }
        case .openSettings: SystemUI.openNotificationSettings()
        }
    }

    /// The block behind the header and the dock, whose ink and focus ring they take (§9 Rules).
    /// `EmptyState` draws `noScreenshots` on `DSBlock.allDone` as well (§15 item 5). Read from the
    /// phase, so it never builds the block's copy.
    private var block: DSBlock? {
        switch model?.phase {
        case .some(.allDone), .some(.noScreenshots): return .allDone
        default: return nil
        }
    }

    /// One burst each time the queue runs out (`ReviewModel.queueDoneCount`), none on a launch that
    /// starts out done, and none under Reduce Motion, which removes celebration (§6).
    private var burst: Int? {
        guard let model, model.phase == .allDone, model.queueDoneCount > 0, !reduceMotion else { return nil }
        return model.queueDoneCount
    }

    /// Block in, block out, dock in, dock out: a standard state change. Under Reduce Motion it becomes
    /// a cross-fade.
    private var stateChange: Animation? {
        DSMotion.gated(DSMotion.standard, reduce: reduceMotion, reduced: DSMotion.crossFade)
    }

    /// P-22: the verdict and the new position in one sentence, the same two facts a sighted user reads
    /// off the stamp and the counter. High priority, so the focus move to the next card cannot cut it.
    private func announce(_ text: String?) {
        guard let text else { return }
        var announcement = AttributedString(text)
        announcement.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(announcement).post()
    }
}

/// The Review header (IA §3 "Header ownership"): `ProgressCounter` leading, Trash with its count badge
/// and Library trailing. Glyphs are `DSSize.iconChrome` in a `DSSize.tapMin` hit area, padded around
/// the glyph rather than enlarged (P-21).
private struct ReviewHeader: View {
    let counter: ProgressCounter.Phase
    let trashCount: Int
    /// The block behind the header in `allDone` and `noScreenshots`; nil over the canvas.
    let block: DSBlock?
    let openTrash: () -> Void
    let openLibrary: () -> Void
    @FocusState private var focused: Destination?

    private enum Destination {
        case trash, library
    }

    var body: some View {
        HStack(spacing: DSSpace.s2) {
            ProgressCounter(phase: counter)
            Spacer(minLength: DSSpace.s4)
            chromeButton(.trash, icon: DSIcon.trash, action: openTrash)
                .accessibilityLabel("Trash")
                .accessibilityValue(trashValue)
                .accessibilityHint("Opens Trash.")
            chromeButton(.library, icon: DSIcon.library, action: openLibrary)
                .accessibilityLabel("Library")
                .accessibilityHint("Opens your favorites and your archive.")
        }
        .padding(.horizontal, DSGrid.mobileMargin)
        .padding(.vertical, DSSpace.s2)
    }

    /// `ink2` over the canvas; over a block, the block's ink and focus ring (§9 Rules, ADR-023).
    private func chromeButton(_ destination: Destination, icon: DSIconRef, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            icon.image
                .resizable()
                .scaledToFit()
                .frame(width: DSSize.iconChrome, height: DSSize.iconChrome)
                .overlay(alignment: .topTrailing) {
                    if destination == .trash, showsBadge { badge }
                }
                .frame(width: DSSize.tapMin, height: DSSize.tapMin)
                .contentShape(Rectangle())
        }
        .buttonStyle(.dsPress)
        .foregroundStyle(block?.ink ?? DSColor.ink2)
        .focused($focused, equals: destination)
        .dsFocusRing(focused == destination, cornerRadius: DSRadius.pill, color: block?.focusRing ?? DSColor.focus)
    }

    /// The count on a `trash.main` badge (P-06), `ink` on tomato at 4.61:1 (P-19). A number and not a
    /// dot, so color is never alone (§13). Not drawn over a block: the block's copy already carries the
    /// count, and color on a block comes from `DSBlock` alone.
    private var showsBadge: Bool { trashCount > 0 && block == nil }

    private var badge: some View {
        Text(trashCount.formatted())
            .dsType(.labelSmall)
            .foregroundStyle(DSColor.ink)
            .padding(.horizontal, DSSpace.s1)
            .background(DSColor.trash.main, in: RoundedRectangle(cornerRadius: DSRadius.xs, style: .continuous))
            .fixedSize()
            .alignmentGuide(.top) { $0[VerticalAlignment.center] }
            .alignmentGuide(.trailing) { $0[HorizontalAlignment.center] }
            .accessibilityHidden(true)
    }

    private var trashValue: String {
        switch trashCount {
        case 0: return "Empty"
        case 1: return "1 item"
        default: return "\(trashCount) items"
        }
    }
}

/// The all-done burst of §11.2. The three verdict glyphs fly out the way their cards go, from the
/// centre to the edge, and fade over `DSMotion.confetti` on the throw's ease-out. They use the
/// block's ink, not the verdict or expressive colours, because P-06 keeps verdict colours to four
/// places and expressive colours to full-bleed blocks. Transform and opacity only (§6); hidden from
/// VoiceOver and from touches.
private struct AllDoneBurst: View {
    let ink: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isOut = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Verdict.allCases, id: \.self) { verdict in
                    verdict.icon.image
                        .resizable()
                        .scaledToFit()
                        .frame(width: DSSize.stampIcon, height: DSSize.stampIcon)
                        .offset(isOut ? travel(verdict, in: geo.size) : .zero)
                        .opacity(isOut ? .zero : 1)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .foregroundStyle(ink)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(DSMotion.gated(DSMotion.throwOut(duration: DSMotion.confetti), reduce: reduceMotion)) {
                isOut = true
            }
        }
    }

    /// Along the verdict's swipe axis (ADR-019), from the centre of the region to its edge.
    private func travel(_ verdict: Verdict, in size: CGSize) -> CGSize {
        let axis: CGVector
        switch verdict {
        case .trash: axis = SwipeSector.trash.axis
        case .archive: axis = SwipeSector.archive.axis
        case .fave: axis = SwipeSector.fave.axis
        }
        return CGSize(width: axis.dx * size.width / 2, height: axis.dy * size.height / 2)
    }
}
