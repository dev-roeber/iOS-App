import Foundation
import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Phase-6 — Session-Modell + `make(reader:importID:storeURL:)`-Konstruktion.
/// Verifiziert: keine Geometrie, korrekte Counter, Fehlerpfad bei
/// unbekanntem Import.
final class LocalTimelineSessionTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTSession-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    private func makeStoreFixture() throws -> (LocalTimelineStore, LocalTimelineStoreReader, URL, String) {
        let storeURL = tempDir.appendingPathComponent("store.sqlite")
        let store = try LocalTimelineStore(url: storeURL)
        let writer = try LocalTimelineImportWriter(store: store, source: "fixture.json")

        try writer.addVisit(.init(startTime: "2024-01-01T08:00:00Z",
                                  endTime: "2024-01-01T09:00:00Z",
                                  latitude: 48.0,
                                  longitude: 11.0,
                                  name: "Home"))
        try writer.addActivity(.init(startTime: "2024-01-01T10:00:00Z",
                                     endTime: "2024-01-01T11:00:00Z",
                                     mode: "walking",
                                     distanceM: 1234.0,
                                     startLat: 48.0,
                                     startLon: 11.0,
                                     endLat: 48.01,
                                     endLon: 11.01))
        try writer.addPath(.init(startTime: "2024-01-02T10:00:00Z",
                                 endTime: "2024-01-02T10:30:00Z",
                                 mode: "cycling",
                                 distanceM: 500.0,
                                 flatCoordinates: [48.0, 11.0, 48.001, 11.001, 48.002, 11.002]))
        let summary = try writer.finalize()

        let reader = LocalTimelineStoreReader(store: store)
        return (store, reader, storeURL, summary.importId)
    }

    func testMakeBuildsSummaryWithoutMaterializingGeometry() throws {
        let (store, reader, url, importId) = try makeStoreFixture()
        defer { store.close() }

        let session = try LocalTimelineSession.make(reader: reader,
                                                    importID: importId,
                                                    storeURL: url)

        XCTAssertEqual(session.importID, importId)
        XCTAssertEqual(session.sourceFilename, "fixture.json")
        XCTAssertEqual(session.storeURL, url)
        XCTAssertEqual(session.summary.dayCount, 2)
        // Activity erzeugt zusätzlich einen abgeleiteten Pfad (start→end),
        // daher 2 Pfade insgesamt (1 abgeleitet + 1 expliziter Path auf Tag 2).
        XCTAssertEqual(session.summary.pathCount, 2)
        XCTAssertEqual(session.summary.visitCount, 1)
        XCTAssertEqual(session.summary.activityCount, 1)
        XCTAssertEqual(session.summary.totalDistanceM, 1734.0, accuracy: 0.001)
        XCTAssertEqual(session.summary.dateRange, "2024-01-01"..."2024-01-02")
    }

    func testMakeThrowsForUnknownImport() throws {
        let (store, reader, url, _) = try makeStoreFixture()
        defer { store.close() }

        XCTAssertThrowsError(try LocalTimelineSession.make(reader: reader,
                                                           importID: "does-not-exist",
                                                           storeURL: url)) { error in
            guard case let LocalTimelineSessionError.unknownImport(id) = error else {
                XCTFail("unexpected error \(error)"); return
            }
            XCTAssertEqual(id, "does-not-exist")
        }
    }

    func testEmptySummaryEqualityIsFieldwise() {
        let s1 = LocalTimelineSession(
            importID: "x", sourceFilename: "y", storeURL: URL(fileURLWithPath: "/tmp/a"),
            createdAt: "t", importedAt: "t",
            summary: .init(dayCount: 0, pathCount: 0, visitCount: 0,
                           activityCount: 0, totalDistanceM: 0, dateRange: nil))
        let s2 = LocalTimelineSession(
            importID: "x", sourceFilename: "y", storeURL: URL(fileURLWithPath: "/tmp/a"),
            createdAt: "t", importedAt: "t",
            summary: .init(dayCount: 0, pathCount: 0, visitCount: 0,
                           activityCount: 0, totalDistanceM: 0, dateRange: nil))
        XCTAssertEqual(s1, s2)
    }
}
