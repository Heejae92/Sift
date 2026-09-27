import CoreGraphics
import Testing
@testable import Sift

struct SwipeGeometryTests {
    @Test func sectorsAreFourEqualQuadrants() {
        #expect(SwipeGeometry.sector(dx: 100, dy: 0, current: nil) == .archive)
        #expect(SwipeGeometry.sector(dx: 0, dy: -100, current: nil) == .fave)
        #expect(SwipeGeometry.sector(dx: -100, dy: 0, current: nil) == .trash)
        #expect(SwipeGeometry.sector(dx: 0, dy: 100, current: nil) == .down)
        #expect(SwipeGeometry.rawSector(angle: 45) == .archive)     // boundary belongs to the lower sector
        #expect(SwipeGeometry.rawSector(angle: 45.1) == .fave)
        #expect(SwipeGeometry.rawSector(angle: 315.1) == .archive)
    }

    @Test func hysteresisHoldsTheCurrentSectorNearABoundary() {
        // 47° is 2° into FAVE; with 6° of hysteresis ARCHIVE holds
        let dx: CGFloat = 100, dy = -CGFloat(100 * tan(47.0 * .pi / 180))
        #expect(SwipeGeometry.sector(dx: dx, dy: dy, current: .archive) == .archive)
        #expect(SwipeGeometry.sector(dx: dx, dy: dy, current: nil) == .fave)
        // 60° is 15° into FAVE; ARCHIVE lets go
        let dy2 = -CGFloat(100 * tan(60.0 * .pi / 180))
        #expect(SwipeGeometry.sector(dx: dx, dy: dy2, current: .archive) == .fave)
        #expect(SwipeGeometry.sector(dx: 0, dy: 0, current: .trash) == .trash)
    }

    @Test func commitByDistanceOrByVelocityWithTravelFloor() {
        #expect(SwipeGeometry.shouldCommit(distance: DSSwipe.commitDistance, velocityAlongAxis: 0))
        #expect(!SwipeGeometry.shouldCommit(distance: DSSwipe.commitDistance - 1, velocityAlongAxis: 0))
        #expect(SwipeGeometry.shouldCommit(distance: DSSwipe.minTravelForVelocity, velocityAlongAxis: DSSwipe.commitVelocity))
        #expect(!SwipeGeometry.shouldCommit(distance: DSSwipe.minTravelForVelocity - 1, velocityAlongAxis: DSSwipe.commitVelocity * 2))
        #expect(!SwipeGeometry.shouldCommit(distance: 60, velocityAlongAxis: -DSSwipe.commitVelocity))
    }

    @Test func rotationIsClampedAndStampRampMatchesTheCommitDistance() {
        #expect(SwipeGeometry.rotationDegrees(dx: 60) == 3)
        #expect(SwipeGeometry.rotationDegrees(dx: 1000) == Double(DSSwipe.maxRotationDegrees))
        #expect(SwipeGeometry.rotationDegrees(dx: -1000) == -Double(DSSwipe.maxRotationDegrees))
        #expect(SwipeGeometry.stampOpacity(distance: DSSwipe.stampRevealStart) == 0)
        #expect(SwipeGeometry.stampOpacity(distance: DSSwipe.commitDistance) == 1)
        #expect(abs(SwipeGeometry.stampOpacity(distance: 60) - 0.4) < 0.0001)
    }

    @Test func velocityProjectsOntoTheSectorAxis() {
        #expect(SwipeGeometry.velocityAlongAxis(velocity: CGSize(width: -900, height: 10), sector: .trash) == 900)
        #expect(SwipeGeometry.velocityAlongAxis(velocity: CGSize(width: 0, height: -900), sector: .fave) == 900)
    }
}
