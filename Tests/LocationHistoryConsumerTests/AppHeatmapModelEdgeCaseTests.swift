import XCTest

#if canImport(SwiftUI) && canImport(MapKit)
import SwiftUI
import MapKit
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Edge-case coverage for `AppHeatmapModel` initialization. The full
/// asynchronous rendering pipeline is exercised by `AppHeatmapRenderingTests`;
/// this file pins state observable immediately after init for empty/single
/// inputs (audit P1).
@available(iOS 17.0, macOS 14.0, *)
final class AppHeatmapModelEdgeCaseTests: XCTestCase {

    @MainActor
    func testHeatmapModelEmptyExportProducesNoCoordinates() {
        let export = AppHeatmapModelEdgeCaseTests.makeExport(days: [])
        let model = AppHeatmapModel(export: export)

        XCTAssertFalse(model.hasData)
        XCTAssertEqual(model.visibleCells.count, 0)
        XCTAssertEqual(model.stats.totalPoints, 0)
        XCTAssertEqual(model.stats.dayCount, 0)
    }

    @MainActor
    func testHeatmapModelSingleDayExportInitialState() {
        let day = Day(
            date: "2024-08-01",
            visits: [],
            activities: [],
            paths: [
                Path(
                    startTime: "2024-08-01T08:00:00Z",
                    endTime: "2024-08-01T08:10:00Z",
                    activityType: "WALKING",
                    distanceM: 300,
                    sourceType: "timelinePath",
                    points: [
                        PathPoint(lat: 52.5, lon: 13.4, time: "2024-08-01T08:00:00Z", accuracyM: 5),
                        PathPoint(lat: 52.51, lon: 13.41, time: "2024-08-01T08:05:00Z", accuracyM: 5),
                        PathPoint(lat: 52.52, lon: 13.42, time: "2024-08-01T08:10:00Z", accuracyM: 5)
                    ],
                    flatCoordinates: nil
                )
            ]
        )
        let export = AppHeatmapModelEdgeCaseTests.makeExport(days: [day])
        let model = AppHeatmapModel(export: export)

        // Pre-precomputation: model holds the snapshot but visibleCells is
        // empty until `startPrecomputation`. The tested invariant is that
        // construction with non-empty data does not crash and exposes the
        // baseline observable state.
        XCTAssertFalse(model.hasData)
        XCTAssertEqual(model.stats.totalPoints, 0)
    }

    @MainActor
    func testHeatmapModelDayWithoutPathsDoesNotCrash() {
        let day = Day(date: "2024-08-02", visits: [], activities: [], paths: [])
        let export = AppHeatmapModelEdgeCaseTests.makeExport(days: [day])
        let model = AppHeatmapModel(export: export)

        XCTAssertFalse(model.hasData)
        XCTAssertEqual(model.visibleCells.count, 0)
    }

    // MARK: - Helpers

    private static func makeExport(days: [Day]) -> AppExport {
        AppExport(
            schemaVersion: .v1_0,
            meta: Meta(
                exportedAt: "2024-08-01T00:00:00Z",
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
#endif
