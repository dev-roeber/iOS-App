import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Direct coverage for `LocalTimelineImportWriter` aggregation semantics.
final class LocalTimelineImportWriterTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTIWriter-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    private func makeStore() throws -> LocalTimelineStore {
        try LocalTimelineStore(url: tempDir.appendingPathComponent("w.sqlite"))
    }

    func testDaySummaryAggregation() throws {
        let store = try makeStore()
        defer { store.close() }
        let writer = try LocalTimelineImportWriter(store: store, source: "agg.json")
        try writer.addVisit(.init(startTime: "2026-05-08T08:00:00Z",
                                  latitude: 52.5, longitude: 13.4))
        try writer.addVisit(.init(startTime: "2026-05-08T12:00:00Z",
                                  latitude: 52.5, longitude: 13.4))
        try writer.addPath(.init(startTime: "2026-05-08T09:00:00Z",
                                 distanceM: 1000,
                                 flatCoordinates: [52.5, 13.4, 52.51, 13.41]))
        try writer.addPath(.init(startTime: "2026-05-08T10:00:00Z",
                                 distanceM: 500,
                                 flatCoordinates: [52.5, 13.4, 52.52, 13.42]))
        // Different day:
        try writer.addVisit(.init(startTime: "2026-05-09T08:00:00Z",
                                  latitude: 52.5, longitude: 13.4))
        let summary = try writer.finalize()

        XCTAssertEqual(summary.dayCount, 2)
        XCTAssertEqual(summary.totalEntries, 5)
        XCTAssertEqual(summary.skippedEntries, 0)

        let days = try store.days(forImportId: summary.importId)
        XCTAssertEqual(days.count, 2)
        let may8 = try XCTUnwrap(days.first { $0.date == "2026-05-08" })
        let may9 = try XCTUnwrap(days.first { $0.date == "2026-05-09" })
        XCTAssertEqual(may8.routeCount, 2)
        XCTAssertEqual(may8.visitCount, 2)
        XCTAssertEqual(may8.distanceM, 1500, accuracy: 1e-6)
        XCTAssertEqual(may9.visitCount, 1)
        XCTAssertEqual(may9.routeCount, 0)
    }

    func testInvalidEntriesAreSkippedNotThrown() throws {
        let store = try makeStore()
        defer { store.close() }
        let writer = try LocalTimelineImportWriter(store: store, source: "skip.json")

        // Missing startTime → drop.
        try writer.addVisit(.init(startTime: nil, latitude: 52.5, longitude: 13.4))
        // Unparseable startTime → drop.
        try writer.addActivity(.init(startTime: "not-a-date", mode: "WALKING"))
        // Path too short → drop.
        try writer.addPath(.init(startTime: "2026-05-08T08:00:00Z",
                                 flatCoordinates: [52.5, 13.4]))
        // Odd-length coords → drop (encoder would throw, writer must not).
        try writer.addPath(.init(startTime: "2026-05-08T08:00:00Z",
                                 flatCoordinates: [52.5, 13.4, 52.51]))
        // Valid:
        try writer.addPath(.init(startTime: "2026-05-08T08:00:00Z",
                                 distanceM: 250,
                                 flatCoordinates: [52.5, 13.4, 52.51, 13.41]))

        let summary = try writer.finalize()
        XCTAssertEqual(summary.totalEntries, 5)
        XCTAssertEqual(summary.skippedEntries, 4)
        XCTAssertEqual(try store.countPaths(), 1)
    }

    func testCancelRollsBackImport() throws {
        let store = try makeStore()
        defer { store.close() }
        let writer = try LocalTimelineImportWriter(store: store, source: "rollback.json")
        try writer.addVisit(.init(startTime: "2026-05-08T08:00:00Z",
                                  latitude: 52.5, longitude: 13.4))
        writer.cancel()

        XCTAssertEqual(try store.countImports(), 0)
        XCTAssertEqual(try store.countDays(), 0)
        XCTAssertEqual(try store.countVisits(), 0)
    }

    func testPathBoundingBoxIsRecorded() throws {
        let store = try makeStore()
        defer { store.close() }
        let writer = try LocalTimelineImportWriter(store: store, source: "bbox.json")
        try writer.addPath(.init(
            startTime: "2026-05-08T08:00:00Z",
            flatCoordinates: [52.5, 13.4, 52.6, 13.3, 52.45, 13.5]))
        let summary = try writer.finalize()
        let day = try store.days(forImportId: summary.importId)[0]
        let path = try store.paths(forDayId: day.id)[0]
        XCTAssertEqual(try XCTUnwrap(path.minLat), 52.45, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(path.maxLat), 52.6,  accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(path.minLon), 13.3,  accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(path.maxLon), 13.5,  accuracy: 1e-9)
        XCTAssertEqual(path.coordEncoding, CoordBlobEncoding.int32MicrodegreesV1)
    }
}
