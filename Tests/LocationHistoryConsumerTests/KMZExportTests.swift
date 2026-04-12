import XCTest
import Foundation
import ZIPFoundation
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class KMZExportTests: XCTestCase {

    // Minimal fixture: one day with one path
    private var sampleDays: [Day] {
        let pt1 = PathPoint(lat: 48.137, lon: 11.575, time: "2023-11-15T10:00:00Z", accuracyM: nil)
        let pt2 = PathPoint(lat: 48.138, lon: 11.576, time: "2023-11-15T10:01:00Z", accuracyM: nil)
        let path = Path(
            startTime: "2023-11-15T10:00:00Z",
            endTime: "2023-11-15T10:01:00Z",
            activityType: "WALKING",
            distanceM: nil,
            sourceType: nil,
            points: [pt1, pt2],
            flatCoordinates: nil
        )
        let day = Day(date: "2023-11-15", visits: [], activities: [], paths: [path])
        return [day]
    }

    func testBuildProducesNonEmptyData() throws {
        let data = try KMZBuilder.build(from: sampleDays, mode: .tracks)
        XCTAssertFalse(data.isEmpty, "KMZ data should not be empty")
    }

    func testBuildIsValidZip() throws {
        let data = try KMZBuilder.build(from: sampleDays, mode: .tracks)
        // ZIP files start with PK signature (0x504B0304)
        XCTAssertGreaterThanOrEqual(data.count, 4)
        XCTAssertEqual(data[0], 0x50) // 'P'
        XCTAssertEqual(data[1], 0x4B) // 'K'
    }

    func testBuildContainsDocKml() throws {
        let data = try KMZBuilder.build(from: sampleDays, mode: .tracks)
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".kmz")
        defer { try? FileManager.default.removeItem(at: tmpURL) }
        try data.write(to: tmpURL)
        let archive = try Archive(url: tmpURL, accessMode: .read)
        let entry = archive["doc.kml"]
        XCTAssertNotNil(entry, "KMZ must contain doc.kml")
    }

    func testDocKmlContainsValidKMLContent() throws {
        let data = try KMZBuilder.build(from: sampleDays, mode: .tracks)
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".kmz")
        defer { try? FileManager.default.removeItem(at: tmpURL) }
        try data.write(to: tmpURL)
        let archive = try Archive(url: tmpURL, accessMode: .read)
        guard let entry = archive["doc.kml"] else {
            XCTFail("doc.kml not found")
            return
        }
        var kmlData = Data()
        _ = try archive.extract(entry) { chunk in kmlData.append(chunk) }
        let kmlString = String(data: kmlData, encoding: .utf8)
        XCTAssertNotNil(kmlString)
        XCTAssertTrue(kmlString!.contains("<?xml"), "KML must contain XML header")
        XCTAssertTrue(kmlString!.contains("<kml"), "KML must contain root element")
        XCTAssertTrue(kmlString!.contains("LineString"), "Track mode should produce LineString elements")
    }

    func testBuildEmptyDaysProducesValidKMZ() throws {
        let data = try KMZBuilder.build(from: [], mode: .tracks)
        XCTAssertFalse(data.isEmpty)
        // Should still be a valid ZIP
        XCTAssertEqual(data[0], 0x50)
        XCTAssertEqual(data[1], 0x4B)
    }

    func testWaypointModeContainsPlacemarks() throws {
        // Use a day with a visit (waypoint)
        let visit = Visit(
            lat: 48.137,
            lon: 11.575,
            startTime: "2023-11-15T10:00:00Z",
            endTime: "2023-11-15T11:00:00Z",
            semanticType: "RESTAURANT",
            placeID: nil,
            accuracyM: nil,
            sourceType: nil
        )
        let day = Day(date: "2023-11-15", visits: [visit], activities: [], paths: [])
        let data = try KMZBuilder.build(from: [day], mode: .waypoints)
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".kmz")
        defer { try? FileManager.default.removeItem(at: tmpURL) }
        try data.write(to: tmpURL)
        let archive = try Archive(url: tmpURL, accessMode: .read)
        guard let entry = archive["doc.kml"] else { XCTFail(); return }
        var kmlData = Data()
        _ = try archive.extract(entry) { chunk in kmlData.append(chunk) }
        let kmlString = String(data: kmlData, encoding: .utf8) ?? ""
        XCTAssertTrue(kmlString.contains("Point"), "Waypoint mode should produce Point elements")
    }
}
