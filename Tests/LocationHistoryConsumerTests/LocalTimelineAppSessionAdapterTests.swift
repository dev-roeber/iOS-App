import Foundation
import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Phase-6 — Adapter projiziert Store-Daten bounded.
/// Verifiziert: keine Geometrie in DayDetail, explizite Coord-Decode
/// liefert die geschriebenen Punkte, Day-Summaries kommen aus Store.
final class LocalTimelineAppSessionAdapterTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTAdapter-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    private struct Fixture {
        let store: LocalTimelineStore
        let reader: LocalTimelineStoreReader
        let session: LocalTimelineSession
        let adapter: LocalTimelineAppSessionAdapter
    }

    private func makeFixture() throws -> Fixture {
        let url = tempDir.appendingPathComponent("store.sqlite")
        let store = try LocalTimelineStore(url: url)
        let writer = try LocalTimelineImportWriter(store: store, source: "fixture.json")
        try writer.addVisit(.init(startTime: "2024-01-01T08:00:00Z",
                                  endTime: "2024-01-01T09:00:00Z",
                                  latitude: 48.0, longitude: 11.0,
                                  name: "Home"))
        try writer.addActivity(.init(startTime: "2024-01-01T10:00:00Z",
                                     endTime: "2024-01-01T11:00:00Z",
                                     mode: "walking",
                                     distanceM: 100,
                                     startLat: 48.0, startLon: 11.0,
                                     endLat: 48.001, endLon: 11.001))
        try writer.addPath(.init(startTime: "2024-01-01T10:00:00Z",
                                 endTime: "2024-01-01T10:30:00Z",
                                 mode: "cycling",
                                 distanceM: 500,
                                 flatCoordinates: [48.0, 11.0, 48.001, 11.001, 48.002, 11.002]))
        let summary = try writer.finalize()
        let reader = LocalTimelineStoreReader(store: store)
        let session = try LocalTimelineSession.make(reader: reader,
                                                    importID: summary.importId,
                                                    storeURL: url)
        let adapter = LocalTimelineAppSessionAdapter(reader: reader, session: session)
        return Fixture(store: store, reader: reader, session: session, adapter: adapter)
    }

    func testDaySummariesContainAllDays() throws {
        let f = try makeFixture(); defer { f.store.close() }
        let summaries = try f.adapter.daySummaries()
        XCTAssertEqual(summaries.count, 1)
        let day = try XCTUnwrap(summaries.first)
        XCTAssertEqual(day.date, "2024-01-01")
        // Activity erzeugt zusätzlich einen abgeleiteten Pfad → 2 routes.
        XCTAssertEqual(day.routeCount, 2)
        XCTAssertEqual(day.visitCount, 1)
        XCTAssertEqual(day.distanceM, 600, accuracy: 0.001) // 100 + 500
    }

    func testDayDetailDoesNotMaterializeGeometry() throws {
        let f = try makeFixture(); defer { f.store.close() }
        let dayId = try XCTUnwrap(f.adapter.daySummaries().first?.dayId)
        let detail = try XCTUnwrap(f.adapter.dayDetail(dayId: dayId))

        XCTAssertEqual(detail.day.date, "2024-01-01")
        XCTAssertEqual(detail.visits.count, 1)
        XCTAssertEqual(detail.activities.count, 1)
        // 1 expliziter Pfad + 1 von Activity abgeleitet.
        XCTAssertEqual(detail.paths.count, 2)
        // Genau ein Pfad mit den 3 expliziten Punkten.
        XCTAssertNotNil(detail.paths.first { $0.pointCount == 3 })
        // Sanity: PathMetadataView hat überhaupt kein Coord-Feld.
        let mirror = Mirror(reflecting: detail.paths.first!)
        let labels = mirror.children.compactMap { $0.label }
        XCTAssertFalse(labels.contains("flatCoordinates"))
        XCTAssertFalse(labels.contains("coordinates"))
    }

    func testCoordinatesAreDecodedExplicitlyOnDemand() throws {
        let f = try makeFixture(); defer { f.store.close() }
        let dayId = try XCTUnwrap(f.adapter.daySummaries().first?.dayId)
        let detail = try XCTUnwrap(f.adapter.dayDetail(dayId: dayId))
        let pathId = try XCTUnwrap(detail.paths.first { $0.pointCount == 3 }?.id)

        let coords = try f.adapter.coordinates(forPathId: pathId)
        XCTAssertEqual(coords.count, 3)
        XCTAssertEqual(coords[0].lat, 48.0, accuracy: 0.0001)
        XCTAssertEqual(coords[0].lon, 11.0, accuracy: 0.0001)
        XCTAssertEqual(coords[2].lat, 48.002, accuracy: 0.0001)
    }

    func testDayDetailReturnsNilForUnknownId() throws {
        let f = try makeFixture(); defer { f.store.close() }
        XCTAssertNil(try f.adapter.dayDetail(dayId: "does-not-exist"))
    }
}
