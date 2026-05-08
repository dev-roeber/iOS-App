import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-1 spike tests. Exercise the SQLite-backed `LocalTimelineStore`
/// against a tmp-directory database file. No production app flow uses
/// the store yet — these tests pin the schema/round-trip contract so a
/// future migration can rely on it.
///
/// All tests run on Linux (using the system `libsqlite3` via the
/// `CSQLite` system-library target) and on Apple platforms (via the
/// SDK-bundled `SQLite3` module).
final class LocalTimelineStoreTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LocalTimelineStoreTests-\(UUID().uuidString)",
                                    isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    private func makeStore(_ name: String = "timeline.sqlite") throws -> LocalTimelineStore {
        try LocalTimelineStore(url: tempDir.appendingPathComponent(name))
    }

    // MARK: - 11. Schema bootstrap

    func testCreateSchemaAndUserVersion() throws {
        let store = try makeStore()
        defer { store.close() }
        XCTAssertEqual(try store.userVersion(), LocalTimelineStoreSchema.userVersion)
        XCTAssertEqual(try store.countImports(), 0)
        XCTAssertEqual(try store.countDays(), 0)
        XCTAssertEqual(try store.countPaths(), 0)
    }

    func testReopenIsIdempotent() throws {
        let url = tempDir.appendingPathComponent("idempotent.sqlite")
        do {
            let store = try LocalTimelineStore(url: url)
            try store.insertImport(.init(id: "imp", sourceFilename: "x.zip",
                                         createdAt: "2026-05-08T00:00:00Z"))
            store.close()
        }
        let reopened = try LocalTimelineStore(url: url)
        defer { reopened.close() }
        XCTAssertEqual(try reopened.countImports(), 1)
        XCTAssertEqual(try reopened.userVersion(), LocalTimelineStoreSchema.userVersion)
    }

    // MARK: - 12. Insert import / day / path

    func testInsertImportDayPath() throws {
        let store = try makeStore()
        defer { store.close() }

        let importId = "imp-1"
        let dayId = "day-1"
        try store.insertImport(.init(id: importId, sourceFilename: "Records.json",
                                     createdAt: "2026-05-08T10:00:00Z"))
        try store.insertDay(.init(id: dayId, importId: importId, date: "2026-05-08",
                                  routeCount: 1, visitCount: 0, distanceM: 1234.5))
        let blob = try CoordBlobEncoder.encode(flatCoordinates: [52.52, 13.40, 52.53, 13.41])
        try store.insertPath(.init(
            id: "path-1", dayId: dayId,
            startTime: "2026-05-08T10:00:00Z", endTime: "2026-05-08T10:15:00Z",
            mode: "walking", distanceM: 1234.5, pointCount: 2,
            minLat: 52.52, minLon: 13.40, maxLat: 52.53, maxLon: 13.41,
            coordEncoding: CoordBlobEncoding.int32MicrodegreesV1, coordBlob: blob))

        XCTAssertEqual(try store.countImports(), 1)
        XCTAssertEqual(try store.countDays(), 1)
        XCTAssertEqual(try store.countPaths(), 1)
    }

    // MARK: - 13. Query paths by day

    func testQueryPathsByDayOrderedByStartTime() throws {
        let store = try makeStore()
        defer { store.close() }
        try store.insertImport(.init(id: "i", sourceFilename: "f", createdAt: "t"))
        try store.insertDay(.init(id: "d1", importId: "i", date: "2026-05-08",
                                  routeCount: 2, visitCount: 0, distanceM: 0))
        try store.insertDay(.init(id: "d2", importId: "i", date: "2026-05-09",
                                  routeCount: 0, visitCount: 0, distanceM: 0))

        let blobA = try CoordBlobEncoder.encode(flatCoordinates: [1, 1])
        let blobB = try CoordBlobEncoder.encode(flatCoordinates: [2, 2])
        try store.insertPath(.init(id: "pB", dayId: "d1", startTime: "2026-05-08T12:00:00Z",
                                   endTime: nil, mode: "walking", distanceM: 0, pointCount: 1,
                                   minLat: nil, minLon: nil, maxLat: nil, maxLon: nil,
                                   coordEncoding: CoordBlobEncoding.int32MicrodegreesV1,
                                   coordBlob: blobB))
        try store.insertPath(.init(id: "pA", dayId: "d1", startTime: "2026-05-08T08:00:00Z",
                                   endTime: nil, mode: "walking", distanceM: 0, pointCount: 1,
                                   minLat: nil, minLon: nil, maxLat: nil, maxLon: nil,
                                   coordEncoding: CoordBlobEncoding.int32MicrodegreesV1,
                                   coordBlob: blobA))

        let d1Paths = try store.paths(forDayId: "d1")
        XCTAssertEqual(d1Paths.map(\.id), ["pA", "pB"])
        XCTAssertTrue(try store.paths(forDayId: "d2").isEmpty)
    }

    // MARK: - 14. Coord blob storage round-trip

    func testCoordBlobRoundTripThroughStore() throws {
        let store = try makeStore()
        defer { store.close() }
        try store.insertImport(.init(id: "i", sourceFilename: "f", createdAt: "t"))
        try store.insertDay(.init(id: "d", importId: "i", date: "2026-05-08",
                                  routeCount: 1, visitCount: 0, distanceM: 0))

        let originalFlat: [Double] = [
            52.520008, 13.404954,
            48.137154, 11.575382,
            50.110924,  8.682127,
            -33.868820, 151.209296,
        ]
        let blob = try CoordBlobEncoder.encode(flatCoordinates: originalFlat)

        try store.insertPath(.init(
            id: "p", dayId: "d", startTime: nil, endTime: nil,
            mode: nil, distanceM: 0, pointCount: 4,
            minLat: nil, minLon: nil, maxLat: nil, maxLon: nil,
            coordEncoding: CoordBlobEncoding.int32MicrodegreesV1, coordBlob: blob))

        let rows = try store.paths(forDayId: "d")
        XCTAssertEqual(rows.count, 1)
        let stored = rows[0]
        XCTAssertEqual(stored.coordEncoding, CoordBlobEncoding.int32MicrodegreesV1)
        XCTAssertEqual(stored.coordBlob.count, 4 * CoordBlobEncoding.bytesPerPoint)

        let decoded = try CoordBlobIterator.decodeAll(stored.coordBlob)
        XCTAssertEqual(decoded.count, 4)
        for (i, point) in decoded.enumerated() {
            XCTAssertEqual(point.latitude,  originalFlat[2*i],     accuracy: 5e-7)
            XCTAssertEqual(point.longitude, originalFlat[2*i + 1], accuracy: 5e-7)
        }
    }

    // MARK: - 15. Cascade delete

    func testDeleteImportCascades() throws {
        let store = try makeStore()
        defer { store.close() }
        try store.insertImport(.init(id: "i", sourceFilename: "f", createdAt: "t"))
        try store.insertDay(.init(id: "d", importId: "i", date: "2026-05-08",
                                  routeCount: 1, visitCount: 0, distanceM: 0))
        let blob = try CoordBlobEncoder.encode(flatCoordinates: [1, 1])
        try store.insertPath(.init(id: "p", dayId: "d", startTime: nil, endTime: nil,
                                   mode: nil, distanceM: 0, pointCount: 1,
                                   minLat: nil, minLon: nil, maxLat: nil, maxLon: nil,
                                   coordEncoding: CoordBlobEncoding.int32MicrodegreesV1,
                                   coordBlob: blob))

        try store.deleteImport(id: "i")
        XCTAssertEqual(try store.countImports(), 0)
        XCTAssertEqual(try store.countDays(), 0, "ON DELETE CASCADE must drop dependent days")
        XCTAssertEqual(try store.countPaths(), 0, "ON DELETE CASCADE must drop dependent paths")
    }

    func testForeignKeyViolationOnOrphanDay() throws {
        let store = try makeStore()
        defer { store.close() }
        XCTAssertThrowsError(try store.insertDay(.init(
            id: "d", importId: "missing", date: "2026-05-08",
            routeCount: 0, visitCount: 0, distanceM: 0))) { error in
            guard case .foreignKeyViolation = error as? LocalTimelineStoreError else {
                return XCTFail("Expected .foreignKeyViolation, got \(error)")
            }
        }
    }

    // MARK: - 16. Batch transaction smoke

    func testBatchTransactionInsertsManyPaths() throws {
        let store = try makeStore()
        defer { store.close() }
        try store.insertImport(.init(id: "i", sourceFilename: "f", createdAt: "t"))
        try store.insertDay(.init(id: "d", importId: "i", date: "2026-05-08",
                                  routeCount: 0, visitCount: 0, distanceM: 0))

        let pathCount = 500
        let pointsPerPath = 50
        let flatTemplate = (0..<pointsPerPath).flatMap { i -> [Double] in
            [50.0 + Double(i) * 1e-4, 10.0 + Double(i) * 1e-4]
        }
        let blob = try CoordBlobEncoder.encode(flatCoordinates: flatTemplate)

        try store.withTransaction {
            for n in 0..<pathCount {
                try store.insertPath(.init(
                    id: "p-\(n)", dayId: "d",
                    startTime: String(format: "2026-05-08T%02d:00:00Z", n % 24),
                    endTime: nil, mode: "walking",
                    distanceM: 0, pointCount: pointsPerPath,
                    minLat: nil, minLon: nil, maxLat: nil, maxLon: nil,
                    coordEncoding: CoordBlobEncoding.int32MicrodegreesV1,
                    coordBlob: blob))
            }
        }

        XCTAssertEqual(try store.countPaths(), pathCount)
    }
}
