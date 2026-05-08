import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Phase-10A-Folge — P1-C: WAL-Checkpoint API.
///
/// Linux-only Tests — kein Hardware-/Jetsam-Verhalten geprüft.
final class LocalTimelineStoreWALCheckpointTests: XCTestCase {

    private func makeStore() throws -> (LocalTimelineStore, URL) {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("lts-wal-\(UUID().uuidString).sqlite")
        let store = try LocalTimelineStore(url: tmp)
        return (store, tmp)
    }

    private func cleanup(_ url: URL) {
        for suffix in ["", "-wal", "-shm"] {
            let u = URL(fileURLWithPath: url.path + suffix)
            try? FileManager.default.removeItem(at: u)
        }
    }

    func testCheckpointTruncateOnEmptyStoreSucceeds() throws {
        let (store, url) = try makeStore()
        defer { store.close(); cleanup(url) }
        let info = try store.truncateWAL()
        XCTAssertGreaterThanOrEqual(info.framesInLog, -1)
        XCTAssertGreaterThanOrEqual(info.framesCheckpointed, -1)
    }

    func testCheckpointAfterInsertsSucceeds() throws {
        let (store, url) = try makeStore()
        defer { store.close(); cleanup(url) }
        let writer = try LocalTimelineImportWriter(store: store, source: "wal-insert.json")
        try writer.addVisit(.init(
            startTime: "2025-01-01T10:00:00Z",
            endTime: "2025-01-01T10:30:00Z",
            latitude: 52.5, longitude: 13.4
        ))
        _ = try writer.finalize()
        // finalize() ruft bereits intern bestEffortTruncateWAL auf —
        // ein zweiter expliziter Aufruf muss trotzdem succeeden.
        let info = try store.truncateWAL()
        XCTAssertGreaterThanOrEqual(info.framesInLog, -1)
    }

    func testCheckpointAfterDeleteAllSucceeds() throws {
        let (store, url) = try makeStore()
        defer { store.close(); cleanup(url) }
        let writer = try LocalTimelineImportWriter(store: store, source: "wal-delete.json")
        try writer.addVisit(.init(
            startTime: "2025-01-02T12:00:00Z",
            latitude: 1.0, longitude: 2.0
        ))
        _ = try writer.finalize()
        try store.deleteAll()
        let info = try store.truncateWAL()
        XCTAssertGreaterThanOrEqual(info.framesInLog, -1)
    }

    func testCheckpointIsIdempotent() throws {
        let (store, url) = try makeStore()
        defer { store.close(); cleanup(url) }
        _ = try store.truncateWAL()
        _ = try store.truncateWAL()
        let info = try store.truncateWAL()
        XCTAssertGreaterThanOrEqual(info.framesInLog, -1)
    }

    func testCheckpointPassiveModeSucceeds() throws {
        let (store, url) = try makeStore()
        defer { store.close(); cleanup(url) }
        let info = try store.checkpointWAL(mode: .passive)
        XCTAssertGreaterThanOrEqual(info.framesInLog, -1)
    }

    func testCheckpointThrowsAfterClose() throws {
        let (store, url) = try makeStore()
        defer { cleanup(url) }
        store.close()
        XCTAssertThrowsError(try store.truncateWAL()) { err in
            guard case LocalTimelineStoreError.notOpen = err else {
                XCTFail("expected .notOpen, got \(err)")
                return
            }
        }
    }

    func testBestEffortTruncateReturnsNilAfterClose() throws {
        let (store, url) = try makeStore()
        defer { cleanup(url) }
        store.close()
        XCTAssertNil(store.bestEffortTruncateWAL())
    }
}
