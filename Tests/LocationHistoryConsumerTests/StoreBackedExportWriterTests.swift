import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-5 — End-to-end coverage for `StoreBackedExportWriter`. Every test
/// uses a real on-disk SQLite store wired up via `LocalTimelineImportWriter`,
/// so coordinates round-trip through `coord_blob` and the
/// `CoordBlobIterator` path.
final class StoreBackedExportWriterTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTSExport-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    // MARK: - Fixtures

    private struct Fixture {
        let store: LocalTimelineStore
        let reader: LocalTimelineStoreReader
        let locations: LocalTimelineStorageLocations
        let writer: StoreBackedExportWriter
        let importId: String
    }

    private func makeFixture(days: [DayFixture]) throws -> Fixture {
        let storeURL = tempDir.appendingPathComponent("store.sqlite")
        let store = try LocalTimelineStore(url: storeURL)
        let importer = try LocalTimelineImportWriter(store: store, source: "fixture.json")
        for day in days {
            for v in day.visits {
                try importer.addVisit(.init(
                    startTime: "\(day.date)T\(v.time)Z",
                    latitude: v.lat, longitude: v.lon, name: v.name))
            }
            for a in day.activities {
                try importer.addActivity(.init(
                    startTime: "\(day.date)T\(a.time)Z",
                    mode: a.mode, distanceM: a.distance,
                    startLat: a.startLat, startLon: a.startLon,
                    endLat: a.endLat, endLon: a.endLon),
                    includeStartEndPath: false)
            }
            for p in day.paths {
                try importer.addPath(.init(
                    startTime: "\(day.date)T\(p.time)Z",
                    mode: p.mode, distanceM: p.distance,
                    flatCoordinates: p.flat))
            }
        }
        _ = try importer.finalize()
        let reader = LocalTimelineStoreReader(store: store)
        let locations = LocalTimelineStorageLocations.temporary(under: tempDir)
        try locations.ensureDirectoriesExist()
        let writer = StoreBackedExportWriter(reader: reader, locations: locations)
        let importId = try XCTUnwrap(reader.latestImport()?.id)
        return Fixture(store: store, reader: reader, locations: locations,
                       writer: writer, importId: importId)
    }

    private struct DayFixture {
        let date: String
        var visits: [VisitFixture] = []
        var activities: [ActivityFixture] = []
        var paths: [PathFixture] = []
    }
    private struct VisitFixture {
        let time: String; let lat: Double; let lon: Double; let name: String
    }
    private struct ActivityFixture {
        let time: String; let mode: String; let distance: Double
        let startLat: Double; let startLon: Double
        let endLat: Double; let endLon: Double
    }
    private struct PathFixture {
        let time: String; let mode: String; let distance: Double; let flat: [Double]
    }

    private func defaultFixture() throws -> Fixture {
        try makeFixture(days: [
            DayFixture(
                date: "2024-01-01",
                visits: [.init(time: "08:00:00", lat: 52.5, lon: 13.4, name: "Home")],
                activities: [.init(time: "09:00:00", mode: "walking", distance: 1234.5,
                                   startLat: 52.5, startLon: 13.4,
                                   endLat: 52.51, endLon: 13.41)],
                paths: [.init(time: "09:00:00", mode: "walking", distance: 1234.5,
                              flat: [52.5, 13.4, 52.501, 13.401, 52.502, 13.402])]
            ),
            DayFixture(
                date: "2024-01-02",
                visits: [],
                activities: [],
                paths: [.init(time: "10:00:00", mode: "cycling", distance: 5000,
                              flat: [40.0, -74.0, 40.001, -74.001])]
            )
        ])
    }

    private func read(_ url: URL) throws -> String {
        String(data: try Data(contentsOf: url), encoding: .utf8) ?? ""
    }

    // MARK: - Format basics

    func testGPXContainsTrkptFromCoordBlob() throws {
        let f = try defaultFixture()
        defer { f.store.close() }
        let r = try f.writer.export(
            selection: .init(importID: f.importId), format: .gpx)
        let s = try read(r.outputURL)
        XCTAssertTrue(s.contains("<gpx"))
        XCTAssertTrue(s.contains("<trkpt"))
        XCTAssertTrue(s.contains("lat=\"52.5\""))
        XCTAssertTrue(s.contains("lon=\"13.4\""))
        XCTAssertTrue(s.contains("</gpx>"))
    }

    func testKMLContainsLineString() throws {
        let f = try defaultFixture()
        defer { f.store.close() }
        let r = try f.writer.export(
            selection: .init(importID: f.importId), format: .kml)
        let s = try read(r.outputURL)
        XCTAssertTrue(s.contains("<kml"))
        XCTAssertTrue(s.contains("<LineString>"))
        XCTAssertTrue(s.contains("<coordinates>"))
        XCTAssertTrue(s.contains("</kml>"))
    }

    func testGeoJSONContainsFeatureCollectionAndLineString() throws {
        let f = try defaultFixture()
        defer { f.store.close() }
        let r = try f.writer.export(
            selection: .init(importID: f.importId), format: .geoJSON)
        let s = try read(r.outputURL)
        XCTAssertTrue(s.hasPrefix("{\"type\":\"FeatureCollection\""))
        XCTAssertTrue(s.contains("\"LineString\""))
        // Validate JSON parses cleanly.
        let parsed = try JSONSerialization.jsonObject(
            with: try Data(contentsOf: r.outputURL))
        XCTAssertNotNil(parsed)
    }

    func testCSVContainsHeaderAndCoordinateRows() throws {
        let f = try defaultFixture()
        defer { f.store.close() }
        let r = try f.writer.export(
            selection: .init(importID: f.importId), format: .csv)
        let s = try read(r.outputURL)
        let lines = s.split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(lines.first, "type,date,time,lat,lon,name,mode,distance_m")
        XCTAssertTrue(s.contains("path,2024-01-01"))
        XCTAssertTrue(s.contains("visit,2024-01-01"))
        XCTAssertTrue(s.contains("activity,2024-01-01"))
    }

    // MARK: - Counters

    func testResultCountersAreAccurate() throws {
        let f = try defaultFixture()
        defer { f.store.close() }
        let r = try f.writer.export(
            selection: .init(importID: f.importId), format: .csv)
        XCTAssertEqual(r.dayCount, 2)
        XCTAssertEqual(r.pathCount, 2)
        XCTAssertEqual(r.visitCount, 1)
        XCTAssertEqual(r.activityCount, 1)
        XCTAssertEqual(r.pointCount, 5)   // 3 + 2 path points
        XCTAssertGreaterThan(r.bytesWritten, 0)
    }

    // MARK: - Selection: dayIds

    func testDayIdSelectionExportsOnlyMatchingDay() throws {
        let f = try defaultFixture()
        defer { f.store.close() }
        let days = try f.reader.days(forImportId: f.importId)
        let firstDayId = days.first { $0.date == "2024-01-01" }!.id
        let r = try f.writer.export(
            selection: .init(importID: f.importId, dayIds: [firstDayId]),
            format: .csv)
        XCTAssertEqual(r.dayCount, 1)
        let s = try read(r.outputURL)
        XCTAssertTrue(s.contains("2024-01-01"))
        XCTAssertFalse(s.contains("2024-01-02"))
    }

    // MARK: - Selection: dateRange

    func testDateRangeSelectionExportsOnlyMatchingDays() throws {
        let f = try defaultFixture()
        defer { f.store.close() }
        let r = try f.writer.export(
            selection: .init(importID: f.importId,
                             dateRange: "2024-01-02"..."2024-01-31"),
            format: .csv)
        XCTAssertEqual(r.dayCount, 1)
        let s = try read(r.outputURL)
        XCTAssertTrue(s.contains("2024-01-02"))
        XCTAssertFalse(s.contains("2024-01-01"))
    }

    // MARK: - File location

    func testExportFileLandsUnderExportStaging() throws {
        let f = try defaultFixture()
        defer { f.store.close() }
        let r = try f.writer.export(
            selection: .init(importID: f.importId), format: .gpx)
        XCTAssertTrue(r.outputURL.path.hasPrefix(f.locations.exportStagingRoot.path))
        XCTAssertEqual(r.outputURL.lastPathComponent, "export.gpx")
    }

    // MARK: - Errors

    func testUnknownImportThrows() throws {
        let f = try defaultFixture()
        defer { f.store.close() }
        XCTAssertThrowsError(try f.writer.export(
            selection: .init(importID: "no-such-id"), format: .gpx)) { err in
            XCTAssertTrue("\(err)".contains("unknownImport"))
        }
    }

    func testEmptySelectionThrows() throws {
        let f = try defaultFixture()
        defer { f.store.close() }
        XCTAssertThrowsError(try f.writer.export(
            selection: .init(importID: f.importId, dayIds: ["does-not-exist"]),
            format: .gpx)) { err in
            XCTAssertTrue("\(err)".contains("emptySelection"))
        }
    }

    // MARK: - Escaping

    func testCSVEscapesQuotesAndCommas() throws {
        let f = try makeFixture(days: [
            DayFixture(
                date: "2024-03-03",
                visits: [.init(time: "10:00:00", lat: 1.0, lon: 2.0,
                               name: "Home, \"sweet\"\nhome")],
                paths: [.init(time: "10:00:00", mode: "walking", distance: 0,
                              flat: [1.0, 2.0, 1.001, 2.001])]
            )
        ])
        defer { f.store.close() }
        let r = try f.writer.export(
            selection: .init(importID: f.importId), format: .csv)
        let s = try read(r.outputURL)
        // Comma + quote → field is quoted, embedded quote doubled.
        XCTAssertTrue(s.contains("\"Home, \"\"sweet\"\"\nhome\""))
    }

    func testGeoJSONEscapesProblematicVisitName() throws {
        let f = try makeFixture(days: [
            DayFixture(
                date: "2024-03-03",
                visits: [.init(time: "10:00:00", lat: 1.0, lon: 2.0,
                               name: "Quote \" backslash \\ newline\n")]
            )
        ])
        defer { f.store.close() }
        let r = try f.writer.export(
            selection: .init(importID: f.importId), format: .geoJSON)
        // Must be valid JSON.
        let obj = try JSONSerialization.jsonObject(
            with: try Data(contentsOf: r.outputURL)) as? [String: Any]
        let features = obj?["features"] as? [[String: Any]] ?? []
        let visit = features.first { ($0["properties"] as? [String: Any])?["kind"] as? String == "visit" }
        let props = visit?["properties"] as? [String: Any]
        XCTAssertEqual(props?["name"] as? String, "Quote \" backslash \\ newline\n")
    }

    func testGPXXMLEscapesAmpersandInName() throws {
        let f = try makeFixture(days: [
            DayFixture(
                date: "2024-03-03",
                visits: [.init(time: "10:00:00", lat: 1.0, lon: 2.0, name: "A & B <X>")]
            )
        ])
        defer { f.store.close() }
        let r = try f.writer.export(
            selection: .init(importID: f.importId), format: .gpx)
        let s = try read(r.outputURL)
        XCTAssertTrue(s.contains("A &amp; B &lt;X&gt;"))
        XCTAssertFalse(s.contains("<name>A & B <X></name>"))
    }

    // MARK: - Visits include flag

    func testIncludeVisitsFalseDropsVisitsButKeepsPaths() throws {
        let f = try defaultFixture()
        defer { f.store.close() }
        let r = try f.writer.export(
            selection: .init(importID: f.importId, includeVisits: false),
            format: .csv)
        XCTAssertEqual(r.visitCount, 0)
        XCTAssertGreaterThan(r.pathCount, 0)
        let s = try read(r.outputURL)
        XCTAssertFalse(s.contains("visit,"))
    }

    // MARK: - Smoke: many path points

    func testManyPathPointsExportSmoke() throws {
        var flat: [Double] = []
        for i in 0..<2_000 {
            flat.append(50.0 + Double(i) * 1e-5)
            flat.append(10.0 + Double(i) * 1e-5)
        }
        let f = try makeFixture(days: [
            DayFixture(
                date: "2024-04-01",
                paths: [.init(time: "08:00:00", mode: "walking", distance: 0, flat: flat)]
            )
        ])
        defer { f.store.close() }
        let r = try f.writer.export(
            selection: .init(importID: f.importId), format: .geoJSON)
        XCTAssertEqual(r.pointCount, 2_000)
        XCTAssertGreaterThan(r.bytesWritten, 30_000)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(
            with: try Data(contentsOf: r.outputURL)))
    }
}
