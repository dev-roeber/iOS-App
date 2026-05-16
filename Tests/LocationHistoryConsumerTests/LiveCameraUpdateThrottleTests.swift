import XCTest
@testable import LocationHistoryConsumerAppSupport

final class LiveCameraUpdateThrottleTests: XCTestCase {

    private let munich = LiveCameraUpdateThrottle.Coordinate(latitude: 48.137, longitude: 11.575)
    private let munichNorth30m = LiveCameraUpdateThrottle.Coordinate(latitude: 48.13727, longitude: 11.575)
    private let munichNorth10m = LiveCameraUpdateThrottle.Coordinate(latitude: 48.13709, longitude: 11.575)

    func testFollowOffAlwaysSkips() {
        let decision = LiveCameraUpdateThrottle.shouldUpdate(
            isFollowing: false,
            coordinate: munich,
            now: Date(),
            lastUpdate: nil
        )
        XCTAssertEqual(decision, .skip)
    }

    func testFollowOnFirstUpdateAlwaysUpdates() {
        let decision = LiveCameraUpdateThrottle.shouldUpdate(
            isFollowing: true,
            coordinate: munich,
            now: Date(),
            lastUpdate: nil
        )
        XCTAssertEqual(decision, .update)
    }

    func testFollowOnSubIntervalSkips() {
        let now = Date()
        let decision = LiveCameraUpdateThrottle.shouldUpdate(
            isFollowing: true,
            coordinate: munichNorth30m,
            now: now,
            lastUpdate: (timestamp: now.addingTimeInterval(-0.2), coordinate: munich)
        )
        XCTAssertEqual(decision, .skip, "200ms elapsed + 30m moved must skip (interval threshold)")
    }

    func testFollowOnSubDistanceSkips() {
        let now = Date()
        let decision = LiveCameraUpdateThrottle.shouldUpdate(
            isFollowing: true,
            coordinate: munichNorth10m,
            now: now,
            lastUpdate: (timestamp: now.addingTimeInterval(-2.0), coordinate: munich)
        )
        XCTAssertEqual(decision, .skip, "2s elapsed + 10m moved must skip (distance threshold)")
    }

    func testFollowOnBothThresholdsCrossedUpdates() {
        let now = Date()
        let decision = LiveCameraUpdateThrottle.shouldUpdate(
            isFollowing: true,
            coordinate: munichNorth30m,
            now: now,
            lastUpdate: (timestamp: now.addingTimeInterval(-1.0), coordinate: munich)
        )
        XCTAssertEqual(decision, .update, "1s elapsed + 30m moved must update")
    }

    func testFollowOnSamePositionSkips() {
        let now = Date()
        let decision = LiveCameraUpdateThrottle.shouldUpdate(
            isFollowing: true,
            coordinate: munich,
            now: now,
            lastUpdate: (timestamp: now.addingTimeInterval(-10.0), coordinate: munich)
        )
        XCTAssertEqual(decision, .skip, "10s elapsed but 0m moved must skip")
    }

    func testCustomThresholdsHonoured() {
        let now = Date()
        // Tighter thresholds: 0.1s and 5m.
        let decision = LiveCameraUpdateThrottle.shouldUpdate(
            isFollowing: true,
            coordinate: munichNorth10m,
            now: now,
            lastUpdate: (timestamp: now.addingTimeInterval(-0.2), coordinate: munich),
            minInterval: 0.1,
            minDistanceMeters: 5.0
        )
        XCTAssertEqual(decision, .update)
    }

    func testDistanceMetersApproximatesGreatCircle() {
        let d30 = LiveCameraUpdateThrottle.Coordinate.distanceMeters(munich, munichNorth30m)
        XCTAssertEqual(d30, 30.0, accuracy: 2.0)
        let d10 = LiveCameraUpdateThrottle.Coordinate.distanceMeters(munich, munichNorth10m)
        XCTAssertEqual(d10, 10.0, accuracy: 1.0)
        let dZero = LiveCameraUpdateThrottle.Coordinate.distanceMeters(munich, munich)
        XCTAssertEqual(dZero, 0.0)
    }

    func testDeterministicForSameInput() {
        let now = Date()
        let last: (Date, LiveCameraUpdateThrottle.Coordinate) = (now.addingTimeInterval(-1.0), munich)
        let d1 = LiveCameraUpdateThrottle.shouldUpdate(
            isFollowing: true,
            coordinate: munichNorth30m,
            now: now,
            lastUpdate: (timestamp: last.0, coordinate: last.1)
        )
        let d2 = LiveCameraUpdateThrottle.shouldUpdate(
            isFollowing: true,
            coordinate: munichNorth30m,
            now: now,
            lastUpdate: (timestamp: last.0, coordinate: last.1)
        )
        XCTAssertEqual(d1, d2)
    }
}
