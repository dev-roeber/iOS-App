import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-8B — store-backed Heatmap-Provider, bounded sampling + LOD-Cache.
final class StoreBackedHeatmapDataProviderTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTHeatmapProv-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    private func makeStore(_ name: String = "store.sqlite") throws -> LocalTimelineStore {
        try LocalTimelineStore(url: tempDir.appendingPathComponent(name))
    }

    @discardableResult
    private func seedSyntheticStore(store: LocalTimelineStore,
                                    importID: String = "imp-A",
                                    pathCount: Int,
                                    pointsPerPath: Int = 4,
                                    baseLat: Double = 48.0,
                                    baseLon: Double = 11.0,
                                    latStep: Double = 0.01) throws -> [String] {
        try store.insertImport(.init(id: importID, sourceFilename: "x.json",
                                     createdAt: "2024-01-01T00:00:00Z"))
        let dayID = "day-\(importID)"
        try store.insertDay(.init(id: dayID, importId: importID, date: "2024-01-01",
                                  routeCount: pathCount, visitCount: 0, distanceM: 0))
        var ids: [String] = []
        for i in 0..<pathCount {
            let pathID = "p-\(importID)-\(i)"
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
            try store.insertPath(.init(
                id: pathID, dayId: dayID,
                startTime: String(format: "2024-01-01T%02d:00:00Z", i % 24),
                endTime: nil, mode: "walking",
                distanceM: 100, pointCount: pointsPerPath,
                minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon,
                coordEncoding: CoordBlobEncoding.int32MicrodegreesV1,
                coordBlob: blob))
        }
        return ids
    }

    private func makeProvider(store: LocalTimelineStore,
                              cacheStore: LocalTimelineStore? = nil,
                              now: @escaping () -> String = { "2024-02-01T00:00:00Z" })
        -> StoreBackedHeatmapDataProvider
    {
        StoreBackedHeatmapDataProvider(
            reader: LocalTimelineStoreReader(store: store),
            cacheStore: cacheStore,
            now: now)
    }

    // MARK: - Samples

    func testHeatmapSamplesViewportBounded() throws {
        let store = try makeStore()
        defer { store.close() }
        _ = try seedSyntheticStore(store: store, pathCount: 10, pointsPerPath: 4)
        let provider = makeProvider(store: store)
        let vp = LocalTimelineMapViewport(minLat: 47.999, minLon: 10.999,
                                          maxLat: 48.025, maxLon: 11.025)!
        let resp = try provider.heatmapSamples(importID: "imp-A", viewport: vp,
                                               maxRoutes: 100,
                                               maxPointsPerRoute: 100,
                                               maxSamples: 10_000)
        // 3 Pfade (i=0,1,2) × 4 Punkte = 12.
        XCTAssertEqual(resp.samples.count, 12)
        XCTAssertFalse(resp.truncatedRoutes)
    }

    func testHeatmapSamplesMaxSamplesLimit() throws {
        let store = try makeStore()
        defer { store.close() }
        _ = try seedSyntheticStore(store: store, pathCount: 5, pointsPerPath: 10)
        let provider = makeProvider(store: store)
        let resp = try provider.heatmapSamples(importID: "imp-A",
                                               viewport: .world,
                                               maxRoutes: 100,
                                               maxPointsPerRoute: 100,
                                               maxSamples: 7)
        XCTAssertLessThanOrEqual(resp.samples.count, 7)
        XCTAssertTrue(resp.truncatedPoints)
    }

    func testHeatmapSamplesMaxRoutesLimit() throws {
        let store = try makeStore()
        defer { store.close() }
        _ = try seedSyntheticStore(store: store, pathCount: 8, pointsPerPath: 4)
        let provider = makeProvider(store: store)
        let resp = try provider.heatmapSamples(importID: "imp-A",
                                               viewport: .world,
                                               maxRoutes: 3,
                                               maxPointsPerRoute: 100,
                                               maxSamples: 10_000)
        XCTAssertTrue(resp.truncatedRoutes)
        // 3 routes × 4 points = 12.
        XCTAssertEqual(resp.samples.count, 12)
    }

    func testHeatmapSamplesUnknownImportEmpty() throws {
        let store = try makeStore()
        defer { store.close() }
        let provider = makeProvider(store: store)
        let resp = try provider.heatmapSamples(importID: "missing", viewport: .world,
                                               maxRoutes: 100,
                                               maxPointsPerRoute: 100,
                                               maxSamples: 1000)
        XCTAssertTrue(resp.samples.isEmpty)
    }

    // MARK: - LOD aggregation

    func testHeatmapLODAggregatesIntoCells() throws {
        let store = try makeStore()
        defer { store.close() }
        _ = try seedSyntheticStore(store: store, pathCount: 5, pointsPerPath: 10)
        let provider = makeProvider(store: store)
        let vp = LocalTimelineMapViewport(minLat: 47, minLon: 10, maxLat: 49, maxLon: 12,
                                          detailLevel: .medium)!
        let opts = StoreBackedHeatmapDataProvider.LODOptions(
            maxRoutes: 100, maxPointsPerRoute: 100, maxSamples: 10_000,
            maxCells: 1000, cellSizeDegrees: 0.5, useCache: false)
        let resp = try provider.heatmapLOD(importID: "imp-A", viewport: vp, options: opts)
        XCTAssertGreaterThan(resp.cells.count, 0)
        XCTAssertEqual(resp.totalSamples, 50)
        XCTAssertFalse(resp.cacheHit)
    }

    func testHeatmapLODCachesAndReadsBack() throws {
        let store = try makeStore()
        defer { store.close() }
        _ = try seedSyntheticStore(store: store, pathCount: 3, pointsPerPath: 10)
        let provider = makeProvider(store: store, cacheStore: store)
        let vp = LocalTimelineMapViewport(minLat: 47, minLon: 10, maxLat: 49, maxLon: 12,
                                          detailLevel: .medium)!
        let opts = StoreBackedHeatmapDataProvider.LODOptions(
            maxRoutes: 100, maxPointsPerRoute: 100, maxSamples: 10_000,
            maxCells: 1000, cellSizeDegrees: 0.5, useCache: true)
        let first = try provider.heatmapLOD(importID: "imp-A", viewport: vp, options: opts)
        XCTAssertFalse(first.cacheHit)
        let second = try provider.heatmapLOD(importID: "imp-A", viewport: vp, options: opts)
        XCTAssertTrue(second.cacheHit)
        XCTAssertEqual(first.cells.count, second.cells.count)
        XCTAssertEqual(first.totalSamples, second.totalSamples)
    }

    func testClearHeatmapCacheInvalidates() throws {
        let store = try makeStore()
        defer { store.close() }
        _ = try seedSyntheticStore(store: store, pathCount: 3, pointsPerPath: 10)
        let provider = makeProvider(store: store, cacheStore: store)
        let vp = LocalTimelineMapViewport(minLat: 47, minLon: 10, maxLat: 49, maxLon: 12,
                                          detailLevel: .medium)!
        let opts = StoreBackedHeatmapDataProvider.LODOptions(
            maxRoutes: 100, maxPointsPerRoute: 100, maxSamples: 10_000,
            maxCells: 1000, cellSizeDegrees: 0.5, useCache: true)
        _ = try provider.heatmapLOD(importID: "imp-A", viewport: vp, options: opts)
        try provider.clearHeatmapCache(importID: "imp-A")
        let third = try provider.heatmapLOD(importID: "imp-A", viewport: vp, options: opts)
        XCTAssertFalse(third.cacheHit)
    }

    func testCacheKeyDifferentiatesByDetailLevel() {
        let vpA = LocalTimelineMapViewport(minLat: 0, minLon: 0, maxLat: 1, maxLon: 1,
                                           detailLevel: .overview)!
        let vpB = LocalTimelineMapViewport(minLat: 0, minLon: 0, maxLat: 1, maxLon: 1,
                                           detailLevel: .high)!
        let kA = LocalTimelineHeatmapCacheKey.make(viewport: vpA, detailLevel: .overview,
                                                    maxSamples: 1000, cellSizeDegrees: 0.5,
                                                    version: 1)
        let kB = LocalTimelineHeatmapCacheKey.make(viewport: vpB, detailLevel: .high,
                                                    maxSamples: 1000, cellSizeDegrees: 0.005,
                                                    version: 1)
        XCTAssertNotEqual(kA, kB)
    }

    func testMalformedCoordBlobIsSkipped() throws {
        let store = try makeStore()
        defer { store.close() }
        try store.insertImport(.init(id: "imp-X", sourceFilename: "x", createdAt: "t"))
        try store.insertDay(.init(id: "d-X", importId: "imp-X", date: "2024-01-01",
                                  routeCount: 1, visitCount: 0, distanceM: 0))
        try store.insertPath(.init(
            id: "p-bad", dayId: "d-X",
            startTime: "2024-01-01T01:00:00Z", endTime: nil, mode: nil,
            distanceM: 0, pointCount: 1,
            minLat: 0, minLon: 0, maxLat: 0, maxLon: 0,
            coordEncoding: CoordBlobEncoding.int32MicrodegreesV1,
            coordBlob: Data([0x01, 0x02, 0x03, 0x04, 0x05])))
        let provider = makeProvider(store: store)
        let resp = try provider.heatmapSamples(importID: "imp-X", viewport: .world,
                                               maxRoutes: 10,
                                               maxPointsPerRoute: 100,
                                               maxSamples: 1000)
        // Malformed wird kontrolliert übersprungen — Provider liefert leeres Sample-Set.
        XCTAssertTrue(resp.samples.isEmpty)
    }

    func test50kSyntheticStoreStaysBoundedUnderLODBudget() throws {
        let store = try makeStore()
        defer { store.close() }
        // 5000 paths × 10 points = 50_000 raw points.
        try store.withTransaction {
            try seedSyntheticStore(store: store, pathCount: 5000, pointsPerPath: 10,
                                   latStep: 0.001)
        }
        let provider = makeProvider(store: store)
        let vp = LocalTimelineMapViewport.world
        let opts = StoreBackedHeatmapDataProvider.LODOptions(
            maxRoutes: 1000, maxPointsPerRoute: 16, maxSamples: 5_000,
            maxCells: 4096, cellSizeDegrees: 0.1, useCache: false)
        let resp = try provider.heatmapLOD(importID: "imp-A", viewport: vp, options: opts)
        XCTAssertLessThanOrEqual(resp.totalSamples, 5_000)
        XCTAssertLessThanOrEqual(resp.cells.count, 4_096)
    }

    func testLODPayloadCodecRoundTrip() throws {
        let cells = [
            LocalTimelineHeatmapGridCell(centerLat: 48.05, centerLon: 11.05, count: 7),
            LocalTimelineHeatmapGridCell(centerLat: 49.05, centerLon: 12.05, count: 3),
        ]
        let payload = StoreBackedHeatmapDataProvider.encodeLODPayload(
            cells: cells, totalSamples: 10, truncatedCells: false)
        let decoded = try StoreBackedHeatmapDataProvider.decodeLODPayload(payload)
        XCTAssertEqual(decoded.cells.count, 2)
        XCTAssertEqual(decoded.cells[0].count, 7)
        XCTAssertEqual(decoded.totalSamples, 10)
        XCTAssertFalse(decoded.truncatedCells)
    }
}
