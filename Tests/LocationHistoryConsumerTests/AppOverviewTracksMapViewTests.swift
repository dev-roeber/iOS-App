import XCTest
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

#if canImport(MapKit)
final class AppOverviewTracksMapViewTests: XCTestCase {

    func testOverviewMapTaskKeyChangesWhenSummaryCompositionChanges() {
        let filter = AppExportQueryFilter(fromDate: "2024-01-01", toDate: "2024-01-31")
        let baseline = [
            DaySummary.stub(date: "2024-01-01", visitCount: 1, pathCount: 2, totalPathPointCount: 40),
            DaySummary.stub(date: "2024-01-02", visitCount: 0, pathCount: 3, totalPathPointCount: 70),
            DaySummary.stub(date: "2024-01-03", visitCount: 1, pathCount: 1, totalPathPointCount: 20),
        ]
        let changedMiddle = [
            DaySummary.stub(date: "2024-01-01", visitCount: 1, pathCount: 2, totalPathPointCount: 40),
            DaySummary.stub(date: "2024-01-02", visitCount: 0, pathCount: 9, totalPathPointCount: 140),
            DaySummary.stub(date: "2024-01-03", visitCount: 1, pathCount: 1, totalPathPointCount: 20),
        ]

        let baselineKey = OverviewMapTaskKey.make(daySummaries: baseline, queryFilter: filter)
        let changedKey = OverviewMapTaskKey.make(daySummaries: changedMiddle, queryFilter: filter)

        XCTAssertNotEqual(baselineKey, changedKey)
    }

    func testOverviewMapPreparationKeepsSmallDatasetsUnoptimized() throws {
        let url = try TestSupport.contractFixtureURL(named: "golden_app_export_sample_small.json")
        let export = try AppExportDecoder.decode(contentsOf: url)
        let content = AppSessionContent(export: export, source: .demoFixture(name: "small"))
        let dates = AppExportQueries.daySummaries(from: export).map(\.date)

        let renderData = OverviewMapPreparation.buildRenderData(
            for: dates,
            content: content,
            filter: nil
        )

        XCTAssertGreaterThan(renderData.visibleRouteCount, 0)
        XCTAssertEqual(renderData.totalRouteCount, renderData.visibleRouteCount)
        XCTAssertFalse(renderData.isOptimized)
        XCTAssertNotNil(renderData.region)
    }

    func testOverviewMapPreparationLimitsLargeDatasetsButKeepsTotalCount() throws {
        let url = try TestSupport.contractFixtureURL(named: "perf_app_export_large.json")
        let export = try AppExportDecoder.decode(contentsOf: url)
        let content = AppSessionContent(export: export, source: .demoFixture(name: "perf"))
        let dates = AppExportQueries.daySummaries(from: export).map(\.date)
        let expectedRenderableRoutes = export.data.days.reduce(0) { partial, day in
            partial + day.paths.filter { $0.points.count >= 2 }.count
        }

        let renderData = OverviewMapPreparation.buildRenderData(
            for: dates,
            content: content,
            filter: nil
        )

        XCTAssertEqual(renderData.totalRouteCount, expectedRenderableRoutes)
        XCTAssertTrue(renderData.isOptimized)
        XCTAssertGreaterThan(renderData.visibleRouteCount, 0)
        XCTAssertLessThan(renderData.visibleRouteCount, renderData.totalRouteCount)
        XCTAssertLessThanOrEqual(renderData.visibleRouteCount, 96)
        XCTAssertTrue(renderData.pathOverlays.allSatisfy { $0.coordinates.count >= 2 })
        XCTAssertTrue(renderData.pathOverlays.allSatisfy { $0.coordinates.count <= 96 })
        XCTAssertNotNil(renderData.region)
    }
}

private extension DaySummary {
    static func stub(
        date: String,
        visitCount: Int = 0,
        activityCount: Int = 0,
        pathCount: Int = 0,
        totalPathPointCount: Int = 0,
        totalPathDistanceM: Double = 0
    ) -> DaySummary {
        DaySummary(
            date: date,
            visitCount: visitCount,
            activityCount: activityCount,
            pathCount: pathCount,
            totalPathPointCount: totalPathPointCount,
            totalPathDistanceM: totalPathDistanceM,
            hasContent: visitCount > 0 || activityCount > 0 || pathCount > 0
        )
    }
}
#endif
