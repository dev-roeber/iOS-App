import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-10A — `LocalTimelineDayMapViewState` is the Foundation-only
/// presentation surface for the Store DayMap UI. The tests pin the bounded-
/// read guarantees: candidates read metadata only, geometry decodes only for
/// selected paths, and routes/points budgets are strictly enforced.
final class LocalTimelineDayMapViewStateTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTDayMap-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func makeStore(name: String = "daymap.sqlite") throws -> LocalTimelineStore {
        try LocalTimelineStore(url: tempDir.appendingPathComponent(name))
    }

    @discardableResult
    private func seed(store: LocalTimelineStore,
                      pathCount: Int,
                      pointsPerPath: Int = 4,
                      withBbox: Bool = true,
                      importID: String = "imp-DM",
                      dayDate: String = "2024-04-01") throws -> (dayID: String, pathIDs: [String]) {
        try store.insertImport(.init(id: importID, sourceFilename: "daymap.json",
                                     createdAt: "2024-04-01T00:00:00Z"))
        let dayID = "day-\(importID)"
        try store.insertDay(.init(id: dayID, importId: importID, date: dayDate,
                                  routeCount: pathCount, visitCount: 0, distanceM: 0))
        var ids: [String] = []
        for i in 0..<pathCount {
            let pathID = "path-\(importID)-\(i)"
            ids.append(pathID)
            var flat: [Double] = []
            let baseLat = 48.0 + Double(i) * 0.01
            let baseLon = 11.0
            for k in 0..<pointsPerPath {
                flat.append(baseLat + Double(k) * 0.0001)
                flat.append(baseLon + Double(k) * 0.0001)
            }
            let blob = try CoordBlobEncoder.encode(flatCoordinates: flat)
            let minLat: Double? = withBbox ? baseLat : nil
            let maxLat: Double? = withBbox ? baseLat + Double(pointsPerPath - 1) * 0.0001 : nil
            let minLon: Double? = withBbox ? baseLon : nil
            let maxLon: Double? = withBbox ? baseLon + Double(pointsPerPath - 1) * 0.0001 : nil
            let startTime = String(format: "2024-04-01T%02d:00:00Z", i % 24)
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
        return (dayID, ids)
    }

    private func makeSource(store: LocalTimelineStore,
                            budget: LocalTimelineDayMapViewState.Budget = .default,
                            visitsFallback: @escaping LocalTimelineDayMapSource.VisitBoundsFallback = { _ in [] })
        -> LocalTimelineDayMapSource
    {
        LocalTimelineDayMapSource.make(
            provider: StoreBackedMapDataProvider(reader: LocalTimelineStoreReader(store: store)),
            visitsForBoundsFallback: visitsFallback,
            budget: budget
        )
    }

    // MARK: - Candidates without geometry

    func testLoadsCandidatesWithoutGeometryWhenNothingSelected() throws {
        let store = try makeStore(); defer { store.close() }
        let (dayID, pathIDs) = try seed(store: store, pathCount: 3)
        let source = makeSource(store: store)
        let state = try source.load(dayID, [])
        XCTAssertEqual(state.routes.count, 3)
        XCTAssertEqual(Set(state.routes.map(\.pathID)), Set(pathIDs))
        for r in state.routes {
            XCTAssertTrue(r.decimatedPoints.isEmpty,
                          "candidate-only load must not decode coord_blob")
            XCTAssertNotNil(r.bbox, "seeded paths carry path-metadata bbox")
        }
        XCTAssertFalse(state.truncatedRoutes)
        XCTAssertFalse(state.truncatedTotalPoints)
        XCTAssertEqual(state.totalDecodedPoints, 0)
    }

    // MARK: - Selected geometry only

    func testDecodesOnlySelectedRouteGeometry() throws {
        let store = try makeStore(); defer { store.close() }
        let (dayID, pathIDs) = try seed(store: store, pathCount: 3, pointsPerPath: 4)
        let source = makeSource(store: store)
        let chosen = pathIDs[0]
        let state = try source.load(dayID, [chosen])
        let decodedRoutes = state.routes.filter { !$0.decimatedPoints.isEmpty }
        XCTAssertEqual(decodedRoutes.count, 1)
        XCTAssertEqual(decodedRoutes.first?.pathID, chosen)
        XCTAssertEqual(decodedRoutes.first?.decimatedPoints.count, 4)
        for r in state.routes where r.pathID != chosen {
            XCTAssertTrue(r.decimatedPoints.isEmpty)
        }
    }

    // MARK: - maxRoutes budget

    func testMaxRoutesEnforced() throws {
        let store = try makeStore(); defer { store.close() }
        let (dayID, _) = try seed(store: store, pathCount: 6)
        let budget = LocalTimelineDayMapViewState.Budget(
            maxRoutes: 3, maxPointsPerRoute: 256, maxTotalPoints: 1024
        )
        let source = makeSource(store: store, budget: budget)
        let state = try source.load(dayID, [])
        XCTAssertEqual(state.routes.count, 3)
        XCTAssertTrue(state.truncatedRoutes)
    }

    // MARK: - maxPointsPerRoute budget

    func testMaxPointsPerRouteEnforced() throws {
        let store = try makeStore(); defer { store.close() }
        let (dayID, pathIDs) = try seed(store: store, pathCount: 2, pointsPerPath: 32)
        let budget = LocalTimelineDayMapViewState.Budget(
            maxRoutes: 4, maxPointsPerRoute: 8, maxTotalPoints: 1024
        )
        let source = makeSource(store: store, budget: budget)
        let state = try source.load(dayID, Set(pathIDs))
        for r in state.routes {
            XCTAssertLessThanOrEqual(r.decimatedPoints.count, 8)
        }
    }

    // MARK: - maxTotalPoints budget

    func testMaxTotalPointsEnforced() throws {
        let store = try makeStore(); defer { store.close() }
        let (dayID, pathIDs) = try seed(store: store, pathCount: 4, pointsPerPath: 16)
        let budget = LocalTimelineDayMapViewState.Budget(
            maxRoutes: 10, maxPointsPerRoute: 16, maxTotalPoints: 20
        )
        let source = makeSource(store: store, budget: budget)
        let state = try source.load(dayID, Set(pathIDs))
        XCTAssertLessThanOrEqual(state.totalDecodedPoints, 20)
        XCTAssertTrue(state.truncatedTotalPoints,
                      "exceeding the per-day point cap must surface as truncatedTotalPoints")
    }

    // MARK: - Empty day surfaces empty state

    func testEmptyDayProducesEmptyState() throws {
        let store = try makeStore(); defer { store.close() }
        // Seed a day with no paths.
        try store.insertImport(.init(id: "imp-empty",
                                     sourceFilename: "empty.json",
                                     createdAt: "2024-04-01T00:00:00Z"))
        try store.insertDay(.init(id: "day-empty", importId: "imp-empty",
                                  date: "2024-04-01", routeCount: 0,
                                  visitCount: 0, distanceM: 0))
        let source = makeSource(store: store)
        let state = try source.load("day-empty", [])
        XCTAssertTrue(state.routes.isEmpty)
        XCTAssertNil(state.bounds)
        XCTAssertTrue(state.isEmpty)
    }

    // MARK: - Selecting unknown path id is silently ignored

    func testSelectingUnknownPathDoesNotThrow() throws {
        let store = try makeStore(); defer { store.close() }
        let (dayID, _) = try seed(store: store, pathCount: 2)
        let source = makeSource(store: store)
        let state = try source.load(dayID, ["does-not-exist"])
        XCTAssertEqual(state.routes.count, 2)
        XCTAssertEqual(state.totalDecodedPoints, 0)
    }
}
