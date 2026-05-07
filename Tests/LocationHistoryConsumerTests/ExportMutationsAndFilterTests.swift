import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Coverage for `ExportSelectionContent` mutation overlay and `DayListFilter`
/// chip evaluation (audit P1). Pins that user deletions reach the exporter
/// and that filter chips honour the per-summary `isFavorited` parameter.
final class ExportMutationsAndFilterTests: XCTestCase {

    // MARK: - ExportSelectionContent + ImportedPathMutationSet

    func testExportSelectionContentRespectsMutations() {
        let export = makeExportWithTwoPaths()
        var selection = ExportSelectionState()
        selection.toggle("2026-01-01")

        let mutations = ImportedPathMutationSet(
            deletions: [ImportedPathDeletion(dayKey: "2026-01-01", pathIndex: 0)]
        )

        let days = ExportSelectionContent.exportDays(
            importedExport: export,
            selection: selection,
            recordedTracks: [],
            queryFilter: nil,
            mutations: mutations
        )

        XCTAssertEqual(days.count, 1)
        // Original day had two paths; mutation drops index 0, leaving one.
        XCTAssertEqual(days[0].paths.count, 1)
    }

    func testExportSelectionContentEmptyMutationsLeavesDaysUnchanged() {
        let export = makeExportWithTwoPaths()
        var selection = ExportSelectionState()
        selection.toggle("2026-01-01")

        let days = ExportSelectionContent.exportDays(
            importedExport: export,
            selection: selection,
            recordedTracks: [],
            queryFilter: nil,
            mutations: .empty
        )

        XCTAssertEqual(days.count, 1)
        XCTAssertEqual(days[0].paths.count, 2)
    }

    // MARK: - DayListFilter

    func testDayListFilterPassesRoutesOnly() {
        let summaries = [
            DaySummary(date: "2026-01-01", visitCount: 0, activityCount: 0, pathCount: 0,
                       totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: false),
            DaySummary(date: "2026-01-02", visitCount: 0, activityCount: 0, pathCount: 1,
                       totalPathPointCount: 5, totalPathDistanceM: 100, hasContent: true),
            DaySummary(date: "2026-01-03", visitCount: 1, activityCount: 0, pathCount: 0,
                       totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: true)
        ]
        let filter = DayListFilter(activeChips: [.hasRoutes])

        let kept = summaries.filter { filter.passes(summary: $0, isFavorited: false) }

        XCTAssertEqual(kept.map(\.date), ["2026-01-02"])
    }

    func testDayListFilterFavoritesUsesIsFavoritedParameter() {
        let summary = DaySummary(
            date: "2026-01-04",
            visitCount: 0, activityCount: 0, pathCount: 0,
            totalPathPointCount: 0, totalPathDistanceM: 0,
            hasContent: false
        )
        let filter = DayListFilter(activeChips: [.favorites])

        XCTAssertTrue(filter.passes(summary: summary, isFavorited: true))
        XCTAssertFalse(filter.passes(summary: summary, isFavorited: false))
    }

    // MARK: - Helpers

    private func makeExportWithTwoPaths() -> AppExport {
        let day = Day(
            date: "2026-01-01",
            visits: [],
            activities: [],
            paths: [
                Path(
                    startTime: "2026-01-01T08:00:00Z",
                    endTime: "2026-01-01T08:10:00Z",
                    activityType: "WALKING",
                    distanceM: 300,
                    sourceType: "timelinePath",
                    points: [
                        PathPoint(lat: 52.5, lon: 13.4, time: "2026-01-01T08:00:00Z", accuracyM: 5),
                        PathPoint(lat: 52.51, lon: 13.41, time: "2026-01-01T08:10:00Z", accuracyM: 5)
                    ],
                    flatCoordinates: nil
                ),
                Path(
                    startTime: "2026-01-01T18:00:00Z",
                    endTime: "2026-01-01T18:20:00Z",
                    activityType: "CYCLING",
                    distanceM: 4000,
                    sourceType: "timelinePath",
                    points: [
                        PathPoint(lat: 52.55, lon: 13.45, time: "2026-01-01T18:00:00Z", accuracyM: 5),
                        PathPoint(lat: 52.56, lon: 13.46, time: "2026-01-01T18:20:00Z", accuracyM: 5)
                    ],
                    flatCoordinates: nil
                )
            ]
        )
        return AppExport(
            schemaVersion: .v1_0,
            meta: Meta(
                exportedAt: "2026-01-01T00:00:00Z",
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
            data: DataBlock(days: [day]),
            stats: nil
        )
    }
}
