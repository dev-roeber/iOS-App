import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Structural bounded-read guarantees for the Phase-3 reader surface.
///
/// These tests are deliberately structural / behavioural — they do **not**
/// rely on wall-clock or memory probes. They demonstrate that the reader's
/// bounded-read contract (no decoded `[Double]` for whole imports, no eager
/// path materialisation in day-list / day-detail) is enforced by the public
/// API shape and behaviour.
final class LocalTimelineStoreBoundedReadTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTSBounded-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    private func makeStore(_ name: String = "store.sqlite") throws -> LocalTimelineStore {
        try LocalTimelineStore(url: tempDir.appendingPathComponent(name))
    }

    // MARK: - Day list does not expose coordinates

    func testDaysForImportDoesNotExposeCoordinates() throws {
        let store = try makeStore()
        defer { store.close() }
        let writer = try LocalTimelineImportWriter(store: store, source: "many-days.json")
        let cal = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2026; components.month = 1; components.day = 1
        components.hour = 8
        components.timeZone = TimeZone(secondsFromGMT: 0)
        let base = cal.date(from: components)!
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        let dayCount = 100
        for i in 0..<dayCount {
            let start = cal.date(byAdding: .day, value: i, to: base)!
            let iso = isoFormatter.string(from: start)
            try writer.addPath(.init(startTime: iso,
                                     distanceM: 10,
                                     flatCoordinates: [52.5, 13.4, 52.51, 13.41]))
        }
        let summary = try writer.finalize()

        let reader = LocalTimelineStoreReader(store: store)
        let days = try reader.days(forImportId: summary.importId)
        XCTAssertEqual(days.count, dayCount)
        for day in days {
            XCTAssertEqual(day.routeCount, 1)
            XCTAssertEqual(day.importId, summary.importId)
            // Compile-time bounded-read guarantee: LocalTimelineDayRecord
            // has no path / coord-blob property; we can only see summary
            // counts and aggregate distance.
            _ = day.distanceM
        }
    }

    // MARK: - Day detail returns metadata only

    func testDayDetailReturnsPathMetadataWithoutCoordBlob() throws {
        let store = try makeStore()
        defer { store.close() }
        let writer = try LocalTimelineImportWriter(store: store, source: "detail.json")
        let n = 4
        for i in 0..<n {
            let coords: [Double] = [
                52.5 + Double(i) * 0.001, 13.4,
                52.51 + Double(i) * 0.001, 13.41,
                52.52 + Double(i) * 0.001, 13.42,
            ]
            let iso = String(format: "2026-05-08T08:%02d:00Z", i * 5)
            try writer.addPath(.init(startTime: iso,
                                     distanceM: 75,
                                     flatCoordinates: coords))
        }
        let summary = try writer.finalize()

        let reader = LocalTimelineStoreReader(store: store)
        let day = try XCTUnwrap(reader.days(forImportId: summary.importId).first)
        let detail = try XCTUnwrap(reader.dayDetail(dayId: day.id))

        XCTAssertEqual(detail.paths.count, n)
        for path in detail.paths {
            // Compile-time bounded-read guarantee: LocalTimelinePathRecord
            // does NOT carry a `coordBlob` property — only metadata.
            XCTAssertEqual(path.pointCount, 3)
            XCTAssertEqual(path.coordEncoding, CoordBlobEncoding.int32MicrodegreesV1)
            XCTAssertNotNil(path.minLat)
            XCTAssertNotNil(path.maxLat)
        }
        // Sanity: dayDetail does NOT decode coords on the caller's behalf —
        // the only way to obtain them is the explicit iterator API used in
        // testCoordinateSequenceDecodesOnlyTheRequestedPath. We never call
        // it here.
    }

    // MARK: - Coordinate sequence is per-path

    func testCoordinateSequenceDecodesOnlyTheRequestedPath() throws {
        let store = try makeStore()
        defer { store.close() }
        let writer = try LocalTimelineImportWriter(store: store, source: "two.json")
        let coordsA: [Double] = [52.50, 13.40, 52.51, 13.41]
        let coordsB: [Double] = [40.10, -74.00, 40.11, -74.01, 40.12, -74.02]
        try writer.addPath(.init(startTime: "2026-05-08T08:00:00Z",
                                 distanceM: 100, flatCoordinates: coordsA))
        try writer.addPath(.init(startTime: "2026-05-08T09:00:00Z",
                                 distanceM: 200, flatCoordinates: coordsB))
        let summary = try writer.finalize()

        let reader = LocalTimelineStoreReader(store: store)
        let day = try XCTUnwrap(reader.days(forImportId: summary.importId).first)
        let paths = try reader.paths(forDayId: day.id)
        XCTAssertEqual(paths.count, 2)
        let pathA = try XCTUnwrap(paths.first { $0.startTime == "2026-05-08T08:00:00Z" })
        let pathB = try XCTUnwrap(paths.first { $0.startTime == "2026-05-08T09:00:00Z" })

        let decodedA = Array(try reader.coordinateSequence(forPathId: pathA.id))
        XCTAssertEqual(decodedA.count, 2)
        XCTAssertEqual(decodedA[0].latitude, 52.50, accuracy: 1e-6)
        XCTAssertEqual(decodedA[0].longitude, 13.40, accuracy: 1e-6)
        XCTAssertEqual(decodedA[1].latitude, 52.51, accuracy: 1e-6)
        XCTAssertEqual(decodedA[1].longitude, 13.41, accuracy: 1e-6)
        // Path A's decoded points must not contain Path B's far-away
        // (negative-longitude) coordinates.
        for c in decodedA {
            XCTAssertGreaterThan(c.longitude, 0)
            XCTAssertGreaterThan(c.latitude, 50)
        }

        let decodedB = Array(try reader.coordinateSequence(forPathId: pathB.id))
        XCTAssertEqual(decodedB.count, 3)
        for c in decodedB {
            XCTAssertLessThan(c.longitude, 0)
            XCTAssertLessThan(c.latitude, 41)
        }
    }

    // MARK: - 50k smoke through the reader

    func testFiftyKVisitImportDayListReadStaysSummaryOnly() throws {
        // Build the same synthetic 50k-visit corpus as
        // `GoogleTimelineStoreImporterTests.testFiftyKEntriesSmokeStaysBounded`,
        // import it, then verify that the *reader's* day-list view is a pure
        // summary read: it returns `summary.dayCount` days, each with a
        // plausible `visitCount`, and we never ask for path coordinates.
        var json = "["
        json.reserveCapacity(50_000 * 200)
        let cal = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2026; components.month = 5; components.day = 1
        components.hour = 8
        components.timeZone = TimeZone(secondsFromGMT: 0)
        let base = cal.date(from: components)!
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        var dayKeys = Set<String>()
        for i in 0..<50_000 {
            let dayOffset = (i / 1_000) % 50
            let date = cal.date(byAdding: .day, value: dayOffset, to: base)!
            let iso = isoFormatter.string(from: date)
            dayKeys.insert(String(iso.prefix(10)))
            if i > 0 { json.append(",") }
            json.append("""
            {"startTime":"\(iso)","endTime":"\(iso)",\
            "visit":{"topCandidate":{"placeLocation":"geo:52.5,13.4","semanticType":"X","placeID":"p\(i)","probability":0.5}}}
            """)
        }
        json.append("]")

        let store = try makeStore("smoke-reader.sqlite")
        defer { store.close() }
        let summary = try GoogleTimelineStoreImporter.importFromData(
            Data(json.utf8), sourceFilename: "smoke.json", store: store)

        let reader = LocalTimelineStoreReader(store: store)
        let days = try reader.days(forImportId: summary.importId)
        XCTAssertEqual(days.count, summary.dayCount)
        XCTAssertEqual(days.count, dayKeys.count)
        var totalVisits = 0
        for day in days {
            XCTAssertGreaterThan(day.visitCount, 0)
            totalVisits += day.visitCount
            // Bounded-read guarantee: routeCount is part of the day summary
            // (no path materialisation needed) — for visit-only data: 0.
            XCTAssertEqual(day.routeCount, 0)
        }
        XCTAssertEqual(totalVisits, 50_000)
        // We deliberately do NOT call `reader.coordinateSequence(...)`.
    }

    // MARK: - Reader imports list avoids decoding paths

    func testReaderImportsListAvoidsDecodingPaths() throws {
        let store = try makeStore()
        defer { store.close() }
        let writer = try LocalTimelineImportWriter(store: store, source: "agg.json")
        try writer.addPath(.init(startTime: "2026-05-08T08:00:00Z",
                                 distanceM: 100,
                                 flatCoordinates: [52.5, 13.4, 52.51, 13.41]))
        try writer.addPath(.init(startTime: "2026-05-08T09:00:00Z",
                                 distanceM: 250,
                                 flatCoordinates: [52.5, 13.4, 52.52, 13.42, 52.53, 13.43]))
        try writer.addPath(.init(startTime: "2026-05-09T08:00:00Z",
                                 distanceM: 500,
                                 flatCoordinates: [52.5, 13.4, 52.55, 13.45]))
        let summary = try writer.finalize()

        let reader = LocalTimelineStoreReader(store: store)
        let imports = try reader.imports()
        XCTAssertEqual(imports.count, 1)
        XCTAssertEqual(imports[0].id, summary.importId)

        // These aggregates come from the `days` table summary columns
        // (route_count, distance_m). Verifying the values match the writer's
        // pre-summed aggregates demonstrates that no path-iterator pass was
        // necessary to produce them.
        XCTAssertEqual(try reader.totalRouteCount(forImportId: summary.importId), 3)
        XCTAssertEqual(try reader.totalDistance(forImportId: summary.importId),
                       850, accuracy: 1e-6)
        XCTAssertEqual(try reader.totalVisitCount(forImportId: summary.importId), 0)
        // Once again: no `coordinateSequence` call required to produce the
        // reader's import-level aggregates.
    }
}
