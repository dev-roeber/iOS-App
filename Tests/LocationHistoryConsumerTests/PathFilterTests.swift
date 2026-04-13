import XCTest
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class PathFilterTests: XCTestCase {

    // MARK: - Edge cases

    func testEmptyInput() {
        let empty: [LocationCoordinate2D] = []
        XCTAssertEqual(PathFilter.removeOutliers(empty), empty)
    }

    func testSinglePoint() {
        let p = LocationCoordinate2D(latitude: 48.0, longitude: 11.0)
        XCTAssertEqual(PathFilter.removeOutliers([p] as [LocationCoordinate2D]), [p])
    }

    func testTwoClosePointsKeptUnchanged() {
        let a = LocationCoordinate2D(latitude: 48.0000, longitude: 11.0000)
        let b = LocationCoordinate2D(latitude: 48.0005, longitude: 11.0000) // ~55 m
        let result = PathFilter.removeOutliers([a, b])
        XCTAssertEqual(result, [a, b])
    }

    // MARK: - Normal tracks are not affected

    func testKeepsNormalWalkingPoints() {
        // Five points ~50 m apart — well within default 5 000 m
        let points: [LocationCoordinate2D] = (0..<5).map {
            LocationCoordinate2D(latitude: 48.0 + Double($0) * 0.0005, longitude: 11.0)
        }
        XCTAssertEqual(PathFilter.removeOutliers(points), points)
    }

    func testKeepsDrivingPoints() {
        // Points ~500 m apart — still within default threshold
        let points: [LocationCoordinate2D] = (0..<5).map {
            LocationCoordinate2D(latitude: 48.0 + Double($0) * 0.005, longitude: 11.0)
        }
        XCTAssertEqual(PathFilter.removeOutliers(points), points)
    }

    // MARK: - Outlier removal

    func testRemovesImpossibleJump() {
        // a → outlier (>5 000 m) → c (close to a)
        let a       = LocationCoordinate2D(latitude: 48.0000, longitude: 11.0000)
        let outlier = LocationCoordinate2D(latitude: 48.0000, longitude: 12.0000) // ~78 km
        let c       = LocationCoordinate2D(latitude: 48.0005, longitude: 11.0000) // ~55 m from a
        let result  = PathFilter.removeOutliers([a, outlier, c])
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0], a)
        XCTAssertEqual(result[1], c)
    }

    func testRemovesOutlierAndKeepsReturn() {
        // a → b (close) → outlier → d (close to b, accepted via last-accepted logic)
        let a       = LocationCoordinate2D(latitude: 48.0000, longitude: 11.0000)
        let b       = LocationCoordinate2D(latitude: 48.0010, longitude: 11.0000) // ~111 m from a
        let outlier = LocationCoordinate2D(latitude: 48.0000, longitude: 12.0000) // ~78 km from b
        let d       = LocationCoordinate2D(latitude: 48.0020, longitude: 11.0000) // ~111 m from b
        let result  = PathFilter.removeOutliers([a, b, outlier, d])
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result, [a, b, d])
    }

    // MARK: - Fallback

    func testFallbackWhenFilterLeavesFewerThanTwoPoints() {
        // Both points are >5 000 m apart; only a is accepted → fallback to original
        let a = LocationCoordinate2D(latitude: 48.0, longitude: 11.0)
        let b = LocationCoordinate2D(latitude: 49.0, longitude: 12.0) // >100 km
        let result = PathFilter.removeOutliers([a, b])
        // b is filtered, result = [a] → count < 2 → return original
        XCTAssertEqual(result, [a, b])
    }

    // MARK: - Custom threshold

    func testCustomThresholdFiltersCloserJump() {
        let a = LocationCoordinate2D(latitude: 48.0000, longitude: 11.0000)
        let b = LocationCoordinate2D(latitude: 48.0000, longitude: 11.0020) // ~156 m
        let c = LocationCoordinate2D(latitude: 48.0000, longitude: 11.0025) // ~39 m from b
        // With 100 m: b removed (156 m > 100); c checked against a (~195 m > 100) → removed → fallback
        let strict = PathFilter.removeOutliers([a, b, c], maxJumpMeters: 100)
        XCTAssertEqual(strict, [a, b, c]) // fallback: original returned
        // With default 5 000 m: all three kept
        let loose = PathFilter.removeOutliers([a, b, c])
        XCTAssertEqual(loose.count, 3)
    }
}
