import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Phase-10A-Folge — P1-D: Recovery-Tests für mid-import "Crash"-Szenarien.
///
/// **Scope-Hinweis (verbatim Spec):** Linux-Simulation, **kein** echter
/// iOS-Jetsam-Test. Wir simulieren einen abrupten Abbruch, indem wir die
/// Store-Connection ohne `writer.finalize()`/`writer.cancel()` schließen
/// — SQLite muss die noch offene `BEGIN IMMEDIATE`-Transaktion beim
/// Connection-Close automatisch zurückrollen. Das deckt **keine**
/// Power-Loss-/Kernel-Kill-Szenarien auf echter Hardware ab.
final class LocalTimelineStoreRecoveryTests: XCTestCase {

    private func tmpURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("lts-recover-\(UUID().uuidString).sqlite")
    }

    private func cleanup(_ url: URL) {
        for suffix in ["", "-wal", "-shm"] {
            let u = URL(fileURLWithPath: url.path + suffix)
            try? FileManager.default.removeItem(at: u)
        }
    }

    /// Hilfsfunktion: simuliert einen abrupten Abbruch. Der Writer wird
    /// in einem inneren Scope erzeugt und beschrieben; danach wird der
    /// Store geschlossen, **ohne** `finalize()` oder `cancel()` aufzurufen.
    /// SQLite verwirft die uncommittete `BEGIN IMMEDIATE`-Transaktion.
    private func simulateAbruptAbort(at url: URL) throws {
        let store = try LocalTimelineStore(url: url)
        let writer = try LocalTimelineImportWriter(store: store, source: "crashy.json")
        try writer.addVisit(.init(
            startTime: "2025-01-10T08:00:00Z",
            endTime: "2025-01-10T08:30:00Z",
            latitude: 48.137, longitude: 11.575
        ))
        try writer.addPath(.init(
            startTime: "2025-01-10T09:00:00Z",
            endTime: "2025-01-10T09:15:00Z",
            mode: "walking",
            distanceM: 250,
            flatCoordinates: [48.1, 11.5, 48.11, 11.51, 48.12, 11.52]
        ))
        // Keine finalize/cancel — Crash-Simulation: Connection schließen
        // mit offener Transaktion. SQLite rollback'd automatisch.
        store.close()
        _ = writer  // Halte Writer-Referenz bis zum Scope-Ende.
    }

    func testReopenAfterMidImportAbortShowsNoRows() throws {
        let url = tmpURL()
        defer { cleanup(url) }
        try simulateAbruptAbort(at: url)

        let recovered = try LocalTimelineStore(url: url)
        defer { recovered.close() }
        let imports = try recovered.imports()
        XCTAssertEqual(imports.count, 0,
                       "Mid-Import-Abort darf keine import-row hinterlassen")
    }

    func testReopenAfterAbortAllowsNewImport() throws {
        let url = tmpURL()
        defer { cleanup(url) }
        try simulateAbruptAbort(at: url)

        let recovered = try LocalTimelineStore(url: url)
        defer { recovered.close() }
        let writer = try LocalTimelineImportWriter(store: recovered, source: "fresh.json")
        try writer.addVisit(.init(
            startTime: "2025-02-01T10:00:00Z",
            latitude: 50.0, longitude: 8.0
        ))
        let summary = try writer.finalize()
        XCTAssertEqual(summary.totalEntries, 1)
        XCTAssertEqual(summary.skippedEntries, 0)
        XCTAssertEqual(try recovered.imports().count, 1)
    }

    func testDeleteAllAfterAbortSucceeds() throws {
        let url = tmpURL()
        defer { cleanup(url) }
        try simulateAbruptAbort(at: url)

        let recovered = try LocalTimelineStore(url: url)
        defer { recovered.close() }
        XCTAssertNoThrow(try recovered.deleteAll())
        XCTAssertEqual(try recovered.imports().count, 0)
    }

    func testForeignKeysStayConsistentAfterAbort() throws {
        let url = tmpURL()
        defer { cleanup(url) }
        try simulateAbruptAbort(at: url)

        let recovered = try LocalTimelineStore(url: url)
        defer { recovered.close() }
        // Es darf weder eine days-Row noch eine paths-/visits-Row geben.
        // (Über `imports`-Liste reicht — alle FKs zeigen auf imports.id;
        // ohne import gibt es keine days, ohne days keine paths/visits.)
        XCTAssertEqual(try recovered.imports().count, 0)
        // Direkt zählen: führt nicht-leere Tabelle zu kaputtem Reader?
        // Ein zweiter Import muss dennoch sauber laufen.
        let writer = try LocalTimelineImportWriter(store: recovered, source: "post-recovery.json")
        try writer.addVisit(.init(
            startTime: "2025-03-01T10:00:00Z",
            latitude: 1, longitude: 1
        ))
        _ = try writer.finalize()
        let imports = try recovered.imports()
        XCTAssertEqual(imports.count, 1)
        let days = try recovered.days(forImportId: imports[0].id)
        XCTAssertEqual(days.count, 1)
    }

    func testReaderAfterAbortReturnsEmptyNotCorrupt() throws {
        let url = tmpURL()
        defer { cleanup(url) }
        try simulateAbruptAbort(at: url)

        let recovered = try LocalTimelineStore(url: url)
        defer { recovered.close() }
        // Kein Import → `days(forImportId:)` für einen Random-ID muss
        // einfach `[]` liefern, nicht crashen.
        let days = try recovered.days(forImportId: UUID().uuidString)
        XCTAssertEqual(days.count, 0)
    }

    func testCancelMidStreamLeavesNoValidRows() throws {
        // Sicherheitsnetz: das bestehende Cancel/Rollback-Verhalten
        // (P1-A) muss auch nach P1-C-Wiring (best-effort WAL truncate
        // im cancel-Pfad) intakt bleiben.
        let url = tmpURL()
        defer { cleanup(url) }
        let store = try LocalTimelineStore(url: url)
        defer { store.close() }
        let writer = try LocalTimelineImportWriter(store: store, source: "cancel.json")
        try writer.addVisit(.init(
            startTime: "2025-04-01T10:00:00Z",
            latitude: 10, longitude: 10
        ))
        writer.cancel()
        XCTAssertEqual(try store.imports().count, 0)
        // Neuer Import muss möglich sein.
        let writer2 = try LocalTimelineImportWriter(store: store, source: "after-cancel.json")
        try writer2.addVisit(.init(
            startTime: "2025-04-02T10:00:00Z",
            latitude: 10, longitude: 10
        ))
        _ = try writer2.finalize()
        XCTAssertEqual(try store.imports().count, 1)
    }
}
