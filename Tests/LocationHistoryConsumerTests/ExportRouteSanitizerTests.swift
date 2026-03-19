import XCTest
@testable import LocationHistoryConsumer

final class ExportRouteSanitizerTests: XCTestCase {
    func testSanitizedPathRemovesConsecutiveDuplicatePoints() throws {
        let duplicate = PathPoint(lat: 48.0, lon: 11.0, time: "2024-05-01T08:00:00Z", accuracyM: nil)
        let unique = PathPoint(lat: 48.001, lon: 11.001, time: "2024-05-01T08:05:00Z", accuracyM: nil)
        let path = Path(
            startTime: "2024-05-01T08:00:00Z",
            endTime: "2024-05-01T08:05:00Z",
            activityType: "WALKING",
            distanceM: 700,
            sourceType: "imported",
            points: [duplicate, duplicate, unique],
            flatCoordinates: nil
        )

        let sanitized = try XCTUnwrap(ExportRouteSanitizer.sanitizedPath(path))

        XCTAssertEqual(sanitized.points.count, 2)
        XCTAssertEqual(sanitized.points.first?.lat, duplicate.lat)
        XCTAssertEqual(sanitized.points.last?.lat, unique.lat)
    }

    func testSanitizedDayDropsRoutesThatCollapseBelowTwoPoints() throws {
        let duplicate = PathPoint(lat: 48.0, lon: 11.0, time: "2024-05-01T08:00:00Z", accuracyM: nil)
        let uniqueA = PathPoint(lat: 48.001, lon: 11.001, time: "2024-05-01T08:05:00Z", accuracyM: nil)
        let uniqueB = PathPoint(lat: 48.002, lon: 11.002, time: "2024-05-01T08:10:00Z", accuracyM: nil)
        let duplicateOnlyPath = Path(
            startTime: nil,
            endTime: nil,
            activityType: "WALKING",
            distanceM: 0,
            sourceType: "imported",
            points: [duplicate, duplicate],
            flatCoordinates: nil
        )
        let exportablePath = Path(
            startTime: nil,
            endTime: nil,
            activityType: "CYCLING",
            distanceM: 1200,
            sourceType: "imported",
            points: [duplicate, uniqueA, uniqueA, uniqueB],
            flatCoordinates: nil
        )
        let day = Day(
            date: "2024-05-01",
            visits: [],
            activities: [],
            paths: [duplicateOnlyPath, exportablePath]
        )

        let sanitized = try XCTUnwrap(ExportRouteSanitizer.sanitizedDay(day))

        XCTAssertEqual(ExportRouteSanitizer.exportablePathCount(in: day), 1)
        XCTAssertEqual(sanitized.paths.count, 1)
        XCTAssertEqual(sanitized.paths[0].points.count, 3)
        XCTAssertEqual(sanitized.paths[0].activityType, "CYCLING")
    }
}
