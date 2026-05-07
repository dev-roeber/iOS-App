import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Round-trip coverage: build GPX from a synthetic `[Day]` and reparse via
/// `GPXImportParser`, asserting that coordinates and counts survive within
/// floating-point tolerance. Locks down the export+import contract so a
/// regression on either side surfaces immediately (audit P1).
final class GPXRoundTripTests: XCTestCase {
    func testGPXImportThenExportPreservesCoordinates() throws {
        let originalDay = Day(
            date: "2024-06-10",
            visits: [],
            activities: [],
            paths: [
                Path(
                    startTime: "2024-06-10T08:00:00Z",
                    endTime: "2024-06-10T08:04:00Z",
                    activityType: "WALKING",
                    distanceM: 500,
                    sourceType: "timelinePath",
                    points: [
                        PathPoint(lat: 52.5200, lon: 13.4050, time: "2024-06-10T08:00:00Z", accuracyM: 5),
                        PathPoint(lat: 52.5210, lon: 13.4060, time: "2024-06-10T08:01:00Z", accuracyM: 5),
                        PathPoint(lat: 52.5220, lon: 13.4070, time: "2024-06-10T08:02:00Z", accuracyM: 5),
                        PathPoint(lat: 52.5230, lon: 13.4080, time: "2024-06-10T08:03:00Z", accuracyM: 5),
                        PathPoint(lat: 52.5240, lon: 13.4090, time: "2024-06-10T08:04:00Z", accuracyM: 5)
                    ],
                    flatCoordinates: nil
                )
            ]
        )

        let xml = GPXBuilder.build(from: [originalDay], mode: .tracks)
        let reimported = try GPXImportParser.parse(Data(xml.utf8), fileName: "rt.gpx")

        XCTAssertEqual(reimported.data.days.count, 1)
        let day = try XCTUnwrap(reimported.data.days.first)
        XCTAssertEqual(day.paths.count, 1)
        let path = try XCTUnwrap(day.paths.first)
        XCTAssertEqual(path.points.count, 5)

        for (original, reparsed) in zip(originalDay.paths[0].points, path.points) {
            XCTAssertEqual(original.lat, reparsed.lat, accuracy: 1e-6)
            XCTAssertEqual(original.lon, reparsed.lon, accuracy: 1e-6)
        }
    }

    func testGPXImportThenExportPreservesWaypoints() throws {
        let originalDay = Day(
            date: "2024-06-11",
            visits: [
                Visit(
                    lat: 52.5300,
                    lon: 13.4100,
                    startTime: "2024-06-11T09:00:00Z",
                    endTime: "2024-06-11T09:30:00Z",
                    semanticType: "HOME",
                    placeID: "home",
                    accuracyM: 5,
                    sourceType: "placeVisit"
                )
            ],
            activities: [],
            paths: []
        )

        let xml = GPXBuilder.build(from: [originalDay], mode: .waypoints)
        let reimported = try GPXImportParser.parse(Data(xml.utf8), fileName: "rt-wpt.gpx")

        XCTAssertEqual(reimported.data.days.count, 1)
        let day = try XCTUnwrap(reimported.data.days.first)
        XCTAssertEqual(day.visits.count, 1)
        let visit = try XCTUnwrap(day.visits.first)
        XCTAssertEqual(visit.lat ?? 0, 52.5300, accuracy: 1e-6)
        XCTAssertEqual(visit.lon ?? 0, 13.4100, accuracy: 1e-6)
    }
}
