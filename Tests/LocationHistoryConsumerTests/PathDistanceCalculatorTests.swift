import XCTest
@testable import LocationHistoryConsumer

/// Coverage for the bug fix where day-detail showed `Distance 0` while
/// summary/insights computed the right total. Audit observation: the
/// summary path used a polyline-fallback (`effectiveDistance`) but the
/// detail path read `distanceM` raw, so geometry-only Google Timeline
/// imports rendered as 0 km in the day-detail metric card.
final class PathDistanceCalculatorTests: XCTestCase {

    // MARK: - Calculator semantics

    func testRawDistanceWinsWhenFinitePositive() {
        let result = PathDistanceCalculator.effectiveDistance(
            rawDistanceM: 1234.5,
            points: [(lat: 0, lon: 0), (lat: 0, lon: 1)],
            flatCoordinates: nil
        )
        XCTAssertEqual(result, 1234.5, accuracy: 0.001)
    }

    func testNilDistanceFallsBackToPolyline() {
        let result = PathDistanceCalculator.effectiveDistance(
            rawDistanceM: nil,
            points: [(lat: 52.5200, lon: 13.4050), (lat: 52.5163, lon: 13.3777)],
            flatCoordinates: nil
        )
        XCTAssertGreaterThan(result, 1500)
        XCTAssertLessThan(result, 3000)
    }

    func testZeroDistanceFallsBackToPolyline() {
        let result = PathDistanceCalculator.effectiveDistance(
            rawDistanceM: 0,
            points: [(lat: 0, lon: 0), (lat: 0, lon: 1)],
            flatCoordinates: nil
        )
        XCTAssertGreaterThan(result, 100_000)
    }

    func testNegativeDistanceFallsBackToPolyline() {
        let result = PathDistanceCalculator.effectiveDistance(
            rawDistanceM: -500,
            points: [(lat: 0, lon: 0), (lat: 0, lon: 1)],
            flatCoordinates: nil
        )
        XCTAssertGreaterThan(result, 100_000)
    }

    func testNonFiniteDistanceFallsBackToPolyline() {
        let result = PathDistanceCalculator.effectiveDistance(
            rawDistanceM: .nan,
            points: [(lat: 0, lon: 0), (lat: 0, lon: 1)],
            flatCoordinates: nil
        )
        XCTAssertGreaterThan(result, 100_000)
    }

    func testFlatCoordinatesUsedWhenPointsMissing() {
        let result = PathDistanceCalculator.effectiveDistance(
            rawDistanceM: nil,
            points: [],
            flatCoordinates: [52.5200, 13.4050, 52.5163, 13.3777]
        )
        XCTAssertGreaterThan(result, 1500)
        XCTAssertLessThan(result, 3000)
    }

    func testTooFewPointsAndNoFlatYieldsZero() {
        XCTAssertEqual(
            PathDistanceCalculator.effectiveDistance(
                rawDistanceM: nil,
                points: [(lat: 0, lon: 0)],
                flatCoordinates: nil
            ),
            0
        )
        XCTAssertEqual(
            PathDistanceCalculator.effectiveDistance(
                rawDistanceM: nil,
                points: [],
                flatCoordinates: nil
            ),
            0
        )
    }

    // MARK: - Path / PathItem wrappers

    func testPathWrapperPrefersExplicitDistance() {
        let path = Path(
            startTime: nil,
            endTime: nil,
            activityType: "WALKING",
            distanceM: 999,
            sourceType: nil,
            points: [PathPoint(lat: 0, lon: 0, time: nil, accuracyM: nil)],
            flatCoordinates: nil
        )
        XCTAssertEqual(PathDistanceCalculator.effectiveDistance(for: path), 999)
    }

    func testPathWrapperFallsBackForGeometryOnlyTimelinePath() {
        let path = Path(
            startTime: "2026-01-01T08:00:00Z",
            endTime: "2026-01-01T09:00:00Z",
            activityType: nil,
            distanceM: nil,
            sourceType: "google_timeline",
            points: [
                PathPoint(lat: 52.5200, lon: 13.4050, time: nil, accuracyM: nil),
                PathPoint(lat: 52.5163, lon: 13.3777, time: nil, accuracyM: nil)
            ],
            flatCoordinates: nil
        )
        let result = PathDistanceCalculator.effectiveDistance(for: path)
        XCTAssertGreaterThan(result, 1500)
        XCTAssertLessThan(result, 3000)
    }

    func testPathItemWrapperFallsBackForGeometryOnly() {
        let pathItem = DayDetailViewState.PathItem(
            startTime: nil,
            endTime: nil,
            activityType: nil,
            distanceM: nil,
            effectiveDistanceM: 0, // intentionally wrong — wrapper recomputes
            pointCount: 2,
            sourceType: "google_timeline",
            points: [
                DayDetailViewState.PathPointItem(lat: 52.5200, lon: 13.4050, time: nil, accuracyM: nil),
                DayDetailViewState.PathPointItem(lat: 52.5163, lon: 13.3777, time: nil, accuracyM: nil)
            ]
        )
        let result = PathDistanceCalculator.effectiveDistance(for: pathItem)
        XCTAssertGreaterThan(result, 1500)
        XCTAssertLessThan(result, 3000)
    }

    // MARK: - Summary / Detail consistency (the regression that motivates
    // this calculator). Both paths must produce identical totals for the
    // same day so Insights, Overview and Day Detail never disagree.

    func testSummaryAndDayDetailAgreeOnGeometryOnlyDay() throws {
        let path = Path(
            startTime: "2026-01-01T08:00:00Z",
            endTime: "2026-01-01T09:00:00Z",
            activityType: "WALKING",
            distanceM: nil,
            sourceType: "google_timeline",
            points: [
                PathPoint(lat: 52.5200, lon: 13.4050, time: nil, accuracyM: nil),
                PathPoint(lat: 52.5163, lon: 13.3777, time: nil, accuracyM: nil),
                PathPoint(lat: 52.5096, lon: 13.3760, time: nil, accuracyM: nil)
            ],
            flatCoordinates: nil
        )
        let day = Day(date: "2026-01-01", visits: [], activities: [], paths: [path])
        let export = AppExport(
            schemaVersion: .v1_0,
            meta: Meta(
                exportedAt: "2026-01-01T00:00:00Z",
                toolVersion: "test/1.0",
                source: Source(zipBasename: nil, zipPath: nil, inputFormat: "test"),
                output: Output(outDir: nil),
                config: ExportConfig(
                    mode: nil,
                    splitMidnight: nil,
                    splitMode: nil,
                    exportFormat: nil,
                    inputFormat: "test"
                ),
                filters: ExportFilters(
                    fromDate: nil, toDate: nil, year: nil, month: nil, weekday: nil,
                    limit: nil, days: nil, has: nil, maxAccuracyM: nil,
                    activityTypes: nil, minGapMin: nil
                )
            ),
            data: DataBlock(days: [day]),
            stats: nil
        )

        let summaries = AppExportQueries.daySummaries(from: export)
        let summary = try XCTUnwrap(summaries.first { $0.date == "2026-01-01" })
        let detail = try XCTUnwrap(AppExportQueries.dayDetail(for: "2026-01-01", in: export))
        let detailTotal = detail.paths.reduce(0.0) { $0 + $1.effectiveDistanceM }

        XCTAssertGreaterThan(summary.totalPathDistanceM, 0,
                             "Summary must reconstruct distance from polyline when distanceM is nil")
        XCTAssertEqual(detailTotal, summary.totalPathDistanceM, accuracy: 0.001,
                       "Day-detail effectiveDistanceM must agree with summary totalPathDistanceM — that's the bug fix.")
    }

    func testDetailDoesNotReportZeroWhenGeometryIsPresent() throws {
        let path = Path(
            startTime: nil,
            endTime: nil,
            activityType: nil,
            distanceM: nil,
            sourceType: "google_timeline",
            points: [
                PathPoint(lat: 0, lon: 0, time: nil, accuracyM: nil),
                PathPoint(lat: 0, lon: 1, time: nil, accuracyM: nil)
            ],
            flatCoordinates: nil
        )
        let day = Day(date: "2026-01-02", visits: [], activities: [], paths: [path])
        let export = AppExport(
            schemaVersion: .v1_0,
            meta: Meta(
                exportedAt: "2026-01-01T00:00:00Z",
                toolVersion: "test/1.0",
                source: Source(zipBasename: nil, zipPath: nil, inputFormat: "test"),
                output: Output(outDir: nil),
                config: ExportConfig(
                    mode: nil,
                    splitMidnight: nil,
                    splitMode: nil,
                    exportFormat: nil,
                    inputFormat: "test"
                ),
                filters: ExportFilters(
                    fromDate: nil, toDate: nil, year: nil, month: nil, weekday: nil,
                    limit: nil, days: nil, has: nil, maxAccuracyM: nil,
                    activityTypes: nil, minGapMin: nil
                )
            ),
            data: DataBlock(days: [day]),
            stats: nil
        )
        let detail = try XCTUnwrap(AppExportQueries.dayDetail(for: "2026-01-02", in: export))
        let pathItem = try XCTUnwrap(detail.paths.first)
        XCTAssertNil(pathItem.distanceM, "Raw distanceM must remain nil so callers can still tell exporter said nothing")
        XCTAssertGreaterThan(pathItem.effectiveDistanceM, 0,
                             "effectiveDistanceM must be > 0 when valid geometry is present, regardless of raw distanceM")
    }
}
