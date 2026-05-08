import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Lifecycle / migration coverage for Phase-2 schema additions
/// (`visits`, `activities`) and `LocalTimelineStore.deleteAll()`.
/// All cases run on Linux against the system `libsqlite3` via `CSQLite`.
final class LocalTimelineStoreLifecycleTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTSLifecycle-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    // MARK: - Schema version

    func testFreshStoreReportsVersion2() throws {
        let store = try LocalTimelineStore(url: tempDir.appendingPathComponent("v2.sqlite"))
        defer { store.close() }
        XCTAssertEqual(LocalTimelineStoreSchema.userVersion, 2)
        XCTAssertEqual(try store.userVersion(), 2)
    }

    /// Simulates a v1 database (no `visits`/`activities` tables, user_version=1)
    /// being opened with the Phase-2 bootstrap. The new tables must appear,
    /// existing rows must survive, and `user_version` must move to 2.
    func testMigrationFromSimulatedV1KeepsExistingRowsAndAddsNewTables() throws {
        let url = tempDir.appendingPathComponent("v1-migrate.sqlite")

        // Step 1: build a v1-like DB by hand — only imports/days/paths,
        // user_version=1, then close.
        do {
            let store = try LocalTimelineStore(url: url)
            try store.execRaw("PRAGMA user_version = 1;")
            // Drop the v2-only tables so the file truly looks like v1.
            try store.execRaw("DROP TABLE IF EXISTS visits;")
            try store.execRaw("DROP TABLE IF EXISTS activities;")
            try store.insertImport(.init(id: "imp-v1", sourceFilename: "v1.json",
                                         createdAt: "2026-05-08T00:00:00Z"))
            try store.insertDay(.init(id: "day-v1", importId: "imp-v1", date: "2026-05-08",
                                      routeCount: 0, visitCount: 0, distanceM: 0))
            XCTAssertEqual(try store.userVersion(), 1)
            store.close()
        }

        // Step 2: reopen — schema bootstrap should add visits/activities and
        // bump user_version to 2 without touching existing rows.
        let reopened = try LocalTimelineStore(url: url)
        defer { reopened.close() }
        XCTAssertEqual(try reopened.userVersion(), 2)
        XCTAssertEqual(try reopened.countImports(), 1)
        XCTAssertEqual(try reopened.countDays(), 1)
        XCTAssertEqual(try reopened.countVisits(), 0)
        XCTAssertEqual(try reopened.countActivities(), 0)

        // New tables must be writable.
        try reopened.insertVisit(.init(
            id: "v1", dayId: "day-v1", startTime: "2026-05-08T08:00:00Z",
            endTime: nil, latitude: 52.5, longitude: 13.4,
            name: nil, semanticType: "RESTAURANT", placeId: "p1",
            probability: 0.9))
        XCTAssertEqual(try reopened.countVisits(), 1)
    }

    // MARK: - deleteAll

    func testDeleteAllOnEmptyStoreSucceeds() throws {
        let store = try LocalTimelineStore(url: tempDir.appendingPathComponent("empty.sqlite"))
        defer { store.close() }
        XCTAssertNoThrow(try store.deleteAll())
        XCTAssertNoThrow(try store.deleteAll()) // idempotent
        XCTAssertEqual(try store.countImports(), 0)
        XCTAssertEqual(try store.countDays(), 0)
        XCTAssertEqual(try store.countPaths(), 0)
        XCTAssertEqual(try store.countVisits(), 0)
        XCTAssertEqual(try store.countActivities(), 0)
    }

    func testDeleteAllAfterImportClearsEverything() throws {
        let store = try LocalTimelineStore(url: tempDir.appendingPathComponent("full.sqlite"))
        defer { store.close() }
        let writer = try LocalTimelineImportWriter(store: store, source: "fixture.json")
        try writer.addVisit(.init(startTime: "2026-05-08T08:00:00Z",
                                  latitude: 52.5, longitude: 13.4,
                                  semanticType: "RESTAURANT"))
        try writer.addActivity(.init(startTime: "2026-05-08T09:00:00Z",
                                     endTime: "2026-05-08T09:30:00Z",
                                     mode: "WALKING", distanceM: 420,
                                     startLat: 52.50, startLon: 13.40,
                                     endLat: 52.51, endLon: 13.41,
                                     rawType: "WALKING"))
        try writer.finalize()

        XCTAssertGreaterThan(try store.countImports(), 0)
        XCTAssertGreaterThan(try store.countVisits(), 0)
        XCTAssertGreaterThan(try store.countActivities(), 0)

        try store.deleteAll()
        XCTAssertEqual(try store.countImports(), 0)
        XCTAssertEqual(try store.countDays(), 0)
        XCTAssertEqual(try store.countPaths(), 0)
        XCTAssertEqual(try store.countVisits(), 0)
        XCTAssertEqual(try store.countActivities(), 0)
    }

    // MARK: - visit / activity round-trip

    func testVisitRoundTrip() throws {
        let store = try LocalTimelineStore(url: tempDir.appendingPathComponent("visit.sqlite"))
        defer { store.close() }
        let writer = try LocalTimelineImportWriter(store: store, source: "v.json")
        try writer.addVisit(.init(
            startTime: "2026-05-08T08:30:00Z", endTime: "2026-05-08T09:00:00Z",
            latitude: 52.520008, longitude: 13.404954,
            name: "Berlin Hbf", semanticType: "TRAIN_STATION",
            placeId: "ChIJB-_W2hQHqEcRVS5R0t_9z2I", probability: 0.87))
        let summary = try writer.finalize()

        XCTAssertEqual(summary.dayCount, 1)
        XCTAssertEqual(try store.countVisits(), 1)
        let dayRows = try store.days(forImportId: summary.importId)
        XCTAssertEqual(dayRows.count, 1)
        let day = dayRows[0]
        XCTAssertEqual(day.visitCount, 1)
        let visits = try store.visits(forDayId: day.id)
        XCTAssertEqual(visits.count, 1)
        XCTAssertEqual(try XCTUnwrap(visits[0].latitude), 52.520008, accuracy: 1e-6)
        XCTAssertEqual(visits[0].semanticType, "TRAIN_STATION")
        XCTAssertEqual(visits[0].placeId, "ChIJB-_W2hQHqEcRVS5R0t_9z2I")
        XCTAssertEqual(try XCTUnwrap(visits[0].probability), 0.87, accuracy: 1e-9)
    }

    func testActivityRoundTripAndStartEndPath() throws {
        let store = try LocalTimelineStore(url: tempDir.appendingPathComponent("act.sqlite"))
        defer { store.close() }
        let writer = try LocalTimelineImportWriter(store: store, source: "a.json")
        try writer.addActivity(.init(
            startTime: "2026-05-08T10:00:00Z", endTime: "2026-05-08T10:45:00Z",
            mode: "CYCLING", distanceM: 4_321.0,
            startLat: 52.5200, startLon: 13.4050,
            endLat: 52.5305, endLon: 13.4180,
            probability: 0.92, rawType: "CYCLING"))
        let summary = try writer.finalize()

        let day = try store.days(forImportId: summary.importId)[0]
        XCTAssertEqual(day.routeCount, 1, "activity start/end must produce one path")
        XCTAssertEqual(day.distanceM, 4_321.0, accuracy: 1e-6)

        let activities = try store.activities(forDayId: day.id)
        XCTAssertEqual(activities.count, 1)
        XCTAssertEqual(activities[0].mode, "CYCLING")
        XCTAssertEqual(activities[0].distanceM, 4_321.0)
        XCTAssertEqual(try XCTUnwrap(activities[0].startLat), 52.52, accuracy: 1e-5)

        let paths = try store.paths(forDayId: day.id)
        XCTAssertEqual(paths.count, 1)
        XCTAssertEqual(paths[0].pointCount, 2)
        let decoded = try CoordBlobIterator.decodeAll(paths[0].coordBlob)
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].latitude, 52.52, accuracy: 1e-5)
        XCTAssertEqual(decoded[1].latitude, 52.5305, accuracy: 1e-5)
    }
}
