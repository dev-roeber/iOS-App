import XCTest
@testable import LocationHistoryConsumer
import LocationHistoryConsumerAppSupport

final class GPXBuilderTests: XCTestCase {

    // MARK: - Filename

    func testSuggestedFilenameEmpty() {
        XCTAssertEqual(GPXBuilder.suggestedFilename(for: []), "lh2gpx-export.gpx")
    }

    func testSuggestedFilenameOneDay() {
        XCTAssertEqual(GPXBuilder.suggestedFilename(for: ["2024-01-15"]), "lh2gpx-2024-01-15.gpx")
    }

    func testSuggestedFilenameMultipleDays() {
        let filename = GPXBuilder.suggestedFilename(for: ["2024-01-20", "2024-01-10", "2024-01-15"])
        XCTAssertEqual(filename, "lh2gpx-2024-01-10_to_2024-01-20.gpx")
    }

    // MARK: - XML Structure

    func testBuildNoDaysProducesValidShell() {
        let gpx = GPXBuilder.build(from: [])
        XCTAssertTrue(gpx.contains(#"<?xml version="1.0""#))
        XCTAssertTrue(gpx.contains(#"<gpx version="1.1""#))
        XCTAssertTrue(gpx.contains("</gpx>"))
        XCTAssertFalse(gpx.contains("<trk>"))
    }

    func testBuildDayWithNoPathsProducesNoTracks() {
        let day = Day(date: "2024-01-15", visits: [], activities: [], paths: [])
        let gpx = GPXBuilder.build(from: [day])
        XCTAssertFalse(gpx.contains("<trk>"))
    }

    func testBuildPathWithNoPointsProducesNoTrack() {
        let path = Path(
            startTime: nil, endTime: nil, activityType: "WALKING",
            distanceM: nil, sourceType: nil,
            points: [], flatCoordinates: nil
        )
        let day = Day(date: "2024-01-15", visits: [], activities: [], paths: [path])
        let gpx = GPXBuilder.build(from: [day])
        XCTAssertFalse(gpx.contains("<trk>"))
    }

    func testBuildSinglePathSinglePoint() {
        let pt = PathPoint(lat: 47.123456, lon: 8.654321, time: "2024-01-15T10:23:00Z", accuracyM: nil)
        let path = Path(
            startTime: nil, endTime: nil, activityType: "WALKING",
            distanceM: nil, sourceType: nil,
            points: [pt], flatCoordinates: nil
        )
        let day = Day(date: "2024-01-15", visits: [], activities: [], paths: [path])
        let gpx = GPXBuilder.build(from: [day])

        XCTAssertTrue(gpx.contains("<trk>"))
        XCTAssertTrue(gpx.contains("<trkseg>"))
        XCTAssertTrue(gpx.contains("lat=\"47.12345600\""))
        XCTAssertTrue(gpx.contains("lon=\"8.65432100\""))
        XCTAssertTrue(gpx.contains("<time>2024-01-15T10:23:00Z</time>"))
        XCTAssertTrue(gpx.contains("Walking"))
    }

    func testBuildPointWithoutTimeOmitsTimeElement() {
        let pt = PathPoint(lat: 47.0, lon: 8.0, time: nil, accuracyM: nil)
        let path = Path(
            startTime: nil, endTime: nil, activityType: nil,
            distanceM: nil, sourceType: nil,
            points: [pt], flatCoordinates: nil
        )
        let day = Day(date: "2024-01-15", visits: [], activities: [], paths: [path])
        let gpx = GPXBuilder.build(from: [day])

        XCTAssertTrue(gpx.contains("<trk>"))
        XCTAssertFalse(gpx.contains("<time>"))
    }

    func testBuildMultiplePathsSameDay() {
        let pt = PathPoint(lat: 47.0, lon: 8.0, time: nil, accuracyM: nil)
        let path1 = Path(startTime: nil, endTime: nil, activityType: "WALKING", distanceM: nil, sourceType: nil, points: [pt], flatCoordinates: nil)
        let path2 = Path(startTime: nil, endTime: nil, activityType: "CYCLING", distanceM: nil, sourceType: nil, points: [pt, pt], flatCoordinates: nil)
        let day = Day(date: "2024-01-15", visits: [], activities: [], paths: [path1, path2])
        let gpx = GPXBuilder.build(from: [day])

        let trackCount = gpx.components(separatedBy: "<trk>").count - 1
        XCTAssertEqual(trackCount, 2)
    }

    func testBuildMultipleDaysEachProducesTrack() {
        let pt = PathPoint(lat: 47.0, lon: 8.0, time: nil, accuracyM: nil)
        let path = Path(startTime: nil, endTime: nil, activityType: nil, distanceM: nil, sourceType: nil, points: [pt], flatCoordinates: nil)
        let day1 = Day(date: "2024-01-10", visits: [], activities: [], paths: [path])
        let day2 = Day(date: "2024-01-11", visits: [], activities: [], paths: [path])
        let gpx = GPXBuilder.build(from: [day1, day2])

        let trackCount = gpx.components(separatedBy: "<trk>").count - 1
        XCTAssertEqual(trackCount, 2)
        XCTAssertTrue(gpx.contains("2024-01-10"))
        XCTAssertTrue(gpx.contains("2024-01-11"))
    }

    func testXMLEscapingInActivityType() {
        let pt = PathPoint(lat: 47.0, lon: 8.0, time: nil, accuracyM: nil)
        let path = Path(startTime: nil, endTime: nil, activityType: "Rock & Roll", distanceM: nil, sourceType: nil, points: [pt], flatCoordinates: nil)
        let day = Day(date: "2024-01-15", visits: [], activities: [], paths: [path])
        let gpx = GPXBuilder.build(from: [day])

        XCTAssertTrue(gpx.contains("Rock &amp; Roll"))
        XCTAssertFalse(gpx.contains("Rock & Roll"))
    }

    func testBuildFromGoldenFixture() throws {
        let export = try loadGoldenExport()
        let days = AppExportQueries.days(in: export)
        let gpx = GPXBuilder.build(from: days)

        XCTAssertTrue(gpx.contains(#"<?xml version="1.0""#))
        XCTAssertTrue(gpx.contains(#"<gpx version="1.1""#))
        XCTAssertTrue(gpx.contains("</gpx>"))
        // Golden fixture has paths → expect at least one track
        let totalPaths = days.flatMap(\.paths).filter { !$0.points.isEmpty }.count
        let trackCount = gpx.components(separatedBy: "<trk>").count - 1
        XCTAssertEqual(trackCount, totalPaths)
    }

    // MARK: - ExportSelectionState

    func testSelectionStartsEmpty() {
        let state = ExportSelectionState()
        XCTAssertTrue(state.isEmpty)
        XCTAssertEqual(state.count, 0)
    }

    func testToggleAddsAndRemoves() {
        var state = ExportSelectionState()
        state.toggle("2024-01-15")
        XCTAssertTrue(state.isSelected("2024-01-15"))
        XCTAssertEqual(state.count, 1)
        state.toggle("2024-01-15")
        XCTAssertFalse(state.isSelected("2024-01-15"))
        XCTAssertEqual(state.count, 0)
    }

    func testSelectAll() {
        var state = ExportSelectionState()
        state.selectAll(from: ["2024-01-10", "2024-01-11", "2024-01-12"])
        XCTAssertEqual(state.count, 3)
        XCTAssertTrue(state.isSelected("2024-01-11"))
    }

    func testClearAll() {
        var state = ExportSelectionState()
        state.selectAll(from: ["2024-01-10", "2024-01-11"])
        state.clearAll()
        XCTAssertTrue(state.isEmpty)
    }

    // MARK: - Helpers

    private func loadGoldenExport() throws -> AppExport {
        let url = try TestSupport.contractFixtureURL(named: "golden_app_export_contract_gate.json")
        let data = try Data(contentsOf: url)
        return try AppExportDecoder.decode(data: data)
    }
}
