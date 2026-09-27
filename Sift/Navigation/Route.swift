import Foundation

/// The pushes of IA §3. Review is the root; the Viewer and the purge sheet are presentations, not routes.
enum Route: Hashable, Sendable {
    case trash
    case library
    case credits
}
