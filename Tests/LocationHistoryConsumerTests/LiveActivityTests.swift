import XCTest
@testable import LocationHistoryConsumerAppSupport

final class LiveActivityTests: XCTestCase {

    // MARK: TrackingStatus.formattedDistance

    func testFormattedDistanceBelowOneKilometre() {
        let status = TrackingStatus(isRecording: true, distanceMeters: 850, pointCount: 10)
        XCTAssertEqual(status.formattedDistance, "850 m")
    }

    func testFormattedDistanceExactlyOneKilometre() {
        let status = TrackingStatus(isRecording: true, distanceMeters: 1000, pointCount: 20)
        XCTAssertEqual(status.formattedDistance, "1.0 km")
    }

    func testFormattedDistanceAboveOneKilometre() {
        let status = TrackingStatus(isRecording: true, distanceMeters: 1234.5, pointCount: 30)
        XCTAssertEqual(status.formattedDistance, "1.2 km")
    }

    func testFormattedDistanceZero() {
        let status = TrackingStatus(isRecording: true, distanceMeters: 0, pointCount: 0)
        XCTAssertEqual(status.formattedDistance, "0 m")
    }

    // MARK: TrackingStatus default init

    func testTrackingStatusDefaultValues() {
        let status = TrackingStatus(isRecording: false, distanceMeters: 0, pointCount: 0)
        XCTAssertFalse(status.isRecording)
        XCTAssertEqual(status.distanceMeters, 0)
        XCTAssertEqual(status.pointCount, 0)
    }

    func testTrackingStatusIsRecordingTrue() {
        let status = TrackingStatus(isRecording: true, distanceMeters: 500, pointCount: 5)
        XCTAssertTrue(status.isRecording)
        XCTAssertEqual(status.distanceMeters, 500)
        XCTAssertEqual(status.pointCount, 5)
    }

    // MARK: TrackingAttributes init (iOS-only because ActivityKit is unavailable on macOS)

    #if canImport(ActivityKit) && os(iOS)
    @available(iOS 16.1, *)
    func testTrackingAttributesStoresProperties() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let attrs = TrackingAttributes(trackName: "Morning Run", startTime: now)
        XCTAssertEqual(attrs.trackName, "Morning Run")
        XCTAssertEqual(attrs.startTime, now)
    }

    @available(iOS 16.1, *)
    func testTrackingAttributesEmptyTrackName() {
        let now = Date()
        let attrs = TrackingAttributes(trackName: "", startTime: now)
        XCTAssertEqual(attrs.trackName, "")
        XCTAssertEqual(attrs.startTime, now)
    }
    #endif

    // MARK: TrackingStatus Codable round-trip

    func testTrackingStatusCodableRoundTrip() throws {
        let original = TrackingStatus(isRecording: true, distanceMeters: 2500.75, pointCount: 42)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TrackingStatus.self, from: data)
        XCTAssertEqual(decoded.isRecording, original.isRecording)
        XCTAssertEqual(decoded.distanceMeters, original.distanceMeters, accuracy: 0.001)
        XCTAssertEqual(decoded.pointCount, original.pointCount)
    }
}
