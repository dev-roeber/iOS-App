import Foundation
import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Phase-8A — die zwei neuen bbox-Indizes existieren in fresh-stores
/// **und** in v2-Stores nach Re-Open (additive Migration).
/// `userVersion` bleibt bei `2`, weil rein additive Indizes keinen
/// semantischen Schema-Schritt darstellen. RTree (`path_bounds` virtuelle
/// Tabelle) bleibt Phase 8B/9.
final class LocalTimelineMapSchemaIndexTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTMapSchema-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    func testFreshStoreHasBboxIndices() throws {
        let store = try LocalTimelineStore(url: tempDir.appendingPathComponent("fresh.sqlite"))
        defer { store.close() }
        let names = Set(try store.indexNames(forTable: "paths"))
        XCTAssertTrue(names.contains("idx_paths_bounds_minmax"), "missing idx_paths_bounds_minmax")
        XCTAssertTrue(names.contains("idx_paths_day_bounds"),    "missing idx_paths_day_bounds")
        XCTAssertTrue(names.contains("idx_paths_day_id"))
        XCTAssertTrue(names.contains("idx_paths_day_start"))
    }

    func testReopenedStoreGainsBboxIndicesAdditively() throws {
        let url = tempDir.appendingPathComponent("v2-old.sqlite")
        // 1) Erzeuge eine Store-DB, lasse die zwei neuen Indizes wieder fallen
        //    und schließe die DB. Danach hat die DB einen "alten v2"-Zustand
        //    ohne idx_paths_bounds_minmax / idx_paths_day_bounds.
        do {
            let store = try LocalTimelineStore(url: url)
            try store.execRaw("DROP INDEX IF EXISTS idx_paths_bounds_minmax;")
            try store.execRaw("DROP INDEX IF EXISTS idx_paths_day_bounds;")
            let pre = Set(try store.indexNames(forTable: "paths"))
            XCTAssertFalse(pre.contains("idx_paths_bounds_minmax"))
            XCTAssertFalse(pre.contains("idx_paths_day_bounds"))
            store.close()
        }
        // 2) Re-open: Bootstrap re-applied → Indizes wieder vorhanden,
        //    user_version bleibt 2.
        let reopened = try LocalTimelineStore(url: url)
        defer { reopened.close() }
        let names = Set(try reopened.indexNames(forTable: "paths"))
        XCTAssertTrue(names.contains("idx_paths_bounds_minmax"))
        XCTAssertTrue(names.contains("idx_paths_day_bounds"))
        XCTAssertEqual(try reopened.userVersion(), LocalTimelineStoreSchema.userVersion)
    }
}
