import XCTest
@testable import LocationHistoryConsumer

final class RouteQualitySummaryTests: XCTestCase {

    // MARK: - Empty / minimal

    func testEmptyArrayYieldsEmptyLevel() {
        let summary = RouteQualitySummary.evaluate(points: [])
        XCTAssertEqual(summary, .empty)
        XCTAssertEqual(summary.level, .empty)
        XCTAssertEqual(summary.pointCount, 0)
        XCTAssertNil(summary.averageSpacingM)
        XCTAssertNil(summary.largestGapM)
    }

    func testSinglePointIsSparseWithoutSpacing() {
        let summary = RouteQualitySummary.evaluate(points: [(lat: 0, lon: 0)])
        XCTAssertEqual(summary.level, .sparse)
        XCTAssertEqual(summary.pointCount, 1)
        XCTAssertNil(summary.averageSpacingM)
        XCTAssertNil(summary.largestGapM)
    }

    // MARK: - Haversine sanity

    func testHaversineOneDegreeLatitudeIsAboutOneEleventhOfEarthCircumference() {
        // 1° latitude ≈ 111 km. Allow ±5 % tolerance for the spherical
        // approximation.
        let d = RouteQualitySummary.haversineMetres((0, 0), (1, 0))
        XCTAssertEqual(d, 111_195, accuracy: 5_500)
    }

    func testHaversineZeroDistance() {
        let d = RouteQualitySummary.haversineMetres((50, 10), (50, 10))
        XCTAssertEqual(d, 0, accuracy: 1e-9)
    }

    // MARK: - Sparse / good / contains-gaps thresholds

    func testRouteWithFewerThanThresholdPointsIsSparse() {
        // 5 closely spaced points are sparse by the count rule.
        var pts: [(lat: Double, lon: Double)] = []
        for i in 0..<5 {
            pts.append((lat: 0.0, lon: Double(i) * 0.001))
        }
        let summary = RouteQualitySummary.evaluate(points: pts)
        XCTAssertEqual(summary.level, .sparse)
        XCTAssertEqual(summary.pointCount, 5)
    }

    func testRouteWithEnoughEvenlySpacedPointsIsGood() {
        // 50 points, ~111 m apart (1e-3°). No large gaps.
        var pts: [(lat: Double, lon: Double)] = []
        for i in 0..<50 {
            pts.append((lat: 0.0, lon: Double(i) * 0.001))
        }
        let summary = RouteQualitySummary.evaluate(points: pts)
        XCTAssertEqual(summary.level, .good)
        XCTAssertEqual(summary.pointCount, 50)
        XCTAssertNotNil(summary.averageSpacingM)
        XCTAssertNotNil(summary.largestGapM)
    }

    func testRouteWithSingleLargeGapIsFlaggedContainsGaps() {
        // 30 closely spaced points + 1 point ~110 km away.
        var pts: [(lat: Double, lon: Double)] = []
        for i in 0..<30 {
            pts.append((lat: 0.0, lon: Double(i) * 0.001))
        }
        // Big jump: roughly 110 km in latitude.
        pts.append((lat: 1.0, lon: 0.03))
        let summary = RouteQualitySummary.evaluate(points: pts)
        XCTAssertEqual(summary.level, .containsGaps,
                       "A 110 km jump must trigger the gap heuristic.")
        XCTAssertNotNil(summary.largestGapM)
        XCTAssertGreaterThan(summary.largestGapM ?? 0, RouteQualitySummary.gapAbsoluteFloorM)
    }

    func testRouteWithUniformShortSpacingDoesNotTripGapHeuristicEvenAt100Points() {
        // Even spacing — no point pair exceeds 5x the average and the
        // absolute gap floor.
        var pts: [(lat: Double, lon: Double)] = []
        for i in 0..<100 {
            pts.append((lat: 0.0, lon: Double(i) * 0.001))
        }
        let summary = RouteQualitySummary.evaluate(points: pts)
        XCTAssertEqual(summary.level, .good)
        // largestGap should be ~equal to averageSpacing.
        if let avg = summary.averageSpacingM, let largest = summary.largestGapM {
            XCTAssertEqual(largest, avg, accuracy: avg * 0.05)
        } else {
            XCTFail("avg and largest should be present for a 100-point route")
        }
    }

    // MARK: - Stability / privacy

    func testAllLevelsAreReachableFromCaseIterable() {
        let cases = RouteQualitySummary.Level.allCases
        XCTAssertEqual(Set(cases.map(\.rawValue)),
                       ["empty", "sparse", "containsGaps", "good"])
    }

    func testSummaryStringDescriptionContainsNoLatLonValues() {
        var pts: [(lat: Double, lon: Double)] = []
        for i in 0..<20 {
            pts.append((lat: 50.123456, lon: Double(i) * 0.001))
        }
        let summary = RouteQualitySummary.evaluate(points: pts)
        let dump = "\(summary)"
        XCTAssertFalse(dump.contains("50.123456"),
                       "Summary description must not echo raw coordinates.")
    }
}
