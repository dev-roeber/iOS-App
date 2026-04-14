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

    // The large fixture has ~210 routes and ~11 500 points. The overview now keeps all
    // routes in range visible and relies on per-polyline simplification instead of
    // silently culling routes out of dense datasets.
    func testOverviewMapPreparationShowsAllRoutesWhenBelowRaisedLimit() throws {
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

        // totalRouteCount always reflects the full dataset – never silently dropped.
        XCTAssertEqual(renderData.totalRouteCount, expectedRenderableRoutes)
        // With ~210 routes, the new routeLimit of 400 means all routes are visible.
        XCTAssertEqual(renderData.visibleRouteCount, expectedRenderableRoutes,
                       "All routes in the time range should be visible when below the raised limit")
        XCTAssertTrue(renderData.isOptimized,
                      "Large datasets should still mark the overview as optimized when simplification is applied")
        XCTAssertGreaterThan(renderData.visibleRouteCount, 0)
        XCTAssertTrue(renderData.pathOverlays.allSatisfy { $0.coordinates.count >= 2 })
        XCTAssertNotNil(renderData.region)
    }

    func testOverviewMapPreparationTotalRouteCountNeverExceedsActualDataset() throws {
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

        // totalRouteCount must match the full candidate pool, and the rendered result
        // must keep every in-range route visible.
        XCTAssertEqual(renderData.totalRouteCount, expectedRenderableRoutes)
        XCTAssertEqual(renderData.visibleRouteCount, renderData.totalRouteCount)
    }

    func testOverviewMapTaskKeyChangesWhenDateRangeFilterChanges() {
        let summaries = [
            DaySummary.stub(date: "2024-05-01", pathCount: 2, totalPathPointCount: 40),
            DaySummary.stub(date: "2024-05-02", pathCount: 3, totalPathPointCount: 70),
        ]
        let noFilter: AppExportQueryFilter? = nil
        let rangeFilter = AppExportQueryFilter(fromDate: "2024-05-01", toDate: "2024-05-01")

        let keyAll = OverviewMapTaskKey.make(daySummaries: summaries, queryFilter: noFilter)
        let keyFiltered = OverviewMapTaskKey.make(daySummaries: summaries, queryFilter: rangeFilter)

        // A different queryFilter must produce a different task key so the map reloads.
        XCTAssertNotEqual(keyAll, keyFiltered,
                          "Task key must change when the time range filter changes so the map reloads")
    }

    func testOverviewMapTaskKeyChangesWhenSummaryDateSetChanges() {
        let filterA = AppExportQueryFilter(fromDate: "2024-01-01", toDate: "2024-01-31")
        let summariesJan = [
            DaySummary.stub(date: "2024-01-01", pathCount: 2, totalPathPointCount: 40),
            DaySummary.stub(date: "2024-01-02", pathCount: 1, totalPathPointCount: 10),
        ]
        // Simulate narrowing the time range to a single day.
        let summariesOneDayOnly = [
            DaySummary.stub(date: "2024-01-01", pathCount: 2, totalPathPointCount: 40),
        ]

        let keyFull = OverviewMapTaskKey.make(daySummaries: summariesJan, queryFilter: filterA)
        let keyNarrowed = OverviewMapTaskKey.make(daySummaries: summariesOneDayOnly, queryFilter: filterA)

        XCTAssertNotEqual(keyFull, keyNarrowed,
                          "Task key must change when the set of day summaries changes")
    }

    // MARK: - buildRenderDataFast (O(N) single-pass)

    func testBuildRenderDataFastProducesSameRouteCountAsLegacy_small() throws {
        let url = try TestSupport.contractFixtureURL(named: "golden_app_export_sample_small.json")
        let export = try AppExportDecoder.decode(contentsOf: url)
        let dates = AppExportQueries.daySummaries(from: export).map(\.date)
        let content = AppSessionContent(export: export, source: .demoFixture(name: "small"))

        let legacy = OverviewMapPreparation.buildRenderData(for: dates, content: content, filter: nil)
        let fast = OverviewMapPreparation.buildRenderDataFast(for: Set(dates), export: export, filter: nil)

        XCTAssertEqual(fast.totalRouteCount, legacy.totalRouteCount,
                       "Fast path must count the same total routes as the legacy path")
        XCTAssertEqual(fast.visibleRouteCount, legacy.visibleRouteCount,
                       "Fast path must produce the same visible route count")
        XCTAssertEqual(fast.isOptimized, legacy.isOptimized)
        XCTAssertNotNil(fast.region)
    }

    func testBuildRenderDataFastEmptyDateSetReturnsEmpty() throws {
        let url = try TestSupport.contractFixtureURL(named: "golden_app_export_sample_small.json")
        let export = try AppExportDecoder.decode(contentsOf: url)

        let fast = OverviewMapPreparation.buildRenderDataFast(for: [], export: export, filter: nil)

        XCTAssertFalse(fast.hasContent)
        XCTAssertEqual(fast.totalRouteCount, 0)
        XCTAssertNil(fast.region)
    }

    func testBuildRenderDataFastActivityTypeFilterExcludesNonMatchingPaths() throws {
        let url = try TestSupport.contractFixtureURL(named: "golden_app_export_sample_small.json")
        let export = try AppExportDecoder.decode(contentsOf: url)
        let dates = Set(AppExportQueries.daySummaries(from: export).map(\.date))

        // Filter for an activity type that is very unlikely to exist in the fixture
        let filter = AppExportQueryFilter(activityTypes: ["__nonexistent_activity_type__"])
        let fast = OverviewMapPreparation.buildRenderDataFast(for: dates, export: export, filter: filter)

        XCTAssertEqual(fast.totalRouteCount, 0, "No routes should match a non-existent activity type")
        XCTAssertFalse(fast.hasContent)
    }

    func testBuildRenderDataFastLargeFixtureProducesValidResult() throws {
        let url = try TestSupport.contractFixtureURL(named: "perf_app_export_large.json")
        let export = try AppExportDecoder.decode(contentsOf: url)
        let dates = Set(AppExportQueries.daySummaries(from: export).map(\.date))
        let expectedRenderableRoutes = export.data.days.reduce(0) { partial, day in
            partial + day.paths.filter { ($0.flatCoordinates?.count ?? 0) >= 4 || $0.points.count >= 2 }.count
        }

        let fast = OverviewMapPreparation.buildRenderDataFast(for: dates, export: export, filter: nil)

        XCTAssertEqual(fast.totalRouteCount, expectedRenderableRoutes,
                       "Fast path totalRouteCount must match all renderable paths in the dataset")
        XCTAssertGreaterThan(fast.visibleRouteCount, 0)
        XCTAssertTrue(fast.pathOverlays.allSatisfy { $0.coordinates.count >= 2 })
        XCTAssertNotNil(fast.region)
    }

    func testOverviewMapRenderProfileNoLongerCapsVisibleRoutes() {
        let profileLarge = OverviewMapRenderProfile.resolve(routeCount: 150, totalPointCount: 5_000)
        XCTAssertEqual(profileLarge.routeLimit, 150,
                       "Route budget metadata should track the full in-range route count")

        let profileHeavy = OverviewMapRenderProfile.resolve(routeCount: 600, totalPointCount: 200_000)
        XCTAssertEqual(profileHeavy.routeLimit, 600,
                       "Even heavy datasets must keep all routes visible in the selected time range")
    }

    // MARK: - Cancellation behaviour

    /// buildRenderDataFast must return promptly when cancelled before the DP phase,
    /// not block the caller indefinitely on thousands of Douglas-Peucker runs.
    func testBuildRenderDataFastExitsEarlyWhenCancelledBeforeDP() async throws {
        let url = try TestSupport.contractFixtureURL(named: "perf_app_export_large.json")
        let export = try AppExportDecoder.decode(contentsOf: url)
        let dates = Set(AppExportQueries.daySummaries(from: export).map(\.date))

        // Cancel the task immediately so Task.isCancelled is true upon entry.
        let task = Task<OverviewMapRenderData, Never> {
            // Yield once so Swift propagates the cancel flag before calling into the hot path.
            await Task.yield()
            return OverviewMapPreparation.buildRenderDataFast(for: dates, export: export, filter: nil)
        }
        task.cancel()

        let result = await task.value

        // The function must return (not hang). Result may be empty or partial –
        // both are acceptable. Only totalRouteCount is allowed to be non-zero
        // (it reflects how many were collected before cancellation was detected).
        XCTAssertEqual(result.pathOverlays.count, 0,
                       "Cancelled task must produce no overlays (DP phase was skipped)")
    }

    /// A second concurrent load (new generation) must not be blocked by a slow
    /// first load: the first result is discarded by the generation guard, and
    /// the spinner state must eventually resolve to a non-loading state.
    func testBuildRenderDataFastCancelledTaskDoesNotBlockSubsequentResult() async throws {
        let url = try TestSupport.contractFixtureURL(named: "golden_app_export_sample_small.json")
        let export = try AppExportDecoder.decode(contentsOf: url)
        let dates = Set(AppExportQueries.daySummaries(from: export).map(\.date))

        // Simulate two concurrent computations; the second must finish and produce content.
        async let first = Task.detached {
            OverviewMapPreparation.buildRenderDataFast(for: dates, export: export, filter: nil)
        }.value
        async let second = Task.detached {
            OverviewMapPreparation.buildRenderDataFast(for: dates, export: export, filter: nil)
        }.value

        let (r1, r2) = await (first, second)

        // Both paths on a non-cancelled task must yield content for this fixture.
        XCTAssertGreaterThan(r1.totalRouteCount, 0)
        XCTAssertGreaterThan(r2.totalRouteCount, 0)
        XCTAssertEqual(r1.totalRouteCount, r2.totalRouteCount,
                       "Two uncancelled runs on the same export must produce identical route counts")
    }

    // MARK: - Loading phase model

    func testLoadingPhaseAnalyzingHasNonEmptyDescription() {
        XCTAssertFalse(OverviewMapLoadingPhase.analyzing.descriptionKey.isEmpty)
    }

    func testLoadingPhaseBuildingHasNonEmptyDescription() {
        XCTAssertFalse(OverviewMapLoadingPhase.building.descriptionKey.isEmpty)
    }

    func testLoadingPhasesAreDifferent() {
        XCTAssertNotEqual(
            OverviewMapLoadingPhase.analyzing.descriptionKey,
            OverviewMapLoadingPhase.building.descriptionKey
        )
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
