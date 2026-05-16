import XCTest
@testable import LocationHistoryConsumerAppSupport

final class LiveTrackRenderCapTests: XCTestCase {

    private func makePoints(_ count: Int) -> [RecordedTrackPoint] {
        (0..<count).map { i in
            RecordedTrackPoint(
                latitude: 48.0 + Double(i) * 0.0001,
                longitude: 11.0 + Double(i) * 0.0001,
                timestamp: Date(timeIntervalSince1970: TimeInterval(i)),
                horizontalAccuracyM: 5.0
            )
        }
    }

    func testCapDisabledReturnsAllPoints() {
        let pts = makePoints(5_000)
        let result = LiveTrackRenderCap.apply(points: pts, cap: 0)
        XCTAssertFalse(result.wasCapped)
        XCTAssertEqual(result.renderedCount, 5_000)
        XCTAssertEqual(result.originalCount, 5_000)
        XCTAssertEqual(result.points.first, pts.first)
        XCTAssertEqual(result.points.last, pts.last)
    }

    func testCountUnderCapReturnsAllPoints() {
        let pts = makePoints(100)
        let result = LiveTrackRenderCap.apply(points: pts, cap: 200)
        XCTAssertFalse(result.wasCapped)
        XCTAssertEqual(result.renderedCount, 100)
        XCTAssertEqual(result.points, pts)
    }

    func testCountEqualToCapReturnsAllPoints() {
        let pts = makePoints(200)
        let result = LiveTrackRenderCap.apply(points: pts, cap: 200)
        XCTAssertFalse(result.wasCapped)
        XCTAssertEqual(result.renderedCount, 200)
    }

    func testCapEnforcedWhenOverflow() {
        let pts = makePoints(10_000)
        let result = LiveTrackRenderCap.apply(points: pts, cap: 2_000)
        XCTAssertTrue(result.wasCapped)
        XCTAssertLessThanOrEqual(result.renderedCount, 2_000)
        XCTAssertEqual(result.originalCount, 10_000)
    }

    func testCapPreservesFirstAndLastPoints() {
        let pts = makePoints(10_000)
        let result = LiveTrackRenderCap.apply(points: pts, cap: 1_000)
        XCTAssertTrue(result.wasCapped)
        XCTAssertEqual(result.points.first, pts.first, "Track-start point must be preserved")
        XCTAssertEqual(result.points.last, pts.last, "Current-position point must be preserved")
    }

    func testCapKeepsTailVerbatim() {
        let pts = makePoints(10_000)
        let cap = 1_000
        let result = LiveTrackRenderCap.apply(points: pts, cap: cap)
        XCTAssertTrue(result.wasCapped)
        // The trailing half of the budget is the most-recent half of the original points.
        let tailCount = cap / 2
        let expectedTail = Array(pts.suffix(tailCount))
        let actualTail = Array(result.points.suffix(tailCount))
        XCTAssertEqual(actualTail, expectedTail, "Most-recent half must be byte-identical to source tail")
    }

    func testEmptyInputReturnsEmpty() {
        let result = LiveTrackRenderCap.apply(points: [], cap: 1_000)
        XCTAssertFalse(result.wasCapped)
        XCTAssertEqual(result.renderedCount, 0)
        XCTAssertEqual(result.originalCount, 0)
    }

    func testSinglePointInputReturnsSinglePoint() {
        let pts = makePoints(1)
        let result = LiveTrackRenderCap.apply(points: pts, cap: 1_000)
        XCTAssertFalse(result.wasCapped)
        XCTAssertEqual(result.renderedCount, 1)
        XCTAssertEqual(result.points.first, pts.first)
    }

    func testNegativeCapIsTreatedAsDisabled() {
        let pts = makePoints(500)
        let result = LiveTrackRenderCap.apply(points: pts, cap: -1)
        XCTAssertFalse(result.wasCapped)
        XCTAssertEqual(result.renderedCount, 500)
    }

    func testDeterministicForSameInput() {
        let pts = makePoints(5_000)
        let r1 = LiveTrackRenderCap.apply(points: pts, cap: 1_000)
        let r2 = LiveTrackRenderCap.apply(points: pts, cap: 1_000)
        XCTAssertEqual(r1, r2, "Same input must produce identical output")
    }
}
