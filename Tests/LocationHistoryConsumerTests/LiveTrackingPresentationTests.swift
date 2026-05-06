import XCTest
@testable import LocationHistoryConsumerAppSupport

final class LiveTrackingPresentationTests: XCTestCase {
    func testMetricsCalculateDistanceSpeedAndLatestSampleDate() {
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
            currentLocation: currentLocation
        )

        XCTAssertGreaterThan(snapshot.totalDistanceM, 600)
        XCTAssertNotNil(snapshot.currentSpeedKMH)
        XCTAssertNotNil(snapshot.lastSegmentDistanceM)
        XCTAssertEqual(snapshot.lastSampleDate, currentLocation.timestamp)
    }

    func testMetricsStayGracefulWithoutAcceptedPoints() {
        let snapshot = LiveTrackingPresentation.metrics(
            points: [],
            currentLocation: nil
        )

        XCTAssertEqual(snapshot.totalDistanceM, 0)
        XCTAssertNil(snapshot.currentSpeedKMH)
        XCTAssertNil(snapshot.lastSegmentDistanceM)
        XCTAssertNil(snapshot.lastSampleDate)
    }

    // MARK: - GPS Status

    func testGPSStatusIsGoodForHighAccuracy() {
        XCTAssertEqual(LiveTrackingPresentation.gpsStatusLabel(accuracyM: 10), "GPS Good")
    }

    func testGPSStatusIsGoodAtThreshold() {
        XCTAssertEqual(LiveTrackingPresentation.gpsStatusLabel(accuracyM: 29), "GPS Good")
    }

    func testGPSStatusIsWeakAtThreshold() {
        XCTAssertEqual(LiveTrackingPresentation.gpsStatusLabel(accuracyM: 30), "GPS Weak")
    }

    func testGPSStatusIsWeakForLowAccuracy() {
        XCTAssertEqual(LiveTrackingPresentation.gpsStatusLabel(accuracyM: 80), "GPS Weak")
    }

    func testGPSStatusIsSearchingWhenNoLocation() {
        XCTAssertEqual(LiveTrackingPresentation.gpsStatusLabel(accuracyM: nil), "GPS Searching")
    }

    // MARK: - Upload Section Visibility

    func testUploadSectionVisibleWhenServerEnabled() {
        XCTAssertTrue(LiveTrackingPresentation.uploadSectionVisible(
            sendsToServer: true, pendingCount: 0, statusMessage: nil
        ))
    }

    func testUploadSectionVisibleWhenQueueNonEmpty() {
        XCTAssertTrue(LiveTrackingPresentation.uploadSectionVisible(
            sendsToServer: false, pendingCount: 3, statusMessage: nil
        ))
    }

    func testUploadSectionVisibleWhenStatusMessagePresent() {
        XCTAssertTrue(LiveTrackingPresentation.uploadSectionVisible(
            sendsToServer: false, pendingCount: 0, statusMessage: "Upload ready."
        ))
    }

    func testUploadSectionHiddenWhenAllInactive() {
        XCTAssertFalse(LiveTrackingPresentation.uploadSectionVisible(
            sendsToServer: false, pendingCount: 0, statusMessage: nil
        ))
    }
}
