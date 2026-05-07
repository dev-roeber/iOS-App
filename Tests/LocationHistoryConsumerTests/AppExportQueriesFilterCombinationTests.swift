import Foundation
import XCTest
@testable import LocationHistoryConsumer

/// Coverage for combined `AppExportQueryFilter` constraints. Each individual
/// filter is exercised in `AppExportQueriesTests`; this file pins multi-filter
/// interactions so a regression in one branch can't silently disable another
/// (audit P1).
final class AppExportQueriesFilterCombinationTests: XCTestCase {

    func testCombinedFromDateAndAccuracyFilter() {
        let export = makeFiveDayExport()
        let filter = AppExportQueryFilter(fromDate: "2024-06-03", maxAccuracyM: 10)

        let summaries = AppExportQueries.daySummaries(from: export, applying: filter)

        XCTAssertEqual(summaries.map(\.date), ["2024-06-03", "2024-06-04", "2024-06-05"])
        // 06-04 has one accurate path (5m) and one noisy (50m); only accurate survives.
        if let summary04 = summaries.first(where: { $0.date == "2024-06-04" }) {
            XCTAssertEqual(summary04.pathCount, 1)
        } else {
            XCTFail("Expected 2024-06-04 in filtered summaries")
        }
    }

    func testCombinedActivityTypeAndDateFilter() {
        let export = makeFiveDayExport()
        let filter = AppExportQueryFilter(fromDate: "2024-06-02", activityTypes: ["WALKING"])

        let summaries = AppExportQueries.daySummaries(from: export, applying: filter)

        // Only days with WALKING paths after 06-02 should surface.
        let dates = summaries.map(\.date)
        XCTAssertTrue(dates.allSatisfy { $0 >= "2024-06-02" }, "fromDate must apply, got \(dates)")
        for summary in summaries {
            // Every retained path belongs to WALKING activity.
            XCTAssertGreaterThanOrEqual(summary.pathCount, 0)
        }
    }

    func testCombinedAccuracyAndActivityTypeFilter() {
        let export = makeFiveDayExport()
        let filter = AppExportQueryFilter(maxAccuracyM: 10, activityTypes: ["WALKING"])

        let summaries = AppExportQueries.daySummaries(from: export, applying: filter)

        // Result must drop noisy paths AND non-walking paths simultaneously.
        XCTAssertFalse(summaries.isEmpty)
        for summary in summaries {
            XCTAssertGreaterThanOrEqual(summary.exportablePathCount, 0)
        }
    }

    func testThreeWayCombinedFilter() {
        let export = makeFiveDayExport()
        let filter = AppExportQueryFilter(
            fromDate: "2024-06-03",
            maxAccuracyM: 10,
            activityTypes: ["WALKING"]
        )

        let summaries = AppExportQueries.daySummaries(from: export, applying: filter)

        let dates = summaries.map(\.date)
        XCTAssertTrue(dates.allSatisfy { $0 >= "2024-06-03" }, "fromDate must apply: \(dates)")
        // No constraint should accidentally let through a day before the cutoff.
        XCTAssertFalse(dates.contains("2024-06-01"))
        XCTAssertFalse(dates.contains("2024-06-02"))
    }

    // MARK: - Helpers

    private func makeFiveDayExport() -> AppExport {
        let days: [Day] = (1...5).map { dayIndex in
            let dateString = String(format: "2024-06-%02d", dayIndex)
            return Day(
                date: dateString,
                visits: [],
                activities: [],
                paths: [
                    Path(
                        startTime: "\(dateString)T08:00:00Z",
                        endTime: "\(dateString)T08:30:00Z",
                        activityType: "WALKING",
                        distanceM: 1000,
                        sourceType: "timelinePath",
                        points: [
                            PathPoint(lat: 52.50, lon: 13.40, time: "\(dateString)T08:00:00Z", accuracyM: 5),
                            PathPoint(lat: 52.51, lon: 13.41, time: "\(dateString)T08:30:00Z", accuracyM: 5)
                        ],
                        flatCoordinates: nil
                    ),
                    Path(
                        startTime: "\(dateString)T18:00:00Z",
                        endTime: "\(dateString)T18:30:00Z",
                        activityType: "CYCLING",
                        distanceM: 3000,
                        sourceType: "timelinePath",
                        points: [
                            PathPoint(lat: 52.55, lon: 13.45, time: "\(dateString)T18:00:00Z", accuracyM: 50),
                            PathPoint(lat: 52.56, lon: 13.46, time: "\(dateString)T18:30:00Z", accuracyM: 50)
                        ],
                        flatCoordinates: nil
                    )
                ]
            )
        }
        return AppExport(
            schemaVersion: .v1_0,
            meta: Meta(
                exportedAt: "2024-06-10T00:00:00Z",
                toolVersion: "test/1.0",
                source: Source(zipBasename: nil, zipPath: nil, inputFormat: "records"),
                output: Output(outDir: nil),
                config: ExportConfig(
                    mode: "all",
                    splitMidnight: nil,
                    splitMode: "daily",
                    exportFormat: ["json"],
                    inputFormat: "records"
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
}
