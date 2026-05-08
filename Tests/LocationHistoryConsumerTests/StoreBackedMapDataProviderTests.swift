import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-8A — store-backed map data provider (bounded queries, lazy decode).
final class StoreBackedMapDataProviderTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTMapProv-\(UUID().uuidString)", isDirectory: true)
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

    /// Build a store with `pathCount` paths, each placed in a distinct
    /// bbox cell within `[baseLat..baseLat+pathCount*step] × baseLon` so we
    /// can deterministically address subsets via viewport.
    private func seedSyntheticStore(store: LocalTimelineStore,
                                    importID: String = "imp-A",
                                    sourceFilename: String = "synthetic.json",
                                    dayDate: String = "2024-01-01",
                                    pathCount: Int,
                                    pointsPerPath: Int = 4,
                                    baseLat: Double = 48.0,
                                    baseLon: Double = 11.0,
                                    latStep: Double = 0.01) throws -> [String] {
        try store.insertImport(.init(id: importID, sourceFilename: sourceFilename,
                                     createdAt: "2024-01-01T00:00:00Z"))
        let dayID = "day-\(importID)"
        try store.insertDay(.init(id: dayID, importId: importID, date: dayDate,
                                  routeCount: pathCount, visitCount: 0, distanceM: 0))
        var ids: [String] = []
        for i in 0..<pathCount {
            let pathID = "path-\(importID)-\(i)"
            ids.append(pathID)
            var flat: [Double] = []
            let lat = baseLat + Double(i) * latStep
            for k in 0..<pointsPerPath {
                flat.append(lat + Double(k) * 0.0001)
                flat.append(baseLon + Double(k) * 0.0001)
            }
            let blob = try CoordBlobEncoder.encode(flatCoordinates: flat)
            let minLat = lat
            let maxLat = lat + Double(pointsPerPath - 1) * 0.0001
            let minLon = baseLon
            let maxLon = baseLon + Double(pointsPerPath - 1) * 0.0001
            // Sortierung: i=0 hat ältestes start_time, hohes i = neuestes.
            let startTime = String(format: "2024-01-01T%02d:00:00Z", i % 24)
            try store.insertPath(.init(
                id: pathID, dayId: dayID,
                startTime: startTime, endTime: nil, mode: "walking",
                distanceM: Double(pointsPerPath) * 10,
                pointCount: pointsPerPath,
                minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon,
                coordEncoding: CoordBlobEncoding.int32MicrodegreesV1,
                coordBlob: blob
            ))
        }
        return ids
    }

    private func makeProvider(store: LocalTimelineStore) -> StoreBackedMapDataProvider {
        StoreBackedMapDataProvider(reader: LocalTimelineStoreReader(store: store))
    }

    // MARK: - Candidates only read metadata

    func testRouteCandidatesReturnMetadataOnly() throws {
        let store = try makeStore()
        defer { store.close() }
        _ = try seedSyntheticStore(store: store, pathCount: 5)
        let provider = makeProvider(store: store)
        let vp = LocalTimelineMapViewport.world
        let cands = try provider.routeCandidates(importID: "imp-A", viewport: vp, limit: 100)
        XCTAssertEqual(cands.count, 5)
        // Newest-first by start_time DESC: i=4 hat startTime "04:00", i=0 "00:00".
        XCTAssertEqual(cands.first?.pathID, "path-imp-A-4")
        XCTAssertEqual(cands.last?.pathID,  "path-imp-A-0")
        // Bounds liegen vor.
        for c in cands {
            XCTAssertNotNil(c.minLat); XCTAssertNotNil(c.maxLat)
            XCTAssertNotNil(c.minLon); XCTAssertNotNil(c.maxLon)
        }
    }

    func testRouteCandidatesFilterByViewport() throws {
        let store = try makeStore()
        defer { store.close() }
        _ = try seedSyntheticStore(store: store, pathCount: 10)
        let provider = makeProvider(store: store)
        // Nur die ersten 3 Pfade (i=0,1,2) liegen in [48.0..48.025].
        let vp = LocalTimelineMapViewport(minLat: 47.999, minLon: 10.999,
                                          maxLat: 48.025, maxLon: 11.025)!
        let cands = try provider.routeCandidates(importID: "imp-A", viewport: vp, limit: 100)
        XCTAssertEqual(cands.count, 3)
        let ids = Set(cands.map(\.pathID))
        XCTAssertEqual(ids, Set(["path-imp-A-0", "path-imp-A-1", "path-imp-A-2"]))
    }

    func testEmptyViewportReturnsEmpty() throws {
        let store = try makeStore()
        defer { store.close() }
        _ = try seedSyntheticStore(store: store, pathCount: 5)
        let provider = makeProvider(store: store)
        // Weit außerhalb aller Pfade.
        let vp = LocalTimelineMapViewport(minLat: -10, minLon: -10, maxLat: -5, maxLon: -5)!
        let cands = try provider.routeCandidates(importID: "imp-A", viewport: vp, limit: 100)
        XCTAssertTrue(cands.isEmpty)
    }

    func testUnknownImportReturnsEmpty() throws {
        let store = try makeStore()
        defer { store.close() }
        _ = try seedSyntheticStore(store: store, pathCount: 3)
        let provider = makeProvider(store: store)
        let cands = try provider.routeCandidates(importID: "imp-DOES-NOT-EXIST",
                                                 viewport: .world, limit: 50)
        XCTAssertTrue(cands.isEmpty)
    }

    func testZeroLimitReturnsEmpty() throws {
        let store = try makeStore()
        defer { store.close() }
        _ = try seedSyntheticStore(store: store, pathCount: 3)
        let provider = makeProvider(store: store)
        let cands = try provider.routeCandidates(importID: "imp-A",
                                                 viewport: .world, limit: 0)
        XCTAssertTrue(cands.isEmpty)
    }

    func testNegativeLimitThrows() throws {
        let store = try makeStore()
        defer { store.close() }
        _ = try seedSyntheticStore(store: store, pathCount: 1)
        let provider = makeProvider(store: store)
        XCTAssertThrowsError(try provider.routeCandidates(importID: "imp-A",
                                                          viewport: .world, limit: -1)) { err in
            guard case LocalTimelineMapProviderError.invalidLimit = err else {
                return XCTFail("expected invalidLimit, got \(err)")
            }
        }
    }

    // MARK: - Day-scoped candidates

    func testDayRouteCandidatesScopeAndFilter() throws {
        let store = try makeStore()
        defer { store.close() }
        _ = try seedSyntheticStore(store: store, pathCount: 5)
        let provider = makeProvider(store: store)
        let vp = LocalTimelineMapViewport(minLat: 47.999, minLon: 10.999,
                                          maxLat: 48.015, maxLon: 11.015)!
        let cands = try provider.dayRouteCandidates(dayID: "day-imp-A",
                                                    viewport: vp, limit: 50)
        XCTAssertEqual(cands.count, 2) // i=0,1
    }

    // MARK: - routeGeometry: lazy + bounded decode

    func testRouteGeometryDecodesExactlyOnePath() throws {
        let store = try makeStore()
        defer { store.close() }
        _ = try seedSyntheticStore(store: store, pathCount: 3, pointsPerPath: 100)
        let provider = makeProvider(store: store)
        let geo = try provider.routeGeometry(pathID: "path-imp-A-1",
                                             detailLevel: .medium, maxPoints: 16)
        XCTAssertEqual(geo.pathID, "path-imp-A-1")
        XCTAssertEqual(geo.originalPointCount, 100)
        XCTAssertLessThanOrEqual(geo.points.count, 16)
        XCTAssertGreaterThanOrEqual(geo.points.count, 2)
    }

    func testRouteGeometryUnknownPathThrows() throws {
        let store = try makeStore()
        defer { store.close() }
        _ = try seedSyntheticStore(store: store, pathCount: 1)
        let provider = makeProvider(store: store)
        XCTAssertThrowsError(try provider.routeGeometry(pathID: "missing",
                                                        detailLevel: .medium,
                                                        maxPoints: 16)) { err in
            guard case LocalTimelineMapProviderError.unknownPath = err else {
                return XCTFail("expected unknownPath, got \(err)")
            }
        }
    }

    func testRouteGeometryMalformedBlobThrowsControlled() throws {
        let store = try makeStore()
        defer { store.close() }
        try store.insertImport(.init(id: "imp-X", sourceFilename: "x.json",
                                     createdAt: "2024-01-01T00:00:00Z"))
        try store.insertDay(.init(id: "day-X", importId: "imp-X", date: "2024-01-01",
                                  routeCount: 1, visitCount: 0, distanceM: 0))
        // Manueller insertPath mit kaputtem Blob (5 Bytes — nicht teilbar durch 8).
        try store.insertPath(.init(
            id: "path-bad", dayId: "day-X",
            startTime: "2024-01-01T00:00:00Z", endTime: nil, mode: "walking",
            distanceM: 0, pointCount: 0,
            minLat: 0, minLon: 0, maxLat: 0, maxLon: 0,
            coordEncoding: CoordBlobEncoding.int32MicrodegreesV1,
            coordBlob: Data([1, 2, 3, 4, 5])
        ))
        let provider = makeProvider(store: store)
        XCTAssertThrowsError(try provider.routeGeometry(pathID: "path-bad",
                                                        detailLevel: .medium,
                                                        maxPoints: 16)) { err in
            guard case LocalTimelineMapProviderError.malformedCoordBlob = err else {
                return XCTFail("expected malformedCoordBlob, got \(err)")
            }
        }
    }

    // MARK: - overviewRoutes: doppelt bounded

    func testOverviewRoutesHonoursMaxRoutes() throws {
        let store = try makeStore()
        defer { store.close() }
        _ = try seedSyntheticStore(store: store, pathCount: 20, pointsPerPath: 10)
        let provider = makeProvider(store: store)
        let q = LocalTimelineMapQuery(
            importID: "imp-A",
            viewport: .world,
            budget: .default(for: .high),
            maxRoutes: 5
        )
        let resp = try provider.overviewRoutes(query: q)
        XCTAssertEqual(resp.routes.count, 5)
        XCTAssertTrue(resp.truncatedRoutes)
    }

    func testOverviewRoutesHonoursMaxTotalPoints() throws {
        let store = try makeStore()
        defer { store.close() }
        _ = try seedSyntheticStore(store: store, pathCount: 8, pointsPerPath: 200)
        let provider = makeProvider(store: store)
        // Budget: 50 pro Pfad, total 120 → drei Pfade können nicht voll passen.
        let budget = LocalTimelineMapPointBudget(maxPointsPerRoute: 50, maxTotalPoints: 120)
        let q = LocalTimelineMapQuery(importID: "imp-A", viewport: .world,
                                      budget: budget, maxRoutes: 8)
        let resp = try provider.overviewRoutes(query: q)
        XCTAssertLessThanOrEqual(resp.totalPoints, 120)
        for r in resp.routes {
            XCTAssertLessThanOrEqual(r.points.count, 50)
        }
    }

    func testOverviewSyntheticLargeStoreStaysBounded() throws {
        // Phase-8A "50k synthetic store"-Anforderung: bounded query ohne RAM-Spike.
        let store = try makeStore(name: "big.sqlite")
        defer { store.close() }
        // 5_000 Pfade × 10 Punkte (50k Punkte gesamt). Insert als Transaktion.
        try store.execRaw("BEGIN IMMEDIATE;")
        try store.insertImport(.init(id: "imp-big", sourceFilename: "big.json",
                                     createdAt: "2024-01-01T00:00:00Z"))
        try store.insertDay(.init(id: "day-big", importId: "imp-big",
                                  date: "2024-01-01",
                                  routeCount: 5_000, visitCount: 0, distanceM: 0))
        for i in 0..<5_000 {
            let lat = 0.0 + Double(i) * 0.001
            let flat: [Double] = (0..<10).flatMap { k -> [Double] in
                [lat + Double(k) * 0.00001, 0.0 + Double(k) * 0.00001]
            }
            let blob = try CoordBlobEncoder.encode(flatCoordinates: flat)
            try store.insertPath(.init(
                id: "p-\(i)", dayId: "day-big",
                startTime: nil, endTime: nil, mode: nil,
                distanceM: 100, pointCount: 10,
                minLat: lat, minLon: 0,
                maxLat: lat + 0.0001, maxLon: 0.0001,
                coordEncoding: CoordBlobEncoding.int32MicrodegreesV1, coordBlob: blob
            ))
        }
        try store.execRaw("COMMIT;")
        let provider = makeProvider(store: store)
        let q = LocalTimelineMapQuery(importID: "imp-big",
                                      viewport: .world,
                                      budget: .default(for: .overview),
                                      maxRoutes: 50)
        let resp = try provider.overviewRoutes(query: q)
        XCTAssertEqual(resp.routes.count, 50)
        XCTAssertLessThanOrEqual(resp.totalPoints,
                                 LocalTimelineMapPointBudget.default(for: .overview).maxTotalPoints)
        XCTAssertTrue(resp.truncatedRoutes) // 50 < 5000
    }

    // MARK: - mapBounds aggregate

    func testMapBoundsAggregatesAcrossPaths() throws {
        let store = try makeStore()
        defer { store.close() }
        _ = try seedSyntheticStore(store: store, pathCount: 5,
                                   pointsPerPath: 3, baseLat: 48.0, latStep: 0.1)
        let provider = makeProvider(store: store)
        let bounds = try provider.mapBounds(forImportID: "imp-A")
        XCTAssertNotNil(bounds)
        XCTAssertEqual(bounds!.minLat, 48.0,        accuracy: 1e-6)
        XCTAssertEqual(bounds!.maxLat, 48.4 + 0.0002, accuracy: 1e-6)
    }

    func testMapBoundsForUnknownImportReturnsNil() throws {
        let store = try makeStore()
        defer { store.close() }
        let provider = makeProvider(store: store)
        XCTAssertNil(try provider.mapBounds(forImportID: "missing"))
    }
}
