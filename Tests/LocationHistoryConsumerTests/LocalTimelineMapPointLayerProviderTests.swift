import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-10B (Weg 3) — Tests für `LocalTimelineMapPointLayerProvider`.
///
/// Foundation-only / Linux-kompatibel: keine UI-Render-Annahmen, keine
/// wall-clock-Assertions, deterministische Fixtures.
final class LocalTimelineMapPointLayerProviderTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTPointLayer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func makeStore(name: String = "store.sqlite") throws -> LocalTimelineStore {
        try LocalTimelineStore(url: tempDir.appendingPathComponent(name))
    }

    private func makeProvider(store: LocalTimelineStore) -> LocalTimelineMapPointLayerProvider {
        LocalTimelineMapPointLayerProvider(reader: LocalTimelineStoreReader(store: store))
    }

    /// Standard-Budget für Tests: medium-Default mit Day-Map Sample-Cap.
    private func standardBudget() -> LocalTimelineMapPerformanceBudget {
        LocalTimelineMapPerformanceBudget.default(for: .medium)
    }

    /// Seed-Helper: 1 Import, 1 Day. Optional Visits, Activities, Pfade.
    @discardableResult
    private func seedImport(
        store: LocalTimelineStore,
        importID: String = "imp-A",
        dayID: String = "day-A",
        dayDate: String = "2024-01-01",
        visitCount: Int = 0,
        activityCount: Int = 0,
        pathCount: Int = 0,
        pointsPerPath: Int = 4,
        baseLat: Double = 48.0,
        baseLon: Double = 11.0,
        latStep: Double = 0.01
    ) throws -> (importID: String, dayID: String, pathIDs: [String]) {
        try store.insertImport(.init(id: importID, sourceFilename: "synthetic.json",
                                     createdAt: "2024-01-01T00:00:00Z"))
        try store.insertDay(.init(id: dayID, importId: importID, date: dayDate,
                                  routeCount: pathCount, visitCount: visitCount,
                                  distanceM: 0))

        // Visits: bei (baseLat - 0.001 * i, baseLon - 0.001 * i)
        for i in 0..<visitCount {
            try store.insertVisit(.init(
                id: "v-\(i)", dayId: dayID,
                startTime: "2024-01-01T0\(i % 10):00:00Z", endTime: nil,
                latitude: baseLat - 0.001 * Double(i),
                longitude: baseLon - 0.001 * Double(i),
                name: "visit-\(i)", semanticType: nil, placeId: nil, probability: nil
            ))
        }

        // Activities: Start = (baseLat + 0.5 + 0.001*i, baseLon + 0.5 + 0.001*i)
        //             End   = Start + (0.0005, 0.0005)
        for i in 0..<activityCount {
            let sLat = baseLat + 0.5 + 0.001 * Double(i)
            let sLon = baseLon + 0.5 + 0.001 * Double(i)
            try store.insertActivity(.init(
                id: "a-\(i)", dayId: dayID,
                startTime: nil, endTime: nil, mode: "walking",
                distanceM: 100,
                startLat: sLat, startLon: sLon,
                endLat: sLat + 0.0005, endLon: sLon + 0.0005,
                probability: nil, rawType: nil
            ))
        }

        // Paths
        var pathIDs: [String] = []
        for i in 0..<pathCount {
            let pathID = "p-\(importID)-\(i)"
            pathIDs.append(pathID)
            let lat = baseLat + Double(i) * latStep
            var flat: [Double] = []
            for k in 0..<pointsPerPath {
                flat.append(lat + Double(k) * 0.0001)
                flat.append(baseLon + Double(k) * 0.0001)
            }
            let blob = try CoordBlobEncoder.encode(flatCoordinates: flat)
            try store.insertPath(.init(
                id: pathID, dayId: dayID,
                startTime: "2024-01-01T00:00:00Z", endTime: nil, mode: "walking",
                distanceM: Double(pointsPerPath) * 10,
                pointCount: pointsPerPath,
                minLat: lat, minLon: baseLon,
                maxLat: lat + Double(pointsPerPath - 1) * 0.0001,
                maxLon: baseLon + Double(pointsPerPath - 1) * 0.0001,
                coordEncoding: CoordBlobEncoding.int32MicrodegreesV1,
                coordBlob: blob
            ))
        }
        return (importID, dayID, pathIDs)
    }

    // MARK: - Visits

    func testDayPointCandidatesIncludesVisitsInViewport() throws {
        let store = try makeStore(); defer { store.close() }
        _ = try seedImport(store: store, visitCount: 3, activityCount: 0, pathCount: 0)
        let provider = makeProvider(store: store)
        let resp = try provider.dayPointCandidates(
            dayID: "day-A", viewport: .world, budget: standardBudget()
        )
        let visits = resp.entries.filter { $0.kind == .visit }
        XCTAssertEqual(visits.count, 3)
        XCTAssertFalse(resp.isTruncated)
        XCTAssertEqual(visits.map(\.referenceID), ["v-0", "v-1", "v-2"])
    }

    // MARK: - Activities (start + end)

    func testActivitiesProvideStartAndEndPoints() throws {
        let store = try makeStore(); defer { store.close() }
        _ = try seedImport(store: store, visitCount: 0, activityCount: 2, pathCount: 0)
        let provider = makeProvider(store: store)
        let resp = try provider.dayPointCandidates(
            dayID: "day-A", viewport: .world, budget: standardBudget()
        )
        let starts = resp.entries.filter { $0.kind == .activityStart }
        let ends = resp.entries.filter { $0.kind == .activityEnd }
        XCTAssertEqual(starts.count, 2)
        XCTAssertEqual(ends.count, 2)
        XCTAssertEqual(Set(starts.map(\.referenceID)), Set(["a-0", "a-1"]))
        XCTAssertEqual(Set(ends.map(\.referenceID)), Set(["a-0", "a-1"]))
    }

    // MARK: - Route samples (lazy)

    func testRouteSamplesAreDrawnForViewportPaths() throws {
        let store = try makeStore(); defer { store.close() }
        _ = try seedImport(store: store, pathCount: 3, pointsPerPath: 8)
        let provider = makeProvider(store: store)
        let resp = try provider.dayPointCandidates(
            dayID: "day-A", viewport: .world, budget: standardBudget()
        )
        let samples = resp.entries.filter { $0.kind == .routeSample }
        XCTAssertGreaterThan(samples.count, 0, "expected route samples")
        // Pro Pfad höchstens maxRouteSamplePointsPerRoute (medium = 32).
        let perPathCap = standardBudget().maxRouteSamplePointsPerRoute
        let grouped = Dictionary(grouping: samples, by: { $0.referenceID })
        for (_, sub) in grouped {
            XCTAssertLessThanOrEqual(sub.count, perPathCap)
        }
        XCTAssertEqual(resp.totalRouteCandidatesScanned, 3)
    }

    // MARK: - Empty viewport

    func testViewportWithNoHitsReturnsEmptyResponseWithoutTruncation() throws {
        let store = try makeStore(); defer { store.close() }
        _ = try seedImport(store: store, visitCount: 2, activityCount: 1, pathCount: 2)
        let provider = makeProvider(store: store)
        // Komplett außerhalb aller Test-Daten.
        let vp = LocalTimelineMapViewport(minLat: -10, minLon: -10,
                                          maxLat: -5, maxLon: -5,
                                          detailLevel: .medium)!
        let resp = try provider.dayPointCandidates(
            dayID: "day-A", viewport: vp, budget: standardBudget()
        )
        XCTAssertTrue(resp.entries.isEmpty)
        XCTAssertFalse(resp.truncatedVisits)
        XCTAssertFalse(resp.truncatedActivities)
        XCTAssertFalse(resp.truncatedRouteSamples)
        XCTAssertFalse(resp.isTruncated)
    }

    // MARK: - World viewport bounded

    func testWorldViewportStaysBoundedByBudget() throws {
        let store = try makeStore(); defer { store.close() }
        _ = try seedImport(store: store, visitCount: 5, activityCount: 5, pathCount: 5,
                           pointsPerPath: 16)
        let provider = makeProvider(store: store)
        let budget = standardBudget()
        let resp = try provider.dayPointCandidates(
            dayID: "day-A", viewport: .world, budget: budget
        )
        XCTAssertLessThanOrEqual(resp.entries.count, budget.maxPointLayerSamples)
    }

    // MARK: - Zero sample budgets

    func testZeroPointLayerSamplesReturnsEmptyAndFlagsTruncationWhenSourceExists() throws {
        let store = try makeStore(); defer { store.close() }
        _ = try seedImport(store: store, visitCount: 2, activityCount: 1, pathCount: 1,
                           pointsPerPath: 6)
        let provider = makeProvider(store: store)
        // pointBudget min: maxPointsPerRoute=2, maxTotal=2 (struct-Precondition).
        let pb = LocalTimelineMapPointBudget(maxPointsPerRoute: 2, maxTotalPoints: 2)
        let budget = LocalTimelineMapPerformanceBudget(
            detailLevel: .medium, pointBudget: pb,
            maxVisibleRoutes: 0, maxRouteCandidates: 8,
            maxPointLayerSamples: 0,
            maxRouteSamplePointsPerRoute: 4,
            maxClusters: 16
        )
        let resp = try provider.dayPointCandidates(
            dayID: "day-A", viewport: .world, budget: budget
        )
        XCTAssertTrue(resp.entries.isEmpty)
        // Es gibt visits → bei cap=0 wird der erste Eintritt sofort als truncated markiert.
        XCTAssertTrue(resp.truncatedVisits)
    }

    func testZeroPerRouteSamplesYieldsNoRouteSamples() throws {
        let store = try makeStore(); defer { store.close() }
        _ = try seedImport(store: store, visitCount: 0, activityCount: 0, pathCount: 2,
                           pointsPerPath: 5)
        let provider = makeProvider(store: store)
        let pb = LocalTimelineMapPointBudget(maxPointsPerRoute: 2, maxTotalPoints: 2)
        let budget = LocalTimelineMapPerformanceBudget(
            detailLevel: .medium, pointBudget: pb,
            maxVisibleRoutes: 0, maxRouteCandidates: 8,
            maxPointLayerSamples: 100,
            maxRouteSamplePointsPerRoute: 0,
            maxClusters: 16
        )
        let resp = try provider.dayPointCandidates(
            dayID: "day-A", viewport: .world, budget: budget
        )
        let samples = resp.entries.filter { $0.kind == .routeSample }
        XCTAssertTrue(samples.isEmpty)
        XCTAssertTrue(resp.truncatedRouteSamples,
                      "Quelldaten mit 0 perRoute-Cap müssen Truncation signalisieren")
    }

    // MARK: - Malformed coord blob

    func testMalformedCoordBlobThrowsControlled() throws {
        let store = try makeStore(); defer { store.close() }
        try store.insertImport(.init(id: "imp-X", sourceFilename: "x.json",
                                     createdAt: "2024-01-01T00:00:00Z"))
        try store.insertDay(.init(id: "day-X", importId: "imp-X", date: "2024-01-01",
                                  routeCount: 1, visitCount: 0, distanceM: 0))
        try store.insertPath(.init(
            id: "path-bad", dayId: "day-X",
            startTime: "2024-01-01T00:00:00Z", endTime: nil, mode: "walking",
            distanceM: 0, pointCount: 4,
            // bbox überlappt world → wird kandidat
            minLat: 0, minLon: 0, maxLat: 1, maxLon: 1,
            coordEncoding: CoordBlobEncoding.int32MicrodegreesV1,
            coordBlob: Data([1, 2, 3, 4, 5])
        ))
        let provider = makeProvider(store: store)
        XCTAssertThrowsError(try provider.dayPointCandidates(
            dayID: "day-X", viewport: .world, budget: standardBudget()
        )) { err in
            guard case LocalTimelineMapPointLayerError.malformedCoordBlob = err else {
                return XCTFail("expected malformedCoordBlob, got \(err)")
            }
        }
    }

    // MARK: - Determinism

    func testDeterminismIdenticalEntriesAcrossCalls() throws {
        let store = try makeStore(); defer { store.close() }
        _ = try seedImport(store: store, visitCount: 3, activityCount: 2, pathCount: 4,
                           pointsPerPath: 10)
        let provider = makeProvider(store: store)
        let r1 = try provider.dayPointCandidates(
            dayID: "day-A", viewport: .world, budget: standardBudget()
        )
        let r2 = try provider.dayPointCandidates(
            dayID: "day-A", viewport: .world, budget: standardBudget()
        )
        XCTAssertEqual(r1.entries, r2.entries)
        XCTAssertEqual(r1.totalRouteCandidatesScanned, r2.totalRouteCandidatesScanned)
    }

    // MARK: - Bounded with many paths

    func testManyPathsStayBoundedByBudget() throws {
        let store = try makeStore(name: "many.sqlite"); defer { store.close() }
        try store.execRaw("BEGIN IMMEDIATE;")
        try store.insertImport(.init(id: "imp-big", sourceFilename: "big.json",
                                     createdAt: "2024-01-01T00:00:00Z"))
        try store.insertDay(.init(id: "day-big", importId: "imp-big", date: "2024-01-01",
                                  routeCount: 250, visitCount: 0, distanceM: 0))
        for i in 0..<250 {
            let lat = 1.0 + Double(i) * 0.001
            let flat: [Double] = (0..<8).flatMap { k -> [Double] in
                [lat + Double(k) * 0.00001, 1.0 + Double(k) * 0.00001]
            }
            let blob = try CoordBlobEncoder.encode(flatCoordinates: flat)
            try store.insertPath(.init(
                id: "p-\(i)", dayId: "day-big",
                startTime: nil, endTime: nil, mode: nil,
                distanceM: 80, pointCount: 8,
                minLat: lat, minLon: 1.0,
                maxLat: lat + 0.0001, maxLon: 1.0001,
                coordEncoding: CoordBlobEncoding.int32MicrodegreesV1, coordBlob: blob
            ))
        }
        try store.execRaw("COMMIT;")
        let provider = makeProvider(store: store)
        // Klein-Budget zum Erzwingen der Caps.
        let pb = LocalTimelineMapPointBudget(maxPointsPerRoute: 8, maxTotalPoints: 256)
        let budget = LocalTimelineMapPerformanceBudget(
            detailLevel: .low, pointBudget: pb,
            maxVisibleRoutes: 16, maxRouteCandidates: 64,
            maxPointLayerSamples: 200,
            maxRouteSamplePointsPerRoute: 4,
            maxClusters: 64
        )
        let resp = try provider.pointCandidates(
            importID: "imp-big", viewport: .world, budget: budget
        )
        XCTAssertLessThanOrEqual(resp.entries.count, budget.maxPointLayerSamples)
        XCTAssertLessThanOrEqual(resp.totalRouteCandidatesScanned, budget.maxRouteCandidates)
    }

    // MARK: - Clustering

    func testDayClusteredPointsAggregatesIntoCells() throws {
        let store = try makeStore(); defer { store.close() }
        _ = try seedImport(store: store, visitCount: 5, activityCount: 2, pathCount: 0)
        let provider = makeProvider(store: store)
        let cell = 1.0 // Eine grobe Zelle aggregiert sehr viel.
        let resp = try provider.dayClusteredPoints(
            dayID: "day-A", viewport: .world,
            budget: standardBudget(), cellSizeDegrees: cell
        )
        XCTAssertEqual(resp.cellSizeDegrees, cell)
        XCTAssertGreaterThan(resp.clusters.count, 0)
        XCTAssertLessThanOrEqual(resp.clusters.count, standardBudget().maxClusters)
        // deterministisch sortiert (lat asc, lon asc)
        for i in 1..<resp.clusters.count {
            let prev = resp.clusters[i - 1]
            let curr = resp.clusters[i]
            if prev.centerLat == curr.centerLat {
                XCTAssertLessThanOrEqual(prev.centerLon, curr.centerLon)
            } else {
                XCTAssertLessThanOrEqual(prev.centerLat, curr.centerLat)
            }
        }
        let totalAggregated = resp.clusters.reduce(0) { $0 + $1.count }
        XCTAssertEqual(totalAggregated, resp.totalEntriesAggregated)
    }

    func testEmptyEntriesYieldZeroClusters() throws {
        let store = try makeStore(); defer { store.close() }
        _ = try seedImport(store: store, visitCount: 0, activityCount: 0, pathCount: 0)
        let provider = makeProvider(store: store)
        let resp = try provider.dayClusteredPoints(
            dayID: "day-A", viewport: .world,
            budget: standardBudget(), cellSizeDegrees: 0.1
        )
        XCTAssertEqual(resp.clusters.count, 0)
        XCTAssertEqual(resp.totalEntriesAggregated, 0)
        XCTAssertFalse(resp.isTruncated)
    }

    // MARK: - Error paths

    func testUnknownDayThrowsUnknownDay() throws {
        let store = try makeStore(); defer { store.close() }
        let provider = makeProvider(store: store)
        XCTAssertThrowsError(try provider.dayPointCandidates(
            dayID: "missing-day", viewport: .world, budget: standardBudget()
        )) { err in
            guard case LocalTimelineMapPointLayerError.unknownDay = err else {
                return XCTFail("expected unknownDay, got \(err)")
            }
        }
    }

    func testUnknownImportThrowsUnknownImport() throws {
        let store = try makeStore(); defer { store.close() }
        let provider = makeProvider(store: store)
        XCTAssertThrowsError(try provider.pointCandidates(
            importID: "missing-import", viewport: .world, budget: standardBudget()
        )) { err in
            guard case LocalTimelineMapPointLayerError.unknownImport = err else {
                return XCTFail("expected unknownImport, got \(err)")
            }
        }
    }
}
