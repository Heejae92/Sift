import SwiftUI

/// UI_DESIGN §10 "Toast": a capsule anchored at the top, one line, no action button. Undo lives on
/// exactly one control, the rewind button, so a toast never offers one. Used for "Not deleted"
/// after the system dialog is cancelled, and for failures (§11.3, §12).
///
/// `toast` fill with `onToast` text in `DSTextRole.labelSmall`, `DSRadius.pill`,
/// `DSShadow.floating` (a toast floats), `DSLayer.toast`. It enters with `DSMotion.enter`, stays
/// `DSMotion.toastVisible`, then sets the binding back to nil and exits with `DSMotion.exit`; both
/// curves go through `DSMotion.gated` (P-15). A new message restarts the timer.
///
/// VoiceOver hears it as a high-priority announcement, so the system dialog closing does not cut it
/// off. It never takes focus and never blocks a tap: moving focus mid-task would lose the user's
/// place in the queue.
struct ToastModifier: ViewModifier {
    @Binding private var message: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(message: Binding<String?>) {
        _message = message
    }

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            ZStack(alignment: .top) {
                if let message {
                    capsule(message)
                }
            }
            .animation(DSMotion.gated(message == nil ? DSMotion.exit : DSMotion.enter, reduce: reduceMotion),
                       value: message)
        }
    }

    private func capsule(_ text: String) -> some View {
        Text(text)
            .dsType(.labelSmall)
            .foregroundStyle(DSColor.onToast)
            .multilineTextAlignment(.center)
            .padding(.vertical, DSSpace.s3)
            .padding(.horizontal, DSSpace.s5)
            .background(DSColor.toast, in: RoundedRectangle(cornerRadius: DSRadius.pill, style: .continuous))
            .dsShadow(.floating)
            .padding(.horizontal, DSGrid.mobileMargin)
            .padding(.top, DSSpace.s2)
            .allowsHitTesting(false)
            .transition(.move(edge: .top).combined(with: .opacity))
            .zIndex(DSLayer.toast)
            .task(id: text) {
                await present(text)
            }
    }

    /// Announce, hold for `DSMotion.toastVisible`, then clear. A cancelled wait clears nothing:
    /// either a newer message owns the timer now, or the host screen has gone.
    private func present(_ text: String) async {
        var announcement = AttributedString(text)
        announcement.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(announcement).post()
        do {
            try await Task.sleep(for: .seconds(DSMotion.toastVisible))
            message = nil
        } catch {
            return
        }
    }
}

extension View {
    /// Shows `message` as the top toast of UI_DESIGN §10, then sets it back to nil after
    /// `DSMotion.toastVisible`.
    func dsToast(_ message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}
