import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-8A — Map-Domain-Modelle (Viewport, Bounds).
final class LocalTimelineMapBoundsTests: XCTestCase {

    func testValidViewport() {
        let vp = LocalTimelineMapViewport(minLat: 47.0, minLon: 10.0, maxLat: 49.0, maxLon: 12.0)
        XCTAssertNotNil(vp)
    }

    func testInvalidViewportFlippedLat() {
        XCTAssertNil(LocalTimelineMapViewport(minLat: 49.0, minLon: 10.0, maxLat: 47.0, maxLon: 12.0))
    }

    func testAntimeridianViewportRejected() {
        // minLon > maxLon → in Phase 8A kontrolliert abgelehnt.
        XCTAssertNil(LocalTimelineMapViewport(minLat: 0, minLon: 170, maxLat: 1, maxLon: -170))
    }

    func testOutOfRangeRejected() {
        XCTAssertNil(LocalTimelineMapViewport(minLat: -91, minLon: 0, maxLat: 0, maxLon: 0))
        XCTAssertNil(LocalTimelineMapViewport(minLat: 0, minLon: -181, maxLat: 0, maxLon: 0))
    }

    func testIntersectsClassicOverlap() {
        let vp = LocalTimelineMapViewport(minLat: 47, minLon: 10, maxLat: 49, maxLon: 12)!
        XCTAssertTrue(vp.intersects(minLat: 48, minLon: 11, maxLat: 48.5, maxLon: 11.5))
        XCTAssertTrue(vp.intersects(minLat: 46, minLon: 9,  maxLat: 47.5, maxLon: 10.5))
    }

    func testIntersectsDisjoint() {
        let vp = LocalTimelineMapViewport(minLat: 47, minLon: 10, maxLat: 49, maxLon: 12)!
        XCTAssertFalse(vp.intersects(minLat: 50, minLon: 13, maxLat: 51, maxLon: 14))
        XCTAssertFalse(vp.intersects(minLat: 30, minLon: 5,  maxLat: 31, maxLon: 6))
    }

    func testIntersectsNullBoundsTreatedAsOverlap() {
        let vp = LocalTimelineMapViewport(minLat: 0, minLon: 0, maxLat: 1, maxLon: 1)!
        XCTAssertTrue(vp.intersects(minLat: nil, minLon: nil, maxLat: nil, maxLon: nil))
    }

    func testPointBudgetDefaultsHonourLevels() {
        let overview = LocalTimelineMapPointBudget.default(for: .overview)
        let high     = LocalTimelineMapPointBudget.default(for: .high)
        XCTAssertLessThan(overview.maxPointsPerRoute, high.maxPointsPerRoute)
        XCTAssertLessThan(overview.maxTotalPoints, high.maxTotalPoints)
    }
}
