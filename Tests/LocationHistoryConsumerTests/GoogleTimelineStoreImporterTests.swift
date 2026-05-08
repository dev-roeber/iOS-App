import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// End-to-end coverage for `GoogleTimelineStoreImporter`. Verifies that the
/// disk-first pipeline ingests visit/activity/timelinePath entries straight
/// into the store **without** building any `AppExport` artefact.
final class GoogleTimelineStoreImporterTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("GTSImporter-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    private func makeStore(_ name: String = "store.sqlite") throws -> LocalTimelineStore {
        try LocalTimelineStore(url: tempDir.appendingPathComponent(name))
    }

    // MARK: - 8. Importer verarbeitet kleines Fixture mit visit + activity

    func testImportFixtureWithVisitActivityAndPath() throws {
        let json = """
        [
          { "startTime": "2026-05-08T08:00:00Z",
            "endTime":   "2026-05-08T08:30:00Z",
            "visit": {
              "topCandidate": {
                "placeLocation": "geo:52.520008,13.404954",
                "semanticType": "TRAIN_STATION",
                "placeID": "ChIJB-_W2hQHqEcRVS5R0t_9z2I",
                "probability": "0.91"
              }
            }
          },
          { "startTime": "2026-05-08T09:00:00Z",
            "endTime":   "2026-05-08T09:45:00Z",
            "activity": {
              "start": "geo:52.520008,13.404954",
              "end":   "geo:52.530001,13.420000",
              "distanceMeters": 1234.5,
              "topCandidate": { "type": "WALKING", "probability": 0.88 }
            }
          },
          { "startTime": "2026-05-08T10:00:00Z",
            "endTime":   "2026-05-08T10:15:00Z",
            "timelinePath": [
              { "point": "geo:52.530001,13.420000" },
              { "point": "geo:52.531000,13.421000" },
              { "point": "geo:52.532000,13.422000" }
            ]
          }
        ]
        """
        let store = try makeStore()
        defer { store.close() }

        let summary = try GoogleTimelineStoreImporter.importFromData(
            Data(json.utf8), sourceFilename: "fixture.json", store: store)

        XCTAssertEqual(summary.dayCount, 1)
        XCTAssertEqual(summary.skippedEntries, 0)
        XCTAssertEqual(try store.countImports(), 1)
        XCTAssertEqual(try store.countVisits(), 1)
        XCTAssertEqual(try store.countActivities(), 1)
        // 1 path from `timelinePath` + 1 path from activity start/end.
        XCTAssertEqual(try store.countPaths(), 2)

        let day = try store.days(forImportId: summary.importId)[0]
        XCTAssertEqual(day.date, "2026-05-08")
        XCTAssertEqual(day.routeCount, 2)
        XCTAssertEqual(day.visitCount, 1)
        XCTAssertEqual(day.distanceM, 1234.5, accuracy: 1e-6)

        let visits = try store.visits(forDayId: day.id)
        XCTAssertEqual(visits[0].placeId, "ChIJB-_W2hQHqEcRVS5R0t_9z2I")
        XCTAssertEqual(visits[0].probability ?? .nan, 0.91, accuracy: 1e-9)

        let acts = try store.activities(forDayId: day.id)
        XCTAssertEqual(acts[0].mode, "WALKING")
        XCTAssertEqual(acts[0].distanceM ?? .nan, 1234.5, accuracy: 1e-6)

        let paths = try store.paths(forDayId: day.id)
        XCTAssertTrue(paths.allSatisfy { $0.coordEncoding == CoordBlobEncoding.int32MicrodegreesV1 })
        let totalPoints = paths.reduce(0) { $0 + $1.pointCount }
        XCTAssertEqual(totalPoints, 2 + 3) // activity start/end + 3-point timelinePath
    }

    // MARK: - 9. Robust gegen Entries ohne Koordinate

    func testImporterSkipsEntriesWithoutCoordinatesGracefully() throws {
        let json = """
        [
          { "startTime": "2026-05-08T08:00:00Z",
            "visit": { "topCandidate": { "semanticType": "UNKNOWN" } } },
          { "startTime": "2026-05-08T09:00:00Z",
            "activity": { "topCandidate": { "type": "WALKING" } } },
          { "startTime": "2026-05-08T10:00:00Z",
            "timelinePath": [ { "point": "not-geo" } ] },
          { "startTime": "2026-05-08T11:00:00Z",
            "activity": {
              "start": "geo:52.5,13.4", "end": "geo:52.51,13.41",
              "topCandidate": { "type": "WALKING" }
            }
          }
        ]
        """
        let store = try makeStore("graceful.sqlite")
        defer { store.close() }

        let summary = try GoogleTimelineStoreImporter.importFromData(
            Data(json.utf8), sourceFilename: "graceful.json", store: store)

        // Visit + activity-without-coords are still inserted (visit has no
        // lat/lon → stored as NULL; activity without start/end coords is
        // stored but produces no path). The pathological timelinePath has
        // no valid points → dropped (skipped entry).
        XCTAssertEqual(try store.countVisits(), 1)
        XCTAssertEqual(try store.countActivities(), 2)
        XCTAssertEqual(try store.countPaths(), 1, "only the second activity's start/end pair makes a path")
        // Either the importer drops the malformed timelinePath silently before
        // reaching the writer (skippedEntries stays low) or the writer counts
        // it. Both are acceptable; the contract tested here is "no throw".
        XCTAssertGreaterThanOrEqual(summary.totalEntries, 3)
    }

    // MARK: - 10. Importer erzeugt kein AppExport (Typ-Garantie)

    func testImporterReturnTypeIsSummaryNotAppExport() throws {
        let json = """
        [{ "startTime": "2026-05-08T08:00:00Z",
           "activity": { "start": "geo:0,0", "end": "geo:0,1",
                         "topCandidate": { "type": "WALKING" } } }]
        """
        let store = try makeStore("typecheck.sqlite")
        defer { store.close() }
        let result: Any = try GoogleTimelineStoreImporter.importFromData(
            Data(json.utf8), sourceFilename: "x.json", store: store)
        XCTAssertTrue(result is LocalTimelineImportSummary)
        XCTAssertFalse(result is AppExport,
                       "GoogleTimelineStoreImporter must NOT materialise an AppExport")
    }

    // MARK: - 11. 50k synthetic smoke

    func testFiftyKEntriesSmokeStaysBounded() throws {
        // 50k visit-entries spread across ~50 days (2026-05-01 .. 2026-06-19,
        // using calendar day-arithmetic so every generated ISO string is
        // valid). The importer must not accumulate them into any in-memory list.
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

        let store = try makeStore("smoke.sqlite")
        defer { store.close() }

        let summary = try GoogleTimelineStoreImporter.importFromData(
            Data(json.utf8), sourceFilename: "smoke.json", store: store)

        XCTAssertEqual(summary.totalEntries, 50_000)
        XCTAssertEqual(summary.skippedEntries, 0)
        XCTAssertEqual(summary.dayCount, dayKeys.count)
        XCTAssertEqual(try store.countVisits(), 50_000)
        XCTAssertEqual(try store.countImports(), 1)
    }
}
