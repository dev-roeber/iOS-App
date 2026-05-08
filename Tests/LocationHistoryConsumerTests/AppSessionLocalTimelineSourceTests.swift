import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-7A — `AppSessionState.show(localTimeline:)` setzt den Store-Pfad
/// bounded an, ohne den In-Memory-Pfad zu materialisieren oder Koordinaten
/// zu dekodieren.
final class AppSessionLocalTimelineSourceTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTSrc-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    private func makeStoreSession() throws -> (LocalTimelineStore, LocalTimelineSession) {
        let url = tempDir.appendingPathComponent("store.sqlite")
        let store = try LocalTimelineStore(url: url)
        let writer = try LocalTimelineImportWriter(store: store, source: "phase7a.json")
        try writer.addVisit(.init(startTime: "2024-01-01T08:00:00Z",
                                  endTime: "2024-01-01T09:00:00Z",
                                  latitude: 48.0, longitude: 11.0, name: "Home"))
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
        return (store, session)
    }

    func testShowLocalTimelineSetsBoundedSession() throws {
        let (store, session) = try makeStoreSession()
        defer { store.close() }

        var state = AppSessionState()
        state.show(localTimeline: session)

        XCTAssertEqual(state.localTimelineSession?.importID, session.importID)
        XCTAssertEqual(state.localTimelineSession?.sourceFilename, "phase7a.json")
        XCTAssertNil(state.content, "Store-Pfad darf keinen In-Memory-AppExport halten")
        XCTAssertFalse(state.isLoading)
        XCTAssertEqual(state.message?.kind, .info)
        XCTAssertEqual(state.message?.title, "Google Timeline loaded")
    }

    func testShowLocalTimelineDoesNotMaterializeAppExport() throws {
        let (store, session) = try makeStoreSession()
        defer { store.close() }

        var state = AppSessionState()
        state.show(localTimeline: session)

        // Legacy-Properties dürfen nichts liefern, ohne zu crashen.
        XCTAssertNil(state.overview)
        XCTAssertNil(state.insights)
        XCTAssertTrue(state.daySummaries.isEmpty)
        XCTAssertFalse(state.hasLoadedContent)
    }

    func testShowLocalTimelineDoesNotEagerDecodeCoordinates() throws {
        // Wir verifizieren das indirekt: `show(localTimeline:)` verwendet die
        // Session ausschließlich für Banner/Title — es gibt keinen Pfad, der
        // den `CoordBlobIterator` triggern könnte. Hardening: nach `show` darf
        // die Session unverändert weiterleben und Reader-Aufrufe sind
        // weiterhin möglich.
        let (store, session) = try makeStoreSession()
        defer { store.close() }

        var state = AppSessionState()
        state.show(localTimeline: session)
        XCTAssertEqual(state.localTimelineSession?.summary.pathCount, 1)
        XCTAssertEqual(state.localTimelineSession?.summary.visitCount, 1)
        // Reader ist frei, on-demand Coords zu liefern (echter Decode-Hook).
        let reader = LocalTimelineStoreReader(store: store)
        let days = try reader.days(forImportId: session.importID)
        XCTAssertFalse(days.isEmpty)
    }

    func testShowContentClearsLocalTimelineSession() throws {
        let (store, session) = try makeStoreSession()
        defer { store.close() }

        var state = AppSessionState()
        state.show(localTimeline: session)
        XCTAssertNotNil(state.localTimelineSession)

        // In-Memory-Session danach setzen → Store-Session muss gehen.
        let export = try AppExportDecoder.decode(
            contentsOf: TestSupport.contractFixtureURL(named: "golden_app_export_sample_small.json")
        )
        let dummy = AppSessionContent(
            export: export, source: .importedFile(filename: "legacy.json")
        )
        state.show(content: dummy)
        XCTAssertNil(state.localTimelineSession)
        XCTAssertNotNil(state.content)
    }

    func testClearContentClearsLocalTimelineSession() throws {
        let (store, session) = try makeStoreSession()
        defer { store.close() }

        var state = AppSessionState()
        state.show(localTimeline: session)
        state.clearContent()
        XCTAssertNil(state.localTimelineSession)
        XCTAssertNil(state.content)
    }
}
