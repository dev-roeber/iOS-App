import XCTest
@testable import LocationHistoryConsumerAppSupport

final class WidgetDataStoreTests: XCTestCase {
    func testLastRecordingFormattedDistance() {
        let rec = WidgetDataStore.LastRecording(date: Date(), distanceMeters: 5230, durationSeconds: 1800, trackName: "Test")
        XCTAssertEqual(rec.formattedDistance, "5.2 km")
    }

    func testLastRecordingFormattedDistanceMeters() {
        let rec = WidgetDataStore.LastRecording(date: Date(), distanceMeters: 450, durationSeconds: 600, trackName: "Test")
        XCTAssertEqual(rec.formattedDistance, "450 m")
    }

    func testLastRecordingFormattedDuration() {
        let rec = WidgetDataStore.LastRecording(date: Date(), distanceMeters: 1000, durationSeconds: 3660, trackName: "Test")
        XCTAssertEqual(rec.formattedDuration, "1h 1m")
    }

    func testLastRecordingCodable() throws {
        let rec = WidgetDataStore.LastRecording(date: Date(timeIntervalSince1970: 1000000), distanceMeters: 3000, durationSeconds: 900, trackName: "Runde")
        let data = try JSONEncoder().encode(rec)
        let decoded = try JSONDecoder().decode(WidgetDataStore.LastRecording.self, from: data)
        XCTAssertEqual(decoded.distanceMeters, 3000)
        XCTAssertEqual(decoded.trackName, "Runde")
    }
}
