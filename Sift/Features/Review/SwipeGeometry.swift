import Foundation
import CoreGraphics

enum SwipeSector: Equatable, Sendable {
    case archive, fave, trash, down

    var verdict: Verdict? {
        switch self {
        case .archive: return .archive
        case .fave: return .fave
        case .trash: return .trash
        case .down: return nil
        }
    }

    /// Unit vector of the sector's axis, in view coordinates (y grows downward).
    var axis: CGVector {
        switch self {
        case .archive: return CGVector(dx: 1, dy: 0)
        case .trash: return CGVector(dx: -1, dy: 0)
        case .fave: return CGVector(dx: 0, dy: -1)
        case .down: return CGVector(dx: 0, dy: 1)
        }
    }

    fileprivate var centerAngle: Double {
        switch self {
        case .archive: return 0
        case .fave: return 90
        case .trash: return 180
        case .down: return 270
        }
    }
}

/// The gesture arithmetic of ADR-019, as pure functions over `DSSwipe`. Mirrors the deck script in
/// `design-system.html` line for line so the two cannot drift.
enum SwipeGeometry {
    /// θ = atan2(−dy, dx), normalised to [0, 360). 0° is right, 90° is up.
    static func angle(dx: CGFloat, dy: CGFloat) -> Double {
        var deg = atan2(Double(-dy), Double(dx)) * 180 / .pi
        deg = deg.truncatingRemainder(dividingBy: 360)
        if deg < 0 { deg += 360 }
        return deg
    }

    /// Four equal quadrants: ARCHIVE (−45, 45] · FAVE (45, 135] · TRASH (135, 225] · DOWN (225, 315].
    static func rawSector(angle: Double) -> SwipeSector {
        if angle > 315 || angle <= 45 { return .archive }
        if angle <= 135 { return .fave }
        if angle <= 225 { return .trash }
        return .down
    }

    /// The sector for a drag, holding the current one until θ crosses `sectorHysteresisDegrees`
    /// into the neighbour. `nil` when the finger has not moved.
    static func sector(dx: CGFloat, dy: CGFloat, current: SwipeSector?) -> SwipeSector? {
        if dx == 0 && dy == 0 { return current }
        let deg = angle(dx: dx, dy: dy)
        let raw = rawSector(angle: deg)
        guard let current, raw != current else { return raw }
        let off = abs(((deg - current.centerAngle + 540).truncatingRemainder(dividingBy: 360)) - 180)
        return off <= 45 + Double(DSSwipe.sectorHysteresisDegrees) ? current : raw
    }

    /// Commit on distance, or on velocity along the sector axis once the travel floor is met.
    static func shouldCommit(distance: CGFloat, velocityAlongAxis: CGFloat) -> Bool {
        distance >= DSSwipe.commitDistance
            || (velocityAlongAxis >= DSSwipe.commitVelocity && distance >= DSSwipe.minTravelForVelocity)
    }

    static func rotationDegrees(dx: CGFloat) -> Double {
        let raw = Double(dx / DSSwipe.rotationDivisor)
        return min(max(raw, -Double(DSSwipe.maxRotationDegrees)), Double(DSSwipe.maxRotationDegrees))
    }

    /// 0 at `stampRevealStart`, 1 at `stampRevealEnd` (= the commit distance).
    static func stampOpacity(distance: CGFloat) -> Double {
        let span = DSSwipe.stampRevealEnd - DSSwipe.stampRevealStart
        let t = (distance - DSSwipe.stampRevealStart) / span
        return Double(min(max(t, 0), 1))
    }

    /// Lift on an upward drag: 1 at rest, `upScale` at the commit distance.
    static func upScale(distance: CGFloat) -> CGFloat {
        1 + (DSSwipe.upScale - 1) * min(distance / DSSwipe.commitDistance, 1)
    }

    static func velocityAlongAxis(velocity: CGSize, sector: SwipeSector) -> CGFloat {
        velocity.width * sector.axis.dx + velocity.height * sector.axis.dy
    }
}
