import XCTest
@testable import LocationHistoryConsumerAppSupport

final class LiveTrackingPresentationTests: XCTestCase {
    func testMetricsCalculateDistanceSpeedAndUpdateAge() {
        let start = Date(timeIntervalSince1970: 1_710_000_000)
        let points = [
            RecordedTrackPoint(latitude: 52.52, longitude: 13.40, timestamp: start, horizontalAccuracyM: 6),
            RecordedTrackPoint(latitude: 52.5209, longitude: 13.4090, timestamp: start.addingTimeInterval(60), horizontalAccuracyM: 6),
        ]
        let currentLocation = LiveLocationSample(
            latitude: 52.5210,
            longitude: 13.4100,
            timestamp: start.addingTimeInterval(90),
            horizontalAccuracyM: 5
        )

        let snapshot = LiveTrackingPresentation.metrics(
            points: points,
            currentLocation: currentLocation,
            referenceDate: start.addingTimeInterval(120),
            recordingDuration: 120
        )

        XCTAssertGreaterThan(snapshot.totalDistanceM, 600)
        XCTAssertNotNil(snapshot.currentSpeedKMH)
        XCTAssertNotNil(snapshot.averageSpeedKMH)
        XCTAssertNotNil(snapshot.lastSegmentDistanceM)
        XCTAssertEqual(snapshot.lastSampleDate, currentLocation.timestamp)
        XCTAssertEqual(snapshot.lastUpdateAge ?? -1, 30, accuracy: 0.001)
    }

    func testMetricsStayGracefulWithoutAcceptedPoints() {
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let snapshot = LiveTrackingPresentation.metrics(
            points: [],
            currentLocation: nil,
            referenceDate: now,
            recordingDuration: 0
        )

        XCTAssertEqual(snapshot.totalDistanceM, 0)
        XCTAssertNil(snapshot.currentSpeedKMH)
        XCTAssertNil(snapshot.averageSpeedKMH)
        XCTAssertNil(snapshot.lastSegmentDistanceM)
        XCTAssertNil(snapshot.lastSampleDate)
        XCTAssertNil(snapshot.lastUpdateAge)
    }
}
