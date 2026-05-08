import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Verifies that the Phase-3 reader surface still works after the underlying
/// `LocalTimelineStore` has been closed and re-opened on the same on-disk
/// database file. Also covers `deleteAll()` semantics and SQL-special-character
/// round-trips through the reader.
final class LocalTimelineStoreReadPersistenceTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTSReadPers-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    private func storeURL(_ name: String = "store.sqlite") -> URL {
        tempDir.appendingPathComponent(name)
    }

    // MARK: - Reopen

    func testReopenPreservesImportRowsForReader() throws {
        let url = storeURL()
        let storeA = try LocalTimelineStore(url: url)
        let writer = try LocalTimelineImportWriter(store: storeA, source: "persist.json")
        try writer.addVisit(.init(startTime: "2026-05-08T08:00:00Z",
                                  latitude: 52.5, longitude: 13.4))
        let summary = try writer.finalize()
        storeA.close()

        let storeB = try LocalTimelineStore(url: url)
        defer { storeB.close() }
        let reader = LocalTimelineStoreReader(store: storeB)
        let imports = try reader.imports()
        XCTAssertEqual(imports.count, 1)
        XCTAssertEqual(imports.first?.id, summary.importId)
        XCTAssertEqual(imports.first?.sourceFilename, "persist.json")
    }

    func testReopenPreservesDaysVisitsActivitiesPathsForReader() throws {
        let url = storeURL()
        let storeA = try LocalTimelineStore(url: url)
        let writer = try LocalTimelineImportWriter(store: storeA, source: "all.json")
        try writer.addVisit(.init(startTime: "2026-05-08T08:00:00Z",
                                  latitude: 52.5, longitude: 13.4, name: "Home"))
        try writer.addActivity(.init(startTime: "2026-05-08T09:00:00Z",
                                     mode: "WALKING", distanceM: 1500),
                                includeStartEndPath: false)
        try writer.addPath(.init(startTime: "2026-05-08T10:00:00Z",
                                 distanceM: 500,
                                 flatCoordinates: [52.5, 13.4, 52.51, 13.41, 52.52, 13.42]))
        let summary = try writer.finalize()
        storeA.close()

        let storeB = try LocalTimelineStore(url: url)
        defer { storeB.close() }
        let reader = LocalTimelineStoreReader(store: storeB)

        let days = try reader.days(forImportId: summary.importId)
        XCTAssertEqual(days.count, 1)
        let detail = try XCTUnwrap(reader.dayDetail(dayId: days[0].id))
        XCTAssertEqual(detail.visits.count, 1)
        XCTAssertEqual(detail.visits.first?.name, "Home")
        XCTAssertEqual(detail.activities.count, 1)
        XCTAssertEqual(detail.activities.first?.mode, "WALKING")
        XCTAssertEqual(detail.paths.count, 1)
        XCTAssertEqual(detail.paths.first?.pointCount, 3)
    }

    func testReopenAllowsCoordinateSequenceDecode() throws {
        let url = storeURL()
        let storeA = try LocalTimelineStore(url: url)
        let writer = try LocalTimelineImportWriter(store: storeA, source: "coords.json")
        let coords: [Double] = [
            52.5, 13.4,
            52.51, 13.41,
            52.52, 13.42,
            52.53, 13.43,
        ]
        try writer.addPath(.init(startTime: "2026-05-08T08:00:00Z",
                                 distanceM: 100,
                                 flatCoordinates: coords))
        let summary = try writer.finalize()
        storeA.close()

        let storeB = try LocalTimelineStore(url: url)
        defer { storeB.close() }
        let reader = LocalTimelineStoreReader(store: storeB)
        let day = try XCTUnwrap(reader.days(forImportId: summary.importId).first)
        let path = try XCTUnwrap(reader.paths(forDayId: day.id).first)
        let decoded = Array(try reader.coordinateSequence(forPathId: path.id))
        XCTAssertEqual(decoded.count, 4)
        for i in 0..<4 {
            XCTAssertEqual(decoded[i].latitude, coords[2 * i], accuracy: 1e-6)
            XCTAssertEqual(decoded[i].longitude, coords[2 * i + 1], accuracy: 1e-6)
        }
    }

    func testReopenPathMetadataExposesCoordEncodingAndPointCount() throws {
        let url = storeURL()
        let storeA = try LocalTimelineStore(url: url)
        let writer = try LocalTimelineImportWriter(store: storeA, source: "meta.json")
        let n = 6
        var flat: [Double] = []
        flat.reserveCapacity(n * 2)
        for i in 0..<n {
            flat.append(52.5 + Double(i) * 0.01)
            flat.append(13.4 + Double(i) * 0.01)
        }
        try writer.addPath(.init(startTime: "2026-05-08T08:00:00Z",
                                 distanceM: 200, flatCoordinates: flat))
        let summary = try writer.finalize()
        storeA.close()

        let storeB = try LocalTimelineStore(url: url)
        defer { storeB.close() }
        let reader = LocalTimelineStoreReader(store: storeB)
        let day = try XCTUnwrap(reader.days(forImportId: summary.importId).first)
        let path = try XCTUnwrap(reader.paths(forDayId: day.id).first)
        XCTAssertEqual(path.coordEncoding, CoordBlobEncoding.int32MicrodegreesV1)
        XCTAssertEqual(path.pointCount, n)
    }

    // MARK: - deleteAll

    func testDeleteAllEmptiesAllReaderAPIs() throws {
        let store = try LocalTimelineStore(url: storeURL())
        defer { store.close() }
        let writer = try LocalTimelineImportWriter(store: store, source: "wipe.json")
        try writer.addPath(.init(startTime: "2026-05-08T08:00:00Z",
                                 distanceM: 100,
                                 flatCoordinates: [52.5, 13.4, 52.51, 13.41]))
        let summary = try writer.finalize()

        let reader = LocalTimelineStoreReader(store: store)
        let day = try XCTUnwrap(reader.days(forImportId: summary.importId).first)
        let path = try XCTUnwrap(reader.paths(forDayId: day.id).first)
        let pathId = path.id

        try store.deleteAll()

        XCTAssertEqual(try reader.imports(), [])
        XCTAssertNil(try reader.latestImport())
        XCTAssertEqual(try reader.days(forImportId: summary.importId), [])
        XCTAssertNil(try reader.dayDetail(dayId: day.id))
        XCTAssertThrowsError(try reader.coordinateSequence(forPathId: pathId)) { error in
            XCTAssertEqual(error as? LocalTimelineStoreReader.ReaderError,
                           .unknownPath(pathId: pathId))
        }
    }

    // MARK: - SQL special characters

    func testSQLSpecialCharactersRoundTrip() throws {
        let store = try LocalTimelineStore(url: storeURL())
        defer { store.close() }

        let weirdSource = #"O'Brien's "weird";--/ü.json"#
        let weirdName = #"Café "O'Brien"; DROP TABLE imports;--"#

        let writer = try LocalTimelineImportWriter(store: store, source: weirdSource)
        try writer.addVisit(.init(startTime: "2026-05-08T08:00:00Z",
                                  latitude: 52.5, longitude: 13.4,
                                  name: weirdName,
                                  semanticType: "HOME",
                                  placeId: "p'1\";--"))
        let summary = try writer.finalize()

        let reader = LocalTimelineStoreReader(store: store)
        let imports = try reader.imports()
        XCTAssertEqual(imports.count, 1)
        XCTAssertEqual(imports[0].sourceFilename, weirdSource)

        let day = try XCTUnwrap(reader.days(forImportId: summary.importId).first)
        let detail = try XCTUnwrap(reader.dayDetail(dayId: day.id))
        XCTAssertEqual(detail.visits.count, 1)
        XCTAssertEqual(detail.visits[0].name, weirdName)
        XCTAssertEqual(detail.visits[0].placeId, "p'1\";--")
        XCTAssertEqual(detail.visits[0].semanticType, "HOME")
    }
}
