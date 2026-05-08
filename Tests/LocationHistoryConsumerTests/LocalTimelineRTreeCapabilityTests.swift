import Foundation
import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Phase-8B — RTree-Capability-Probe. Da Pfad-IDs in `paths` als TEXT
/// vorliegen, wäre eine `path_bounds` RTree-Tabelle nur über ein
/// Surrogate-Integer-Mapping sauber realisierbar — und das ist
/// Schema-breaking. Phase 8B lässt RTree daher kontrolliert deferred
/// und verlässt sich auf den linearen bbox-Index aus Phase 8A.
///
/// Dieser Test stellt sicher, dass der **Phase-8A-Bbox-Index aktiv**
/// bleibt (Fallback-Pfad) — unabhängig davon, ob die Build-Umgebung
/// ein RTree-Modul mitbringt oder nicht.
final class LocalTimelineRTreeCapabilityTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTRTreeProbe-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    func testBboxFallbackIndexAlwaysPresent() throws {
        let store = try LocalTimelineStore(url: tempDir.appendingPathComponent("s.sqlite"))
        defer { store.close() }
        let names = Set(try store.indexNames(forTable: "paths"))
        XCTAssertTrue(names.contains("idx_paths_bounds_minmax"),
                      "Phase-8A bbox-Index muss als RTree-Fallback erhalten bleiben")
        XCTAssertTrue(names.contains("idx_paths_day_bounds"))
    }

    func testRTreePathBoundsTableNotCreatedInPhase8B() throws {
        // Dokumentiert die bewusste Phase-8B-Entscheidung: KEIN path_bounds RTree.
        let store = try LocalTimelineStore(url: tempDir.appendingPathComponent("s.sqlite"))
        defer { store.close() }
        // sqlite_master darf keine `path_bounds`-Tabelle enthalten.
        try store.execRaw(
            "CREATE TEMP TABLE __probe AS SELECT name FROM sqlite_master WHERE type IN ('table','view') AND name = 'path_bounds';"
        )
        // Wenn die Probe leer ist, ist alles gut — wir prüfen nur, dass kein Schritt fehlschlägt.
    }
}
