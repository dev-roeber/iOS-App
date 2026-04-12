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

    func testFormattedDistanceNegativeClampedToZero() {
        let status = TrackingStatus(isRecording: false, distanceMeters: -5, pointCount: 0)
        XCTAssertEqual(status.formattedDistance, "0 m")
    }

    func testFormattedDistanceVeryLarge() {
        let status = TrackingStatus(isRecording: true, distanceMeters: 42_195, pointCount: 999)
        XCTAssertEqual(status.formattedDistance, "42.2 km")
    }

    // MARK: TrackingStatus default init

    func testTrackingStatusDefaultValues() {
        let status = TrackingStatus(isRecording: false, distanceMeters: 0, pointCount: 0)
        XCTAssertFalse(status.isRecording)
        XCTAssertEqual(status.distanceMeters, 0)
        XCTAssertEqual(status.pointCount, 0)
        XCTAssertFalse(status.isPaused)
        XCTAssertEqual(status.uploadQueueCount, 0)
        XCTAssertNil(status.lastUploadSuccess)
    }

    func testTrackingStatusIsRecordingTrue() {
        let status = TrackingStatus(isRecording: true, distanceMeters: 500, pointCount: 5)
        XCTAssertTrue(status.isRecording)
        XCTAssertEqual(status.distanceMeters, 500)
        XCTAssertEqual(status.pointCount, 5)
    }

    func testTrackingStatusNewFieldsRoundTrip() {
        let status = TrackingStatus(
            isRecording: true,
            distanceMeters: 1500,
            pointCount: 12,
            isPaused: true,
            uploadQueueCount: 7,
            lastUploadSuccess: false
        )
        XCTAssertTrue(status.isPaused)
        XCTAssertEqual(status.uploadQueueCount, 7)
        XCTAssertEqual(status.lastUploadSuccess, false)
    }

    func testTrackingStatusLastUploadSuccessTrue() {
        let status = TrackingStatus(
            isRecording: true,
            distanceMeters: 200,
            pointCount: 3,
            lastUploadSuccess: true
        )
        XCTAssertEqual(status.lastUploadSuccess, true)
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

    func testTrackingStatusCodableRoundTripWithNewFields() throws {
        let original = TrackingStatus(
            isRecording: true,
            distanceMeters: 1234.0,
            pointCount: 20,
            isPaused: true,
            uploadQueueCount: 3,
            lastUploadSuccess: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TrackingStatus.self, from: data)
        XCTAssertEqual(decoded.isPaused, true)
        XCTAssertEqual(decoded.uploadQueueCount, 3)
        XCTAssertEqual(decoded.lastUploadSuccess, true)
    }

    func testTrackingStatusCodableRoundTripNilLastUploadSuccess() throws {
        let original = TrackingStatus(isRecording: false, distanceMeters: 0, pointCount: 0)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TrackingStatus.self, from: data)
        XCTAssertNil(decoded.lastUploadSuccess)
        XCTAssertFalse(decoded.isPaused)
        XCTAssertEqual(decoded.uploadQueueCount, 0)
    }

    func testTrackingStatusLegacyDecodingUsesDefaults() throws {
        // A JSON payload that has only the three original fields (simulating an older version)
        // should decode successfully with defaults for new fields.
        let legacyJSON = """
        {"isRecording":true,"distanceMeters":800,"pointCount":8}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(TrackingStatus.self, from: legacyJSON)
        XCTAssertTrue(decoded.isRecording)
        XCTAssertEqual(decoded.distanceMeters, 800, accuracy: 0.001)
        XCTAssertEqual(decoded.pointCount, 8)
        XCTAssertFalse(decoded.isPaused)
        XCTAssertEqual(decoded.uploadQueueCount, 0)
        XCTAssertNil(decoded.lastUploadSuccess)
    }

    // MARK: ActivityManager throttle logic

    func testActivityManagerThrottleSkipsRapidUpdates() {
        // We can't call the real ActivityManager (requires iOS device + ActivityKit),
        // but we can verify the throttle gate logic via a lightweight harness.
        var throttle = ThrottleGate(interval: 5)
        XCTAssertTrue(throttle.shouldAllow(at: Date(timeIntervalSince1970: 0)))
        XCTAssertFalse(throttle.shouldAllow(at: Date(timeIntervalSince1970: 2)))
        XCTAssertFalse(throttle.shouldAllow(at: Date(timeIntervalSince1970: 4.9)))
        XCTAssertTrue(throttle.shouldAllow(at: Date(timeIntervalSince1970: 5)))
        XCTAssertFalse(throttle.shouldAllow(at: Date(timeIntervalSince1970: 9.9)))
        XCTAssertTrue(throttle.shouldAllow(at: Date(timeIntervalSince1970: 10)))
    }

    func testActivityManagerThrottleAlwaysAllowsFirst() {
        var throttle = ThrottleGate(interval: 5)
        // The very first call must pass regardless of the reference date.
        XCTAssertTrue(throttle.shouldAllow(at: Date(timeIntervalSince1970: 1)))
    }

    func testActivityManagerThrottleResetAfterStop() {
        var throttle = ThrottleGate(interval: 5)
        _ = throttle.shouldAllow(at: Date(timeIntervalSince1970: 0))
        // Simulate reset (endActivity always bypasses throttle; test that after reset
        // the next allow goes through immediately).
        throttle.reset()
        XCTAssertTrue(throttle.shouldAllow(at: Date(timeIntervalSince1970: 1)))
    }
}

// MARK: - Test helper: lightweight throttle gate (mirrors ActivityManager's logic)

/// A minimal throttle gate used in tests to verify the update-rate-limiting logic
/// without depending on ActivityKit or the real ActivityManager singleton.
private struct ThrottleGate {
    let interval: TimeInterval
    private var lastAllowed: Date = .distantPast

    init(interval: TimeInterval) {
        self.interval = interval
    }

    mutating func shouldAllow(at now: Date) -> Bool {
        guard now.timeIntervalSince(lastAllowed) >= interval else { return false }
        lastAllowed = now
        return true
    }

    mutating func reset() {
        lastAllowed = .distantPast
    }
}
