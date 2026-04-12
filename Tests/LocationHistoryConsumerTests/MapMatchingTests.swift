import XCTest
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class MapMatchingTests: XCTestCase {

    // MARK: - Straight-line reduction

    /// A straight row of collinear points should collapse to just the two endpoints.
    func testStraightLineReducesToEndpoints() {
        // Five points in a straight horizontal line separated by ~100 m each.
        let points: [LocationCoordinate2D] = [
            LocationCoordinate2D(latitude: 48.0000, longitude: 11.0000),
            LocationCoordinate2D(latitude: 48.0000, longitude: 11.0010),
            LocationCoordinate2D(latitude: 48.0000, longitude: 11.0020),
            LocationCoordinate2D(latitude: 48.0000, longitude: 11.0030),
            LocationCoordinate2D(latitude: 48.0000, longitude: 11.0040),
        ]

        let simplified = PathSimplification.douglasPeucker(points, epsilon: 1.0)

        // All intermediate points are exactly on the line, so they should be dropped.
        XCTAssertEqual(simplified.count, 2, "Straight line should reduce to 2 points")
        XCTAssertEqual(simplified.first?.latitude,  points.first?.latitude)
        XCTAssertEqual(simplified.first?.longitude, points.first?.longitude)
        XCTAssertEqual(simplified.last?.latitude,   points.last?.latitude)
        XCTAssertEqual(simplified.last?.longitude,  points.last?.longitude)
    }

    // MARK: - Original data preservation

    /// The source array must remain unchanged after simplification.
    func testOriginalPointsAreNeverMutated() {
        let points: [LocationCoordinate2D] = [
            LocationCoordinate2D(latitude: 48.1000, longitude: 11.5000),
            LocationCoordinate2D(latitude: 48.1100, longitude: 11.5100),
            LocationCoordinate2D(latitude: 48.1050, longitude: 11.5200),
            LocationCoordinate2D(latitude: 48.1150, longitude: 11.5300),
            LocationCoordinate2D(latitude: 48.1200, longitude: 11.5400),
        ]
        let copy = points

        _ = PathSimplification.douglasPeucker(points, epsilon: 15.0)

        for (original, afterCall) in zip(copy, points) {
            XCTAssertEqual(original.latitude,  afterCall.latitude,  accuracy: 1e-9)
            XCTAssertEqual(original.longitude, afterCall.longitude, accuracy: 1e-9)
        }
    }

    // MARK: - Epsilon = 0 keeps all points

    /// With epsilon = 0 every intermediate point has a perpendicular distance > 0,
    /// so the algorithm must keep all points.
    func testEpsilonZeroKeepsAllPoints() {
        // Non-collinear zigzag so every middle point is off the chord.
        let points: [LocationCoordinate2D] = [
            LocationCoordinate2D(latitude: 48.0000, longitude: 11.0000),
            LocationCoordinate2D(latitude: 48.0010, longitude: 11.0010),
            LocationCoordinate2D(latitude: 48.0000, longitude: 11.0020),
            LocationCoordinate2D(latitude: 48.0010, longitude: 11.0030),
            LocationCoordinate2D(latitude: 48.0000, longitude: 11.0040),
        ]

        let simplified = PathSimplification.douglasPeucker(points, epsilon: 0.0)

        XCTAssertEqual(simplified.count, points.count,
                       "epsilon=0 must keep all points because every deviation is > 0")
    }

    // MARK: - Edge cases

    func testEmptyInputReturnsEmpty() {
        let result = PathSimplification.douglasPeucker([], epsilon: 15.0)
        XCTAssertTrue(result.isEmpty)
    }

    func testSinglePointReturnsSinglePoint() {
        let point = LocationCoordinate2D(latitude: 48.0, longitude: 11.0)
        let result = PathSimplification.douglasPeucker([point], epsilon: 15.0)
        XCTAssertEqual(result.count, 1)
    }

    func testTwoPointsReturnBothPoints() {
        let p1 = LocationCoordinate2D(latitude: 48.0, longitude: 11.0)
        let p2 = LocationCoordinate2D(latitude: 48.1, longitude: 11.1)
        let result = PathSimplification.douglasPeucker([p1, p2], epsilon: 15.0)
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - AppDayPathDisplayMode

    func testAppDayPathDisplayModeDefaultIsOriginal() {
        MainActor.assumeIsolated {
            let suiteName = "MapMatchingTests-\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            defaults.removePersistentDomain(forName: suiteName)
            let prefs = AppPreferences(userDefaults: defaults)
            XCTAssertEqual(prefs.dayPathDisplayMode, .original)
            defaults.removePersistentDomain(forName: suiteName)
        }
    }

    func testAppDayPathDisplayModeRoundTrip() {
        MainActor.assumeIsolated {
            let suiteName = "MapMatchingTests-\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            defaults.removePersistentDomain(forName: suiteName)
            let prefs = AppPreferences(userDefaults: defaults)

            prefs.dayPathDisplayMode = .mapMatched

            let prefs2 = AppPreferences(userDefaults: defaults)
            XCTAssertEqual(prefs2.dayPathDisplayMode, .mapMatched)
            defaults.removePersistentDomain(forName: suiteName)
        }
    }

    func testResetRestoresDayPathDisplayModeToOriginal() {
        MainActor.assumeIsolated {
            let suiteName = "MapMatchingTests-\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            defaults.removePersistentDomain(forName: suiteName)
            let prefs = AppPreferences(userDefaults: defaults)

            prefs.dayPathDisplayMode = .mapMatched
            prefs.reset()

            XCTAssertEqual(prefs.dayPathDisplayMode, .original)
            defaults.removePersistentDomain(forName: suiteName)
        }
    }
}
