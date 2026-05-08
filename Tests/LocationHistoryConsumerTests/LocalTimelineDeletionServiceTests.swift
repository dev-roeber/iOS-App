import Foundation
import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Phase-6 — Deletion-Service ist ein dünner Wrapper um den Lifecycle-Manager.
/// Verifiziert: idempotenter Aufruf, Wipe entfernt geöffneten Store sauber.
final class LocalTimelineDeletionServiceTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTDelete-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    func testDeleteAllOnEmptyLocationsIsIdempotent() throws {
        let locations = LocalTimelineStorageLocations.temporary(under: tempDir)
        try locations.ensureDirectoriesExist()
        let lifecycle = LocalTimelineStoreLifecycle(locations: locations)
        let service = LocalTimelineDeletionService(lifecycle: lifecycle)

        let r1 = try service.deleteAll()
        XCTAssertNoThrow(r1)
        let r2 = try service.deleteAll()
        XCTAssertNoThrow(r2)
        // After two deletions the report should be free of errors.
        XCTAssertNil(r2.rowWipeError)
    }

    func testDeleteAllRemovesPopulatedStore() throws {
        let locations = LocalTimelineStorageLocations.temporary(under: tempDir)
        try locations.ensureDirectoriesExist()

        let store = try LocalTimelineStore(url: locations.databaseFileURL)
        let writer = try LocalTimelineImportWriter(store: store, source: "x.json")
        try writer.addVisit(.init(startTime: "2024-01-01T08:00:00Z",
                                  latitude: 48, longitude: 11, name: "H"))
        _ = try writer.finalize()

        let lifecycle = LocalTimelineStoreLifecycle(locations: locations)
        let service = LocalTimelineDeletionService(lifecycle: lifecycle)

        let report = try service.deleteAll(openStore: store)
        XCTAssertTrue(report.didWipeRowsViaStore || !report.removedDBFiles.isEmpty,
                      "expected either row-wipe or file removal, got \(report)")
    }
}
