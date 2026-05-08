import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-3 reader-surface coverage. Verifies that
/// `LocalTimelineStoreReader` exposes imports/days/day-detail/path metadata
/// and a lazy coordinate sequence — without ever materialising an
/// `AppExport` or a `[Double]` of coordinates for an entire import.
final class LocalTimelineStoreReaderTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTSReader-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    private func makeStore(_ name: String = "store.sqlite") throws -> LocalTimelineStore {
        try LocalTimelineStore(url: tempDir.appendingPathComponent(name))
    }

    private func clockOptions(offset: TimeInterval) -> LocalTimelineImportWriter.Options {
        LocalTimelineImportWriter.Options(
            clock: { Date(timeIntervalSince1970: 1_700_000_000 + offset) }
        )
    }

    // MARK: - Imports

    func testImportsListedNewestFirst() throws {
        let store = try makeStore()
        defer { store.close() }

        let w1 = try LocalTimelineImportWriter(store: store, source: "first.json",
                                               options: clockOptions(offset: 0))
        _ = try w1.finalize()
        let w2 = try LocalTimelineImportWriter(store: store, source: "second.json",
                                               options: clockOptions(offset: 100))
        _ = try w2.finalize()
        let w3 = try LocalTimelineImportWriter(store: store, source: "third.json",
                                               options: clockOptions(offset: 200))
        _ = try w3.finalize()

        let reader = LocalTimelineStoreReader(store: store)
        let imports = try reader.imports()
        XCTAssertEqual(imports.count, 3)
        XCTAssertEqual(imports.map(\.sourceFilename), ["third.json", "second.json", "first.json"])
        // createdAt strictly descending
        XCTAssertGreaterThan(imports[0].createdAt, imports[1].createdAt)
        XCTAssertGreaterThan(imports[1].createdAt, imports[2].createdAt)
    }

    func testLatestImportReturnsNewest() throws {
        let store = try makeStore()
        defer { store.close() }

        let wOld = try LocalTimelineImportWriter(store: store, source: "old.json",
                                                 options: clockOptions(offset: 0))
        _ = try wOld.finalize()
        let wNew = try LocalTimelineImportWriter(store: store, source: "new.json",
                                                 options: clockOptions(offset: 1_000))
        let newSummary = try wNew.finalize()

        let reader = LocalTimelineStoreReader(store: store)
        XCTAssertEqual(try reader.latestImport()?.id, newSummary.importId)
        XCTAssertEqual(try reader.latestImport()?.sourceFilename, "new.json")
    }

    func testLatestImportNilOnEmptyStore() throws {
        let store = try makeStore()
        defer { store.close() }
        let reader = LocalTimelineStoreReader(store: store)
        XCTAssertNil(try reader.latestImport())
    }

    func testImportsEmptyOnEmptyStore() throws {
        let store = try makeStore()
        defer { store.close() }
        let reader = LocalTimelineStoreReader(store: store)
        XCTAssertEqual(try reader.imports(), [])
    }

    func testImportRecordByIdReturnsNilForUnknown() throws {
        let store = try makeStore()
        defer { store.close() }
        let reader = LocalTimelineStoreReader(store: store)
        XCTAssertNil(try reader.importRecord(id: "does-not-exist"))
    }

    // MARK: - Days

    func testDaysForImportOrderedByDate() throws {
        let store = try makeStore()
        defer { store.close() }
        let writer = try LocalTimelineImportWriter(store: store, source: "days.json")
        try writer.addVisit(.init(startTime: "2026-05-10T08:00:00Z",
                                  latitude: 52.5, longitude: 13.4))
        try writer.addVisit(.init(startTime: "2026-05-08T09:00:00Z",
                                  latitude: 52.5, longitude: 13.4))
        try writer.addVisit(.init(startTime: "2026-05-09T10:00:00Z",
                                  latitude: 52.5, longitude: 13.4))
        let summary = try writer.finalize()

        let reader = LocalTimelineStoreReader(store: store)
        let days = try reader.days(forImportId: summary.importId)
        XCTAssertEqual(days.map(\.date), ["2026-05-08", "2026-05-09", "2026-05-10"])
    }

    func testDayCountMatchesInsertedDays() throws {
        let store = try makeStore()
        defer { store.close() }
        let writer = try LocalTimelineImportWriter(store: store, source: "count.json")
        try writer.addVisit(.init(startTime: "2026-05-08T08:00:00Z",
                                  latitude: 1, longitude: 2))
        try writer.addVisit(.init(startTime: "2026-05-09T08:00:00Z",
                                  latitude: 1, longitude: 2))
        try writer.addVisit(.init(startTime: "2026-05-10T08:00:00Z",
                                  latitude: 1, longitude: 2))
        let summary = try writer.finalize()

        let reader = LocalTimelineStoreReader(store: store)
        XCTAssertEqual(try reader.dayCount(forImportId: summary.importId), 3)
    }

    func testDayRecordByIdAndByImportDate() throws {
        let store = try makeStore()
        defer { store.close() }
        let writer = try LocalTimelineImportWriter(store: store, source: "lookup.json")
        try writer.addVisit(.init(startTime: "2026-05-08T08:00:00Z",
                                  latitude: 52.5, longitude: 13.4))
        let summary = try writer.finalize()

        let reader = LocalTimelineStoreReader(store: store)
        let byImportDate = try XCTUnwrap(
            reader.dayRecord(forImportId: summary.importId, date: "2026-05-08")
        )
        let byId = try XCTUnwrap(reader.dayRecord(id: byImportDate.id))
        XCTAssertEqual(byId, byImportDate)
        XCTAssertEqual(byId.date, "2026-05-08")
        XCTAssertEqual(byId.importId, summary.importId)
    }

    // MARK: - Day detail

    func testDayDetailContainsVisitsActivitiesAndPathMetadataOrderedByStartTime() throws {
        let store = try makeStore()
        defer { store.close() }
        let writer = try LocalTimelineImportWriter(store: store, source: "detail.json")
        // Insertion order intentionally non-monotonic; reader must sort by start_time.
        try writer.addVisit(.init(startTime: "2026-05-08T12:00:00Z",
                                  latitude: 52.5, longitude: 13.4, name: "Lunch"))
        try writer.addVisit(.init(startTime: "2026-05-08T08:00:00Z",
                                  latitude: 52.5, longitude: 13.4, name: "Morning"))
        try writer.addActivity(.init(startTime: "2026-05-08T11:00:00Z",
                                     mode: "WALKING", distanceM: 100),
                                includeStartEndPath: false)
        try writer.addActivity(.init(startTime: "2026-05-08T09:30:00Z",
                                     mode: "DRIVING", distanceM: 200),
                                includeStartEndPath: false)
        try writer.addPath(.init(startTime: "2026-05-08T10:30:00Z",
                                 distanceM: 50,
                                 flatCoordinates: [52.5, 13.4, 52.51, 13.41]))
        try writer.addPath(.init(startTime: "2026-05-08T07:30:00Z",
                                 distanceM: 25,
                                 flatCoordinates: [52.5, 13.4, 52.49, 13.39]))
        let summary = try writer.finalize()

        let reader = LocalTimelineStoreReader(store: store)
        let day = try XCTUnwrap(
            reader.dayRecord(forImportId: summary.importId, date: "2026-05-08")
        )
        let detail = try XCTUnwrap(reader.dayDetail(dayId: day.id))

        XCTAssertEqual(detail.day.id, day.id)
        XCTAssertEqual(detail.visits.map(\.startTime),
                       ["2026-05-08T08:00:00Z", "2026-05-08T12:00:00Z"])
        XCTAssertEqual(detail.activities.map(\.startTime),
                       ["2026-05-08T09:30:00Z", "2026-05-08T11:00:00Z"])
        XCTAssertEqual(detail.paths.map(\.startTime),
                       ["2026-05-08T07:30:00Z", "2026-05-08T10:30:00Z"])
        // Each path metadata carries its point count; bounded reads do not
        // expose a coord blob property.
        for path in detail.paths {
            XCTAssertEqual(path.pointCount, 2)
            XCTAssertEqual(path.coordEncoding, CoordBlobEncoding.int32MicrodegreesV1)
        }
    }

    func testDayDetailReturnsNilForUnknownDayId() throws {
        let store = try makeStore()
        defer { store.close() }
        let reader = LocalTimelineStoreReader(store: store)
        XCTAssertNil(try reader.dayDetail(dayId: "no-such-day"))
    }

    // MARK: - Coordinate sequence

    func testCoordinateSequenceDecodesExactlyOnePathLazily() throws {
        let store = try makeStore()
        defer { store.close() }
        let writer = try LocalTimelineImportWriter(store: store, source: "seq.json")
        let coords: [Double] = [
            52.5, 13.4,
            52.51, 13.41,
            52.52, 13.42,
            52.53, 13.43,
            52.54, 13.44,
        ]
        try writer.addPath(.init(startTime: "2026-05-08T08:00:00Z",
                                 distanceM: 100,
                                 flatCoordinates: coords))
        let summary = try writer.finalize()

        let reader = LocalTimelineStoreReader(store: store)
        let day = try XCTUnwrap(
            reader.dayRecord(forImportId: summary.importId, date: "2026-05-08")
        )
        let path = try XCTUnwrap(reader.paths(forDayId: day.id).first)
        XCTAssertEqual(path.pointCount, 5)

        let seq = try reader.coordinateSequence(forPathId: path.id)
        let decoded: [EncodedCoordinate] = Array(seq)
        XCTAssertEqual(decoded.count, 5)
        for i in 0..<5 {
            XCTAssertEqual(decoded[i].latitude, coords[2 * i], accuracy: 1e-6)
            XCTAssertEqual(decoded[i].longitude, coords[2 * i + 1], accuracy: 1e-6)
        }
    }

    func testCoordinateSequenceThrowsUnknownPathForMissingId() throws {
        let store = try makeStore()
        defer { store.close() }
        let reader = LocalTimelineStoreReader(store: store)
        XCTAssertThrowsError(try reader.coordinateSequence(forPathId: "ghost-path")) { error in
            XCTAssertEqual(error as? LocalTimelineStoreReader.ReaderError,
                           .unknownPath(pathId: "ghost-path"))
        }
    }

    // MARK: - Aggregates

    func testDayDateRangeAndTotals() throws {
        let store = try makeStore()
        defer { store.close() }
        let writer = try LocalTimelineImportWriter(store: store, source: "totals.json")
        // Day 2026-05-08: 2 visits, 1 path 100m
        try writer.addVisit(.init(startTime: "2026-05-08T08:00:00Z",
                                  latitude: 1, longitude: 2))
        try writer.addVisit(.init(startTime: "2026-05-08T09:00:00Z",
                                  latitude: 1, longitude: 2))
        try writer.addPath(.init(startTime: "2026-05-08T10:00:00Z",
                                 distanceM: 100,
                                 flatCoordinates: [1, 2, 3, 4]))
        // Day 2026-05-09: 1 visit, 2 paths total 250m
        try writer.addVisit(.init(startTime: "2026-05-09T08:00:00Z",
                                  latitude: 1, longitude: 2))
        try writer.addPath(.init(startTime: "2026-05-09T09:00:00Z",
                                 distanceM: 100,
                                 flatCoordinates: [1, 2, 3, 4]))
        try writer.addPath(.init(startTime: "2026-05-09T10:00:00Z",
                                 distanceM: 150,
                                 flatCoordinates: [1, 2, 3, 4]))
        // Day 2026-05-10: 3 visits, 0 paths
        try writer.addVisit(.init(startTime: "2026-05-10T08:00:00Z",
                                  latitude: 1, longitude: 2))
        try writer.addVisit(.init(startTime: "2026-05-10T09:00:00Z",
                                  latitude: 1, longitude: 2))
        try writer.addVisit(.init(startTime: "2026-05-10T10:00:00Z",
                                  latitude: 1, longitude: 2))
        let summary = try writer.finalize()

        let reader = LocalTimelineStoreReader(store: store)
        let range = try XCTUnwrap(reader.dayDateRange(forImportId: summary.importId))
        XCTAssertEqual(range, "2026-05-08"..."2026-05-10")

        XCTAssertEqual(try reader.totalDistance(forImportId: summary.importId),
                       350, accuracy: 1e-6)
        XCTAssertEqual(try reader.totalRouteCount(forImportId: summary.importId), 3)
        XCTAssertEqual(try reader.totalVisitCount(forImportId: summary.importId), 6)
    }

    // MARK: - Type-surface guarantees

    func testReaderReturnTypeIsNotAppExport() throws {
        let store = try makeStore()
        defer { store.close() }
        let writer = try LocalTimelineImportWriter(store: store, source: "type.json")
        try writer.addVisit(.init(startTime: "2026-05-08T08:00:00Z",
                                  latitude: 52.5, longitude: 13.4))
        let summary = try writer.finalize()

        let reader = LocalTimelineStoreReader(store: store)
        let importsAny: Any = try reader.imports()
        XCTAssertFalse(importsAny is AppExport,
                       "reader.imports() must not return AppExport")
        let day = try XCTUnwrap(reader.days(forImportId: summary.importId).first)
        let detailAny: Any = try XCTUnwrap(reader.dayDetail(dayId: day.id))
        XCTAssertFalse(detailAny is AppExport,
                       "reader.dayDetail(dayId:) must not return AppExport")
    }
}
