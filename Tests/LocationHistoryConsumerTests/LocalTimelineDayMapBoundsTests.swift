import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-10A — Bounds/Viewport defaults for the Store DayMap presentation.
/// Bounds come primarily from path metadata (`paths.min/max_lat/lon`) with
/// a fallback to visit coordinates and a final empty case.
final class LocalTimelineDayMapBoundsTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTDayMapBounds-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    private func makeStore() throws -> LocalTimelineStore {
        try LocalTimelineStore(url: tempDir.appendingPathComponent("bounds.sqlite"))
    }

    func testBoundsFromPathMetadata() throws {
        let store = try makeStore(); defer { store.close() }
        try store.insertImport(.init(id: "imp", sourceFilename: "f.json",
                                     createdAt: "2024-01-01T00:00:00Z"))
        try store.insertDay(.init(id: "day-1", importId: "imp", date: "2024-01-01",
                                  routeCount: 2, visitCount: 0, distanceM: 0))
        // Two paths in distinct cells: union should be (47.0, 10.0) – (49.0, 12.0).
        let blob = try CoordBlobEncoder.encode(flatCoordinates: [47.0, 10.0, 47.5, 10.5])
        try store.insertPath(.init(
            id: "p1", dayId: "day-1", startTime: "2024-01-01T08:00:00Z", endTime: nil,
            mode: "walking", distanceM: 100, pointCount: 2,
            minLat: 47.0, minLon: 10.0, maxLat: 47.5, maxLon: 10.5,
            coordEncoding: CoordBlobEncoding.int32MicrodegreesV1, coordBlob: blob
        ))
        let blob2 = try CoordBlobEncoder.encode(flatCoordinates: [48.5, 11.5, 49.0, 12.0])
        try store.insertPath(.init(
            id: "p2", dayId: "day-1", startTime: "2024-01-01T09:00:00Z", endTime: nil,
            mode: "walking", distanceM: 100, pointCount: 2,
            minLat: 48.5, minLon: 11.5, maxLat: 49.0, maxLon: 12.0,
            coordEncoding: CoordBlobEncoding.int32MicrodegreesV1, coordBlob: blob2
        ))

        let source = LocalTimelineDayMapSource.make(
            provider: StoreBackedMapDataProvider(reader: LocalTimelineStoreReader(store: store))
        )
        let state = try source.load("day-1", [])
        let b = try XCTUnwrap(state.bounds)
        XCTAssertEqual(b.minLat, 47.0, accuracy: 1e-6)
        XCTAssertEqual(b.minLon, 10.0, accuracy: 1e-6)
        XCTAssertEqual(b.maxLat, 49.0, accuracy: 1e-6)
        XCTAssertEqual(b.maxLon, 12.0, accuracy: 1e-6)
    }

    func testBoundsFallbackFromVisitsWhenNoPathBbox() throws {
        let store = try makeStore(); defer { store.close() }
        try store.insertImport(.init(id: "imp", sourceFilename: "f.json",
                                     createdAt: "2024-01-01T00:00:00Z"))
        try store.insertDay(.init(id: "day-1", importId: "imp", date: "2024-01-01",
                                  routeCount: 0, visitCount: 2, distanceM: 0))

        let visitPoints = [
            LocalTimelineMapPoint(latitude: 50.0, longitude: 8.0),
            LocalTimelineMapPoint(latitude: 51.0, longitude: 9.0),
        ]
        let source = LocalTimelineDayMapSource.make(
            provider: StoreBackedMapDataProvider(reader: LocalTimelineStoreReader(store: store)),
            visitsForBoundsFallback: { dayID in
                XCTAssertEqual(dayID, "day-1")
                return visitPoints
            }
        )
        let state = try source.load("day-1", [])
        let b = try XCTUnwrap(state.bounds, "fallback must yield bounds when paths are absent")
        XCTAssertEqual(b.minLat, 50.0, accuracy: 1e-6)
        XCTAssertEqual(b.minLon, 8.0, accuracy: 1e-6)
        XCTAssertEqual(b.maxLat, 51.0, accuracy: 1e-6)
        XCTAssertEqual(b.maxLon, 9.0, accuracy: 1e-6)
    }

    func testEmptyDayHasNoBounds() throws {
        let store = try makeStore(); defer { store.close() }
        try store.insertImport(.init(id: "imp", sourceFilename: "f.json",
                                     createdAt: "2024-01-01T00:00:00Z"))
        try store.insertDay(.init(id: "day-1", importId: "imp", date: "2024-01-01",
                                  routeCount: 0, visitCount: 0, distanceM: 0))
        let source = LocalTimelineDayMapSource.make(
            provider: StoreBackedMapDataProvider(reader: LocalTimelineStoreReader(store: store))
        )
        let state = try source.load("day-1", [])
        XCTAssertNil(state.bounds)
        XCTAssertTrue(state.isEmpty)
    }

    func testMalformedCoordBlobSurfacesControlledError() throws {
        let store = try makeStore(); defer { store.close() }
        try store.insertImport(.init(id: "imp", sourceFilename: "f.json",
                                     createdAt: "2024-01-01T00:00:00Z"))
        try store.insertDay(.init(id: "day-1", importId: "imp", date: "2024-01-01",
                                  routeCount: 1, visitCount: 0, distanceM: 0))
        // Blob bytes count not a multiple of 8 → malformed for v1 encoding.
        let badBlob = Data([0x01, 0x02, 0x03])
        try store.insertPath(.init(
            id: "p-bad", dayId: "day-1",
            startTime: "2024-01-01T08:00:00Z", endTime: nil,
            mode: "walking", distanceM: 0, pointCount: 1,
            minLat: 47.0, minLon: 10.0, maxLat: 47.0, maxLon: 10.0,
            coordEncoding: CoordBlobEncoding.int32MicrodegreesV1,
            coordBlob: badBlob
        ))
        let source = LocalTimelineDayMapSource.make(
            provider: StoreBackedMapDataProvider(reader: LocalTimelineStoreReader(store: store))
        )

        // Without selection — must succeed: candidates only.
        let unselected = try source.load("day-1", [])
        XCTAssertEqual(unselected.routes.count, 1)
        XCTAssertEqual(unselected.totalDecodedPoints, 0)

        // With selection — must throw a controlled provider error.
        XCTAssertThrowsError(try source.load("day-1", ["p-bad"])) { err in
            guard let providerErr = err as? LocalTimelineMapProviderError else {
                return XCTFail("expected LocalTimelineMapProviderError, got \(err)")
            }
            switch providerErr {
            case .malformedCoordBlob(let id, _):
                XCTAssertEqual(id, "p-bad")
            default:
                XCTFail("expected .malformedCoordBlob, got \(providerErr)")
            }
        }
    }
}
