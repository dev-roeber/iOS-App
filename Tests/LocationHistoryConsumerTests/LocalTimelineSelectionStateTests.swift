import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-9B — `AppSessionState.selectedLocalTimelineDayId` ist getrennt vom
/// Legacy-`selectedDate`. `selectLocalTimelineDay(_:)` akzeptiert Werte nur
/// bei aktiver `localTimelineSession`, `clearContent` und `show(content:)`
/// resetten den Wert; `show(localTimeline:)` startet ohne Auswahl.
final class LocalTimelineSelectionStateTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTSel-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    private func makeStoreSession() throws -> (LocalTimelineStore, LocalTimelineSession) {
        let url = tempDir.appendingPathComponent("sel.sqlite")
        let store = try LocalTimelineStore(url: url)
        let writer = try LocalTimelineImportWriter(store: store, source: "sel.json")
        try writer.addVisit(.init(startTime: "2024-04-01T08:00:00Z",
                                  endTime: "2024-04-01T09:00:00Z",
                                  latitude: 48.0, longitude: 11.0, name: "X"))
        let summary = try writer.finalize()
        let reader = LocalTimelineStoreReader(store: store)
        let session = try LocalTimelineSession.make(reader: reader,
                                                    importID: summary.importId,
                                                    storeURL: url)
        return (store, session)
    }

    func testSelectionIgnoredWithoutSession() {
        var state = AppSessionState()
        state.selectLocalTimelineDay("any-day")
        XCTAssertNil(state.selectedLocalTimelineDayId)
    }

    func testSelectionPersistsWhileSessionActive() throws {
        let (store, session) = try makeStoreSession()
        defer { store.close() }

        var state = AppSessionState()
        state.show(localTimeline: session)
        XCTAssertNil(state.selectedLocalTimelineDayId)

        state.selectLocalTimelineDay("day-42")
        XCTAssertEqual(state.selectedLocalTimelineDayId, "day-42")

        state.selectLocalTimelineDay(nil)
        XCTAssertNil(state.selectedLocalTimelineDayId)
    }

    func testClearContentResetsSelection() throws {
        let (store, session) = try makeStoreSession()
        defer { store.close() }

        var state = AppSessionState()
        state.show(localTimeline: session)
        state.selectLocalTimelineDay("day-7")
        XCTAssertEqual(state.selectedLocalTimelineDayId, "day-7")

        state.clearContent()
        XCTAssertNil(state.selectedLocalTimelineDayId)
        XCTAssertNil(state.localTimelineSession)
    }

    func testShowContentResetsSelection() throws {
        let (store, session) = try makeStoreSession()
        defer { store.close() }

        var state = AppSessionState()
        state.show(localTimeline: session)
        state.selectLocalTimelineDay("day-7")

        let export = try AppExportDecoder.decode(
            contentsOf: TestSupport.contractFixtureURL(named: "golden_app_export_sample_small.json")
        )
        state.show(content: AppSessionContent(
            export: export, source: .importedFile(filename: "legacy.json")
        ))
        XCTAssertNil(state.selectedLocalTimelineDayId)
        XCTAssertNotNil(state.content)
    }

    func testReShowingLocalTimelineResetsSelection() throws {
        let (store, session) = try makeStoreSession()
        defer { store.close() }

        var state = AppSessionState()
        state.show(localTimeline: session)
        state.selectLocalTimelineDay("day-7")
        XCTAssertEqual(state.selectedLocalTimelineDayId, "day-7")

        state.show(localTimeline: session)
        XCTAssertNil(state.selectedLocalTimelineDayId,
                     "Re-Show muss frische Auswahl ohne Hangover liefern")
    }

    func testSelectionStaysSeparateFromLegacySelectedDate() throws {
        let (store, session) = try makeStoreSession()
        defer { store.close() }

        var state = AppSessionState()
        state.show(localTimeline: session)
        state.selectLocalTimelineDay("day-7")
        XCTAssertNil(state.selectedDate,
                     "Store-Auswahl darf den Legacy-`selectedDate` nicht setzen")
    }
}
