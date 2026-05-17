import XCTest
@testable import LocationHistoryConsumer

final class ImportValidationSummaryTests: XCTestCase {

    // MARK: - Empty / minimal

    func testEmptyExportYieldsEmptySummary() {
        let summary = ImportValidationSummary.summarize(makeExport(days: []))
        XCTAssertEqual(summary, .empty)
        XCTAssertEqual(summary.dayCount, 0)
        XCTAssertTrue(summary.warnings.contains(.emptyImport))
    }

    func testEmptyConstantIsConsistent() {
        let empty = ImportValidationSummary.empty
        XCTAssertEqual(empty.dayCount, 0)
        XCTAssertNil(empty.firstDate)
        XCTAssertNil(empty.lastDate)
        XCTAssertEqual(empty.totalPathPointCount, 0)
        XCTAssertEqual(empty.warnings, [.emptyImport])
    }

    // MARK: - Single day with points

    func testSingleDayWithPointsSummarisesCounts() {
        let day = Day(
            date: "2024-06-01",
            visits: [],
            activities: [],
            paths: [makePath(points: [(1.0, 2.0), (3.0, 4.0), (5.0, 6.0)])]
        )
        let summary = ImportValidationSummary.summarize(makeExport(days: [day]))
        XCTAssertEqual(summary.dayCount, 1)
        XCTAssertEqual(summary.pathCount, 1)
        XCTAssertEqual(summary.totalPathPointCount, 3)
        XCTAssertEqual(summary.firstDate, "2024-06-01")
        XCTAssertEqual(summary.lastDate, "2024-06-01")
        XCTAssertTrue(summary.warnings.contains(.singleDayOnly))
        XCTAssertFalse(summary.warnings.contains(.noGPSPoints))
    }

    // MARK: - Date range

    func testMultiDayDateRangeIsSortedNotInsertionOrder() {
        let days = [
            Day(date: "2024-06-15", visits: [], activities: [], paths: []),
            Day(date: "2024-06-01", visits: [], activities: [], paths: [makePath(points: [(0, 0)])]),
            Day(date: "2024-06-30", visits: [], activities: [], paths: []),
        ]
        let summary = ImportValidationSummary.summarize(makeExport(days: days))
        XCTAssertEqual(summary.firstDate, "2024-06-01")
        XCTAssertEqual(summary.lastDate, "2024-06-30")
        XCTAssertEqual(summary.dayCount, 3)
        XCTAssertFalse(summary.warnings.contains(.singleDayOnly))
    }

    // MARK: - Counts

    func testVisitAndActivityCountsAccumulate() {
        let visit = Visit(lat: 1.0, lon: 2.0, startTime: nil, endTime: nil,
                          semanticType: nil, placeID: nil, accuracyM: nil, sourceType: nil)
        let activity = Activity(startTime: nil, endTime: nil,
                                startLat: nil, startLon: nil, endLat: nil, endLon: nil,
                                activityType: "walking", distanceM: nil,
                                splitFromMidnight: nil, startAccuracyM: nil,
                                endAccuracyM: nil, sourceType: nil,
                                flatCoordinates: nil)
        let day = Day(date: "2024-06-01",
                      visits: [visit, visit],
                      activities: [activity, activity, activity],
                      paths: [])
        let summary = ImportValidationSummary.summarize(makeExport(days: [day]))
        XCTAssertEqual(summary.visitCount, 2)
        XCTAssertEqual(summary.activityCount, 3)
        XCTAssertEqual(summary.pathCount, 0)
    }

    // MARK: - Flat coordinate geometry

    func testFlatCoordinatesAreCountedByPair() {
        let day = Day(
            date: "2024-06-01",
            visits: [],
            activities: [],
            paths: [makePath(flatCoordinates: [1, 2, 3, 4, 5, 6])]
        )
        let summary = ImportValidationSummary.summarize(makeExport(days: [day]))
        XCTAssertEqual(summary.totalPathPointCount, 3,
                       "6 doubles encode 3 (lat, lon) pairs.")
    }

    func testOddFlatCoordinateArrayIsIgnored() {
        let day = Day(
            date: "2024-06-01",
            visits: [],
            activities: [],
            paths: [makePath(flatCoordinates: [1, 2, 3])]
        )
        let summary = ImportValidationSummary.summarize(makeExport(days: [day]))
        XCTAssertEqual(summary.totalPathPointCount, 0,
                       "Odd-length flatCoordinates are malformed and must not be counted.")
    }

    // MARK: - Warnings

    func testNoGPSPointsWarningWhenAllPathsAndVisitsAreEmpty() {
        let day = Day(date: "2024-06-01", visits: [], activities: [], paths: [])
        let summary = ImportValidationSummary.summarize(makeExport(days: [day]))
        XCTAssertTrue(summary.warnings.contains(.noGPSPoints))
    }

    func testNoGPSPointsWarningSuppressedWhenVisitHasCoordinate() {
        let visit = Visit(lat: 50.0, lon: 10.0, startTime: nil, endTime: nil,
                          semanticType: nil, placeID: nil, accuracyM: nil, sourceType: nil)
        let day = Day(date: "2024-06-01", visits: [visit], activities: [], paths: [])
        let summary = ImportValidationSummary.summarize(makeExport(days: [day]))
        XCTAssertFalse(summary.warnings.contains(.noGPSPoints))
    }

    // MARK: - Privacy contract

    func testSummaryDoesNotExposeCoordinatesInStringDescription() {
        let visit = Visit(lat: 50.123456, lon: 10.987654, startTime: nil, endTime: nil,
                          semanticType: nil, placeID: "place_secret", accuracyM: nil, sourceType: nil)
        let day = Day(date: "2024-06-01",
                      visits: [visit],
                      activities: [],
                      paths: [makePath(points: [(50.111, 10.222)])])
        let summary = ImportValidationSummary.summarize(makeExport(days: [day]))
        let dumped = "\(summary)"
        XCTAssertFalse(dumped.contains("50.123456"))
        XCTAssertFalse(dumped.contains("10.987654"))
        XCTAssertFalse(dumped.contains("50.111"))
        XCTAssertFalse(dumped.contains("10.222"))
        XCTAssertFalse(dumped.contains("place_secret"))
    }

    // MARK: - Helpers (Foundation only, no real coordinates leak into Doku)

    private func makeExport(days: [Day]) -> AppExport {
        AppExport(
            schemaVersion: .v1_0,
            meta: Meta(
                exportedAt: "2024-06-01T00:00:00Z",
                toolVersion: "test",
                source: Source(zipBasename: nil, zipPath: nil, inputFormat: "records"),
                output: Output(outDir: nil),
                config: ExportConfig(
                    mode: "all", splitMidnight: nil, splitMode: "daily",
                    exportFormat: ["json"], inputFormat: "auto"
                ),
                filters: ExportFilters(
                    fromDate: nil, toDate: nil, year: nil, month: nil,
                    weekday: nil, limit: nil, days: nil, has: nil,
                    maxAccuracyM: nil, activityTypes: nil, minGapMin: nil
                )
            ),
            data: DataBlock(days: days),
            stats: nil
        )
    }

    private func makePath(points: [(Double, Double)] = [],
                          flatCoordinates: [Double]? = nil) -> Path {
        Path(
            startTime: nil, endTime: nil,
            activityType: nil,
            distanceM: nil,
            sourceType: nil,
            points: points.map { PathPoint(lat: $0.0, lon: $0.1, time: nil, accuracyM: nil) },
            flatCoordinates: flatCoordinates
        )
    }
}
