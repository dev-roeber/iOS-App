import Foundation
import XCTest
@testable import LocationHistoryConsumer

final class AppExportQueriesTests: XCTestCase {
    func testBuildsOverviewFromDeterministicGolden() throws {
        let export = try loadExport(named: "golden_app_export_contract_gate.json")

        let overview = AppExportQueries.overview(from: export)

        XCTAssertEqual(overview.schemaVersion, "1.0")
        XCTAssertEqual(overview.exportedAt, "2024-01-02T03:04:05Z")
        XCTAssertEqual(overview.inputFormat, "records")
        XCTAssertEqual(overview.mode, "all")
        XCTAssertEqual(overview.splitMode, "single")
        XCTAssertEqual(overview.dayCount, 3)
        XCTAssertEqual(overview.totalVisitCount, 8)
        XCTAssertEqual(overview.totalActivityCount, 5)
        XCTAssertEqual(overview.totalPathCount, 5)
        XCTAssertEqual(overview.statsActivityTypes, ["CYCLING", "IN BUS", "IN PASSENGER VEHICLE", "UNKNOWN", "WALKING"])
    }

    func testBuildsDaySummariesInDeterministicDateOrder() throws {
        let export = try loadExport(named: "golden_app_export_multi_day_varied_structure.json")

        let summaries = AppExportQueries.daySummaries(from: export)

        XCTAssertEqual(summaries.map(\.date), ["2024-06-10", "2024-06-11", "2024-06-12"])
        XCTAssertTrue(summaries[0].hasContent)
        XCTAssertTrue(summaries[1].hasContent)
        XCTAssertFalse(summaries[2].hasContent)
        XCTAssertEqual(summaries[0].visitCount, 1)
        XCTAssertEqual(summaries[1].activityCount, 1)
        XCTAssertEqual(summaries[1].pathCount, 1)
        XCTAssertEqual(summaries[1].exportablePathCount, 1)
        XCTAssertEqual(summaries[1].totalPathPointCount, 3)
        XCTAssertEqual(summaries[1].totalPathDistanceM, 2410.0, accuracy: 0.0001)
        XCTAssertEqual(summaries[2].pathCount, 0)
        XCTAssertEqual(summaries[2].exportablePathCount, 0)
    }

    func testSortsSummariesEvenWhenDecodedDaysAreNotInOrder() throws {
        let export = try loadExportWithReversedDays(named: "golden_app_export_multi_day_varied_structure.json")

        let summaries = AppExportQueries.daySummaries(from: export)

        XCTAssertEqual(summaries.map(\.date), ["2024-06-10", "2024-06-11", "2024-06-12"])
    }

    func testFindDayAndInclusiveDateRangeSelection() throws {
        let export = try loadExport(named: "golden_app_export_multi_day_varied_structure.json")

        XCTAssertEqual(AppExportQueries.findDay(on: "2024-06-11", in: export)?.activities.count, 1)
        XCTAssertNil(AppExportQueries.findDay(on: "2024-06-13", in: export))

        let filtered = AppExportQueries.days(in: export, from: "2024-06-11", to: "2024-06-12")
        XCTAssertEqual(filtered.map(\.date), ["2024-06-11", "2024-06-12"])
    }

    func testOverviewAndSummariesHandleEmptyCollections() throws {
        let export = try loadExport(named: "golden_app_export_empty_collections_minimal.json")

        let overview = AppExportQueries.overview(from: export)
        let summaries = AppExportQueries.daySummaries(from: export)

        XCTAssertEqual(overview.dayCount, 1)
        XCTAssertEqual(overview.totalVisitCount, 0)
        XCTAssertEqual(overview.totalActivityCount, 0)
        XCTAssertEqual(overview.totalPathCount, 0)
        XCTAssertEqual(summaries.count, 1)
        XCTAssertFalse(summaries[0].hasContent)
        XCTAssertEqual(summaries[0].totalPathPointCount, 0)
        XCTAssertEqual(summaries[0].totalPathDistanceM, 0)
    }

    func testInsightsExposeAdditionalVisitAndRouteHighlights() throws {
        let export = try loadExport(named: "golden_app_export_contract_gate.json")

        let insights = AppExportQueries.insights(from: export)
        let summaries = AppExportQueries.daySummaries(from: export)
        let busiestSummary = try XCTUnwrap(
            summaries.max(by: {
                ($0.visitCount + $0.activityCount + $0.pathCount) < ($1.visitCount + $1.activityCount + $1.pathCount)
            })
        )
        let mostVisitsSummary = try XCTUnwrap(summaries.max(by: { $0.visitCount < $1.visitCount }))
        let mostRoutesSummary = try XCTUnwrap(summaries.max(by: { $0.pathCount < $1.pathCount }))
        let longestDistanceSummary = try XCTUnwrap(summaries.max(by: { $0.totalPathDistanceM < $1.totalPathDistanceM }))

        XCTAssertEqual(insights.busiestDay?.date, busiestSummary.date)
        XCTAssertEqual(insights.busiestDay?.value, "\(busiestSummary.visitCount + busiestSummary.activityCount + busiestSummary.pathCount) events")
        XCTAssertEqual(insights.mostVisitsDay?.date, mostVisitsSummary.date)
        XCTAssertEqual(insights.mostVisitsDay?.value, "\(mostVisitsSummary.visitCount) visits")
        XCTAssertEqual(insights.mostRoutesDay?.date, mostRoutesSummary.date)
        XCTAssertEqual(insights.mostRoutesDay?.value, "\(mostRoutesSummary.pathCount) routes")
        XCTAssertEqual(insights.longestDistanceDay?.date, longestDistanceSummary.date)
        XCTAssertEqual(insights.longestDistanceDay?.value, String(format: "%.1f km", longestDistanceSummary.totalPathDistanceM / 1000))
    }

    func testMetadataAccuracyFilterShapesOverviewSummariesInsightsAndDetail() throws {
        let export = makeAccuracyFilteredExport()

        let overview = AppExportQueries.overview(from: export)
        let summaries = AppExportQueries.daySummaries(from: export)
        let insights = AppExportQueries.insights(from: export)
        let detail = try XCTUnwrap(AppExportQueries.dayDetail(for: "2024-08-01", in: export))

        XCTAssertEqual(overview.dayCount, 1)
        XCTAssertEqual(overview.totalVisitCount, 1)
        XCTAssertEqual(overview.totalActivityCount, 1)
        XCTAssertEqual(overview.totalPathCount, 1)
        XCTAssertEqual(overview.statsActivityTypes, ["WALKING"])

        XCTAssertEqual(summaries.map(\.date), ["2024-08-01"])
        XCTAssertEqual(summaries[0].visitCount, 1)
        XCTAssertEqual(summaries[0].activityCount, 1)
        XCTAssertEqual(summaries[0].pathCount, 1)
        XCTAssertEqual(summaries[0].totalPathPointCount, 2)
        XCTAssertEqual(summaries[0].exportablePathCount, 1)

        XCTAssertEqual(insights.activityBreakdown.map(\.activityType), ["WALKING"])
        XCTAssertEqual(insights.visitTypeBreakdown, [VisitTypeItem(semanticType: "HOME", count: 1)])
        XCTAssertEqual(insights.periodBreakdown.count, 1)
        XCTAssertEqual(insights.periodBreakdown[0].paths, 1)
        XCTAssertEqual(insights.activeFilterDescriptions, ["Max accuracy: 10m"])

        XCTAssertEqual(detail.visits.count, 1)
        XCTAssertEqual(detail.activities.count, 1)
        XCTAssertEqual(detail.paths.count, 1)
        XCTAssertEqual(detail.paths[0].pointCount, 2)
        XCTAssertEqual(detail.paths[0].points.compactMap(\.accuracyM), [5, 8])
    }

    func testCustomSpatialFilterCanProjectAreaScopedDays() {
        let export = makeSpatialGroundworkExport()
        let filter = AppExportQueryFilter(
            spatialFilter: .bounds(
                ExportCoordinateBounds(
                    minLat: 52.50,
                    maxLat: 52.53,
                    minLon: 13.38,
                    maxLon: 13.43
                )
            )
        )

        let summaries = AppExportQueries.daySummaries(from: export, applying: filter)
        let insights = AppExportQueries.insights(from: export, applying: filter)
        let detail = AppExportQueries.dayDetail(for: "2024-09-01", in: export, applying: filter)

        XCTAssertEqual(summaries.map(\.date), ["2024-09-01"])
        XCTAssertEqual(summaries[0].visitCount, 1)
        XCTAssertEqual(summaries[0].pathCount, 1)
        XCTAssertEqual(summaries[0].totalPathPointCount, 2)
        XCTAssertEqual(insights.activeFilterDescriptions, ["Area: Bounding box"])
        XCTAssertEqual(detail?.paths.first?.pointCount, 2)
    }

    func testInsightsDistanceFallsBackToTraceGeometryWhenImportedDistanceIsMissing() {
        let export = makeInsightsTraceFallbackExport()

        let summaries = AppExportQueries.daySummaries(from: export)
        let insights = AppExportQueries.insights(from: export)

        XCTAssertEqual(summaries.map(\.date), ["2024-10-01", "2024-10-02"])
        XCTAssertGreaterThan(summaries[0].totalPathDistanceM, 2_000)
        XCTAssertGreaterThan(summaries[1].totalPathDistanceM, 1_000)
        XCTAssertEqual(
            insights.totalDistanceM,
            summaries.reduce(0.0) { $0 + $1.totalPathDistanceM },
            accuracy: 0.001
        )
        XCTAssertEqual(insights.averagesPerDay.avgDistancePerDayM, insights.totalDistanceM / 2, accuracy: 0.001)
        XCTAssertEqual(insights.longestDistanceDay?.date, "2024-10-01")
        XCTAssertEqual(insights.activityBreakdown.map(\.activityType), ["WALKING"])
        XCTAssertGreaterThan(insights.activityBreakdown[0].totalDistanceKM, 1.0)

        guard let firstPeriodBreakdown = insights.periodBreakdown.first else {
            XCTFail("Expected a period breakdown item")
            return
        }
        XCTAssertEqual(firstPeriodBreakdown.distanceM, insights.totalDistanceM, accuracy: 0.001)
    }

    private func loadExport(named name: String) throws -> AppExport {
        try AppExportDecoder.decode(contentsOf: TestSupport.contractFixtureURL(named: name))
    }

    private func loadExportWithReversedDays(named name: String) throws -> AppExport {
        let url = try TestSupport.contractFixtureURL(named: name)
        let data = try Data(contentsOf: url)
        let rootObject = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var dataObject = try XCTUnwrap(rootObject["data"] as? [String: Any])
        let days = try XCTUnwrap(dataObject["days"] as? [[String: Any]])
        dataObject["days"] = Array(days.reversed())

        var mutated = rootObject
        mutated["data"] = dataObject

        let mutatedData = try JSONSerialization.data(withJSONObject: mutated, options: [.prettyPrinted, .sortedKeys])
        return try AppExportDecoder.decode(data: mutatedData)
    }

    private func makeAccuracyFilteredExport() -> AppExport {
        AppExport(
            schemaVersion: .v1_0,
            meta: Meta(
                exportedAt: "2024-08-10T12:00:00Z",
                toolVersion: "1.9.0",
                source: Source(zipBasename: nil, zipPath: nil, inputFormat: "records"),
                output: Output(outDir: nil),
                config: ExportConfig(
                    mode: "all",
                    splitMidnight: nil,
                    splitMode: "daily",
                    exportFormat: ["json"],
                    inputFormat: "auto"
                ),
                filters: ExportFilters(
                    fromDate: nil,
                    toDate: nil,
                    year: nil,
                    month: nil,
                    weekday: nil,
                    limit: nil,
                    days: nil,
                    has: nil,
                    maxAccuracyM: 10,
                    activityTypes: nil,
                    minGapMin: nil
                )
            ),
            data: DataBlock(
                days: [
                    Day(
                        date: "2024-08-01",
                        visits: [
                            Visit(
                                lat: 52.52,
                                lon: 13.405,
                                startTime: "2024-08-01T07:00:00Z",
                                endTime: "2024-08-01T08:00:00Z",
                                semanticType: "HOME",
                                placeID: "home",
                                accuracyM: 5,
                                sourceType: "placeVisit"
                            ),
                            Visit(
                                lat: 52.521,
                                lon: 13.406,
                                startTime: "2024-08-01T09:00:00Z",
                                endTime: "2024-08-01T10:00:00Z",
                                semanticType: "WORK",
                                placeID: "work",
                                accuracyM: 32,
                                sourceType: "placeVisit"
                            )
                        ],
                        activities: [
                            Activity(
                                startTime: "2024-08-01T08:05:00Z",
                                endTime: "2024-08-01T08:25:00Z",
                                startLat: 52.52,
                                startLon: 13.405,
                                endLat: 52.525,
                                endLon: 13.41,
                                activityType: "WALKING",
                                distanceM: 1200,
                                splitFromMidnight: false,
                                startAccuracyM: 4,
                                endAccuracyM: 6,
                                sourceType: "activity",
                                flatCoordinates: nil
                            ),
                            Activity(
                                startTime: "2024-08-01T18:00:00Z",
                                endTime: "2024-08-01T18:30:00Z",
                                startLat: 52.53,
                                startLon: 13.42,
                                endLat: 52.54,
                                endLon: 13.43,
                                activityType: "CYCLING",
                                distanceM: 3200,
                                splitFromMidnight: false,
                                startAccuracyM: 24,
                                endAccuracyM: 25,
                                sourceType: "activity",
                                flatCoordinates: nil
                            )
                        ],
                        paths: [
                            Path(
                                startTime: "2024-08-01T08:05:00Z",
                                endTime: "2024-08-01T08:25:00Z",
                                activityType: "WALKING",
                                distanceM: 1250,
                                sourceType: "timelinePath",
                                points: [
                                    PathPoint(lat: 52.52, lon: 13.405, time: "2024-08-01T08:05:00Z", accuracyM: 5),
                                    PathPoint(lat: 52.522, lon: 13.407, time: "2024-08-01T08:15:00Z", accuracyM: 15),
                                    PathPoint(lat: 52.525, lon: 13.41, time: "2024-08-01T08:25:00Z", accuracyM: 8)
                                ],
                                flatCoordinates: nil
                            ),
                            Path(
                                startTime: "2024-08-01T18:00:00Z",
                                endTime: "2024-08-01T18:30:00Z",
                                activityType: "CYCLING",
                                distanceM: 3000,
                                sourceType: "timelinePath",
                                points: [
                                    PathPoint(lat: 52.53, lon: 13.42, time: "2024-08-01T18:00:00Z", accuracyM: 22),
                                    PathPoint(lat: 52.54, lon: 13.43, time: "2024-08-01T18:30:00Z", accuracyM: 24)
                                ],
                                flatCoordinates: nil
                            )
                        ]
                    ),
                    Day(
                        date: "2024-08-02",
                        visits: [
                            Visit(
                                lat: 52.5,
                                lon: 13.37,
                                startTime: "2024-08-02T10:00:00Z",
                                endTime: "2024-08-02T10:30:00Z",
                                semanticType: "LEISURE",
                                placeID: "park",
                                accuracyM: 40,
                                sourceType: "placeVisit"
                            )
                        ],
                        activities: [],
                        paths: [
                            Path(
                                startTime: "2024-08-02T10:05:00Z",
                                endTime: "2024-08-02T10:20:00Z",
                                activityType: "WALKING",
                                distanceM: 600,
                                sourceType: "timelinePath",
                                points: [
                                    PathPoint(lat: 52.5, lon: 13.37, time: "2024-08-02T10:05:00Z", accuracyM: 30),
                                    PathPoint(lat: 52.501, lon: 13.371, time: "2024-08-02T10:20:00Z", accuracyM: 34)
                                ],
                                flatCoordinates: nil
                            )
                        ]
                    )
                ]
            ),
            stats: Stats(
                activities: [
                    "WALKING": ActivityStats(
                        count: 1,
                        totalDistanceKM: 1.2,
                        totalDurationH: 0.33,
                        avgDistanceKM: 1.2,
                        avgSpeedKMH: 3.6
                    ),
                    "CYCLING": ActivityStats(
                        count: 1,
                        totalDistanceKM: 3.2,
                        totalDurationH: 0.5,
                        avgDistanceKM: 3.2,
                        avgSpeedKMH: 6.4
                    )
                ],
                periods: [
                    PeriodStats(
                        label: "2024-08",
                        year: 2024,
                        month: 8,
                        days: 2,
                        visits: 3,
                        activities: 2,
                        paths: 3,
                        distanceM: 4850
                    )
                ]
            )
        )
    }

    private func makeSpatialGroundworkExport() -> AppExport {
        AppExport(
            schemaVersion: .v1_0,
            meta: Meta(
                exportedAt: "2024-09-10T12:00:00Z",
                toolVersion: "1.9.0",
                source: Source(zipBasename: nil, zipPath: nil, inputFormat: "records"),
                output: Output(outDir: nil),
                config: ExportConfig(
                    mode: "all",
                    splitMidnight: nil,
                    splitMode: "daily",
                    exportFormat: ["json"],
                    inputFormat: "auto"
                ),
                filters: ExportFilters(
                    fromDate: nil,
                    toDate: nil,
                    year: nil,
                    month: nil,
                    weekday: nil,
                    limit: nil,
                    days: nil,
                    has: nil,
                    maxAccuracyM: nil,
                    activityTypes: nil,
                    minGapMin: nil
                )
            ),
            data: DataBlock(
                days: [
                    Day(
                        date: "2024-09-01",
                        visits: [
                            Visit(
                                lat: 52.515,
                                lon: 13.4,
                                startTime: "2024-09-01T08:00:00Z",
                                endTime: "2024-09-01T09:00:00Z",
                                semanticType: "HOME",
                                placeID: "berlin-home",
                                accuracyM: 6,
                                sourceType: "placeVisit"
                            )
                        ],
                        activities: [],
                        paths: [
                            Path(
                                startTime: "2024-09-01T09:00:00Z",
                                endTime: "2024-09-01T09:20:00Z",
                                activityType: "WALKING",
                                distanceM: 1400,
                                sourceType: "timelinePath",
                                points: [
                                    PathPoint(lat: 52.515, lon: 13.4, time: "2024-09-01T09:00:00Z", accuracyM: 6),
                                    PathPoint(lat: 52.519, lon: 13.41, time: "2024-09-01T09:10:00Z", accuracyM: 6),
                                    PathPoint(lat: 52.54, lon: 13.45, time: "2024-09-01T09:20:00Z", accuracyM: 6)
                                ],
                                flatCoordinates: nil
                            )
                        ]
                    ),
                    Day(
                        date: "2024-09-02",
                        visits: [
                            Visit(
                                lat: 48.8566,
                                lon: 2.3522,
                                startTime: "2024-09-02T08:00:00Z",
                                endTime: "2024-09-02T09:00:00Z",
                                semanticType: "WORK",
                                placeID: "paris-office",
                                accuracyM: 6,
                                sourceType: "placeVisit"
                            )
                        ],
                        activities: [],
                        paths: []
                    )
                ]
            ),
            stats: nil
        )
    }

    private func makeInsightsTraceFallbackExport() -> AppExport {
        AppExport(
            schemaVersion: .v1_0,
            meta: Meta(
                exportedAt: "2024-10-10T12:00:00Z",
                toolVersion: "1.9.0",
                source: Source(zipBasename: nil, zipPath: nil, inputFormat: "records"),
                output: Output(outDir: nil),
                config: ExportConfig(
                    mode: "all",
                    splitMidnight: nil,
                    splitMode: "daily",
                    exportFormat: ["json"],
                    inputFormat: "auto"
                ),
                filters: ExportFilters(
                    fromDate: nil,
                    toDate: nil,
                    year: nil,
                    month: nil,
                    weekday: nil,
                    limit: nil,
                    days: nil,
                    has: nil,
                    maxAccuracyM: nil,
                    activityTypes: nil,
                    minGapMin: nil
                )
            ),
            data: DataBlock(
                days: [
                    Day(
                        date: "2024-10-01",
                        visits: [],
                        activities: [],
                        paths: [
                            Path(
                                startTime: "2024-10-01T08:00:00Z",
                                endTime: "2024-10-01T08:40:00Z",
                                activityType: "WALKING",
                                distanceM: nil,
                                sourceType: "timelinePath",
                                points: [
                                    PathPoint(lat: 0.0, lon: 0.0, time: "2024-10-01T08:00:00Z", accuracyM: nil),
                                    PathPoint(lat: 0.0, lon: 0.01, time: "2024-10-01T08:20:00Z", accuracyM: nil),
                                    PathPoint(lat: 0.0, lon: 0.02, time: "2024-10-01T08:40:00Z", accuracyM: nil)
                                ],
                                flatCoordinates: nil
                            )
                        ]
                    ),
                    Day(
                        date: "2024-10-02",
                        visits: [],
                        activities: [
                            Activity(
                                startTime: "2024-10-02T09:00:00Z",
                                endTime: "2024-10-02T09:30:00Z",
                                startLat: nil,
                                startLon: nil,
                                endLat: nil,
                                endLon: nil,
                                activityType: "WALKING",
                                distanceM: nil,
                                splitFromMidnight: false,
                                startAccuracyM: nil,
                                endAccuracyM: nil,
                                sourceType: "activity",
                                flatCoordinates: [0.0, 1.0, 0.0, 1.005, 0.0, 1.01]
                            )
                        ],
                        paths: []
                    )
                ]
            ),
            stats: nil
        )
    }
}
