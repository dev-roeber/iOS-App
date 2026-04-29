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

    func testOverviewMapRenderProfileRouteLimitIsMetadataAndOverlayLimitCapsRendering() {
        // routeLimit is metadata (always == routeCount passed in)
        let profileLarge = OverviewMapRenderProfile.resolve(routeCount: 150, totalPointCount: 5_000)
        XCTAssertEqual(profileLarge.routeLimit, 150,
                       "routeLimit is metadata and must track the full in-range route count")
        // 150 routes → medium-heavy tier → overlayLimit 250; no capping for this dataset
        XCTAssertEqual(profileLarge.overlayLimit, 250)

        // Very heavy dataset: hard cap kicks in to protect MapKit from freeze/crash
        let profileVeryHeavy = OverviewMapRenderProfile.resolve(routeCount: 600, totalPointCount: 200_000)
        XCTAssertEqual(profileVeryHeavy.routeLimit, 600,
                       "routeLimit must still track the full in-range count even when overlay cap applies")
        XCTAssertEqual(profileVeryHeavy.overlayLimit, 150,
                       "Very heavy datasets must be capped at 150 overlays to prevent MapKit freeze")

        // Heavy dataset tier
        let profileHeavy = OverviewMapRenderProfile.resolve(routeCount: 300, totalPointCount: 70_000)
        XCTAssertEqual(profileHeavy.overlayLimit, 200)

        // Small dataset: no overlay cap applied
        let profileSmall = OverviewMapRenderProfile.resolve(routeCount: 20, totalPointCount: 400)
        XCTAssertEqual(profileSmall.overlayLimit, 20,
                       "Small datasets must not be artificially capped")
    }

    func testBuildRenderDataFastCapsOverlayCountForVeryLargeDataset() throws {
        // 600 routes with 10 points each → very heavy profile → overlayLimit 150
        let export = try makeSyntheticExport(routeCount: 600, pointsPerRoute: 10)
        let dates = Set(export.data.days.map(\.date))

        let result = OverviewMapPreparation.buildRenderDataFast(for: dates, export: export, filter: nil)

        XCTAssertEqual(result.totalRouteCount, 600,
                       "totalRouteCount must reflect the full dataset regardless of overlay cap")
        XCTAssertLessThanOrEqual(result.visibleRouteCount, 150,
                                 "Very large dataset must be capped at hard overlay limit to protect MapKit")
        XCTAssertGreaterThan(result.visibleRouteCount, 0)
        XCTAssertTrue(result.isOptimized, "Capped dataset must be marked isOptimized")
        XCTAssertTrue(result.visibleRouteCount < result.totalRouteCount,
                      "Overlay count must be strictly less than total when cap fires")
        XCTAssertTrue(result.pathOverlays.allSatisfy { $0.coordinates.count >= 2 })
    }

    func testBuildRenderDataFastSmallDatasetIsNotCapped() throws {
        // 20 routes → default profile → overlayLimit == routeCount, no capping
        let export = try makeSyntheticExport(routeCount: 20, pointsPerRoute: 5)
        let dates = Set(export.data.days.map(\.date))

        let result = OverviewMapPreparation.buildRenderDataFast(for: dates, export: export, filter: nil)

        XCTAssertEqual(result.totalRouteCount, 20)
        XCTAssertEqual(result.visibleRouteCount, 20,
                       "Small datasets must show all routes without capping")
        XCTAssertFalse(result.isOptimized, "Small dataset with few points must not be marked isOptimized")
    }

    func testBuildRenderDataFastStartAndEndPointsPreservedAfterDecimation() throws {
        // Route with 50 points, profile forcing maxPolylinePoints=64 → no decimation needed,
        // but start/end must always survive whatever profile is applied.
        let export = try makeSyntheticExport(routeCount: 1, pointsPerRoute: 50)
        let dates = Set(export.data.days.map(\.date))

        let result = OverviewMapPreparation.buildRenderDataFast(for: dates, export: export, filter: nil)

        XCTAssertEqual(result.totalRouteCount, 1)
        guard let overlay = result.pathOverlays.first else {
            XCTFail("Expected at least one overlay")
            return
        }
        XCTAssertGreaterThanOrEqual(overlay.coordinates.count, 2)
        // Start and end must match source (first and last of the 50 generated points)
        XCTAssertEqual(overlay.coordinates.first?.latitude ?? 0, 48.0, accuracy: 0.0001)
        XCTAssertEqual(overlay.coordinates.last?.latitude ?? 0, 48.0 + 49 * 0.001, accuracy: 0.0001)
    }

    func testExportDataUnchangedAfterOverlayCap() throws {
        // Verify that the original export object is not mutated by the render pipeline
        let export = try makeSyntheticExport(routeCount: 600, pointsPerRoute: 5)
        let originalDayCount = export.data.days.count
        let originalPathCounts = export.data.days.map { $0.paths.count }
        let dates = Set(export.data.days.map(\.date))

        _ = OverviewMapPreparation.buildRenderDataFast(for: dates, export: export, filter: nil)

        XCTAssertEqual(export.data.days.count, originalDayCount,
                       "Export day count must not change after rendering")
        for (i, day) in export.data.days.enumerated() {
            XCTAssertEqual(day.paths.count, originalPathCounts[i],
                           "Export path count for day \(i) must not change after rendering")
        }
    }

    // MARK: - Coordinate budget invariants

    /// The combination of overlayLimit × maxPolylinePoints creates an implicit global
    /// coordinate cap. This test verifies it holds even when routes have many source points.
    func testTotalRenderedCoordinateCountBoundedByOverlayTimesPointsLimit() throws {
        // 600 routes × 200 points each → very heavy profile → overlayLimit=150, maxPolylinePoints=64
        let export = try makeSyntheticExport(routeCount: 600, pointsPerRoute: 200)
        let dates = Set(export.data.days.map(\.date))

        let result = OverviewMapPreparation.buildRenderDataFast(for: dates, export: export, filter: nil)

        let totalCoords = result.pathOverlays.reduce(0) { $0 + $1.coordinates.count }
        // Upper bound: overlayLimit(150) × maxPolylinePoints(64) = 9600
        XCTAssertLessThanOrEqual(totalCoords, 150 * 64,
                                 "Total rendered coordinate count must be bounded by overlayLimit × maxPolylinePoints")
        XCTAssertGreaterThan(totalCoords, 0)
    }

    /// Individual routes must be decimated to at most maxPolylinePoints after DP+decimate.
    func testIndividualRouteCoordinateCountBoundedByMaxPolylinePoints() throws {
        // 1 route with 1000 points → default (small) profile → maxPolylinePoints=220
        let export = try makeSyntheticExport(routeCount: 1, pointsPerRoute: 1000)
        let dates = Set(export.data.days.map(\.date))

        let result = OverviewMapPreparation.buildRenderDataFast(for: dates, export: export, filter: nil)

        guard let overlay = result.pathOverlays.first else {
            XCTFail("Expected at least one overlay for single-route export"); return
        }
        XCTAssertLessThanOrEqual(overlay.coordinates.count, 220,
                                 "Single route must be decimated to at most maxPolylinePoints(220) coordinates")
        XCTAssertGreaterThanOrEqual(overlay.coordinates.count, 2)
    }

    /// When simplification is applied (eps>30) but no route capping occurs, isOptimized is true
    /// and visibleRouteCount == totalRouteCount → badge shows "Optimized overview", not "Simplified".
    func testIsOptimizedTrueWhenDecimationAppliedButRoutesNotCapped() throws {
        // 130 routes (medium-heavy tier: overlayLimit=250 > 130 → no capping, eps=70>30 → simplified)
        let export = try makeSyntheticExport(routeCount: 130, pointsPerRoute: 30)
        let dates = Set(export.data.days.map(\.date))

        let result = OverviewMapPreparation.buildRenderDataFast(for: dates, export: export, filter: nil)

        XCTAssertTrue(result.isOptimized,
                      "Medium-heavy dataset with eps=70 must be marked isOptimized")
        XCTAssertEqual(result.visibleRouteCount, result.totalRouteCount,
                       "130 routes is under overlayLimit=250, so all routes must be visible")
        // Badge logic: isOptimized=true && visibleRouteCount==totalRouteCount → "Optimized overview"
        XCTAssertFalse(result.visibleRouteCount < result.totalRouteCount,
                       "No route capping must occur, so badge must show 'Optimized overview' not 'Simplified map'")
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

// MARK: - Synthetic export helper

private func makeSyntheticExport(routeCount: Int, pointsPerRoute: Int) throws -> AppExport {
    let routesPerDay = 10
    var daysJSON = ""
    var remaining = routeCount
    var dayIndex = 0
    while remaining > 0 {
        dayIndex += 1
        let month = min(((dayIndex - 1) / 28) + 1, 12)
        let day = ((dayIndex - 1) % 28) + 1
        let date = String(format: "2024-%02d-%02d", month, day)
        let count = min(routesPerDay, remaining)
        remaining -= count

        var pathsJSON = ""
        for r in 0..<count {
            let baseLat = 48.0 + Double(r) * 0.01
            let baseLon = 11.0 + Double(r) * 0.01
            var flats = [String]()
            for p in 0..<pointsPerRoute {
                flats.append(String(baseLat + Double(p) * 0.001))
                flats.append(String(baseLon + Double(p) * 0.001))
            }
            if !pathsJSON.isEmpty { pathsJSON += "," }
            pathsJSON += """
            {"activity_type":"WALKING","flat_coordinates":[\(flats.joined(separator: ","))],"points":[]}
            """
        }
        if !daysJSON.isEmpty { daysJSON += "," }
        daysJSON += """
        {"date":"\(date)","visits":[],"activities":[],"paths":[\(pathsJSON)]}
        """
    }

    let jsonStr = """
    {
        "schema_version":"1.0",
        "meta":{
            "exported_at":"2024-01-01T00:00:00Z",
            "tool_version":"test",
            "source":{"zip_basename":null,"zip_path":null,"input_format":null},
            "output":{"out_dir":null},
            "config":{"mode":null,"split_midnight":null,"split_mode":null,"export_format":null,"input_format":null},
            "filters":{}
        },
        "data":{"days":[\(daysJSON)]}
    }
    """
    guard let data = jsonStr.data(using: .utf8) else {
        throw NSError(domain: "TestHelper", code: 1, userInfo: [NSLocalizedDescriptionKey: "UTF-8 encoding failed"])
    }
    return try AppExportDecoder.decode(data: data)
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
