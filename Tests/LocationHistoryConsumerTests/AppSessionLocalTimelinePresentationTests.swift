import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-7B — `AppSessionState.activeContent` schaltet zwischen Legacy und
/// Store-backed Pfad und hält die Exklusivitäts-Invariante.
final class AppSessionLocalTimelinePresentationTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTPres-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    private func makeSession() throws -> (LocalTimelineStore, LocalTimelineSession) {
        let url = tempDir.appendingPathComponent("store.sqlite")
        let store = try LocalTimelineStore(url: url)
        let writer = try LocalTimelineImportWriter(store: store, source: "pres.json")
        try writer.addVisit(.init(startTime: "2024-01-01T08:00:00Z",
                                  latitude: 48, longitude: 11, name: "H"))
        let summary = try writer.finalize()
        let reader = LocalTimelineStoreReader(store: store)
        let session = try LocalTimelineSession.make(reader: reader,
                                                    importID: summary.importId,
                                                    storeURL: url)
        return (store, session)
    }

    func testActiveContentIsNoneOnEmptyState() {
        let state = AppSessionState()
        XCTAssertEqual(state.activeContent, .none)
        XCTAssertFalse(state.isLocalTimelineActive)
    }

    func testActiveContentIsLocalTimelineAfterShow() throws {
        let (store, session) = try makeSession()
        defer { store.close() }
        var state = AppSessionState()
        state.show(localTimeline: session)
        guard case .localTimeline = state.activeContent else {
            return XCTFail("expected .localTimeline, got \(state.activeContent)")
        }
        XCTAssertTrue(state.isLocalTimelineActive)
    }

    func testActiveContentIsLegacyAfterShowContent() throws {
        let export = try AppExportDecoder.decode(
            contentsOf: TestSupport.contractFixtureURL(named: "golden_app_export_sample_small.json")
        )
        var state = AppSessionState()
        state.show(content: AppSessionContent(export: export, source: .importedFile(filename: "x.json")))
        guard case .legacy = state.activeContent else {
            return XCTFail("expected .legacy, got \(state.activeContent)")
        }
        XCTAssertFalse(state.isLocalTimelineActive)
    }

    func testLegacyAndLocalTimelineAreMutuallyExclusive() throws {
        let (store, session) = try makeSession()
        defer { store.close() }
        let export = try AppExportDecoder.decode(
            contentsOf: TestSupport.contractFixtureURL(named: "golden_app_export_sample_small.json")
        )
        var state = AppSessionState()
        state.show(localTimeline: session)
        XCTAssertNil(state.content)
        XCTAssertNotNil(state.localTimelineSession)

        state.show(content: AppSessionContent(export: export, source: .importedFile(filename: "x.json")))
        XCTAssertNotNil(state.content)
        XCTAssertNil(state.localTimelineSession,
                     "show(content:) muss Store-Session leeren")

        state.show(localTimeline: session)
        XCTAssertNil(state.content,
                     "show(localTimeline:) muss Legacy-Content leeren")
    }

    func testClearContentClearsBothPaths() throws {
        let (store, session) = try makeSession()
        defer { store.close() }
        var state = AppSessionState()
        state.show(localTimeline: session)
        state.clearContent()
        XCTAssertEqual(state.activeContent, .none)
        XCTAssertNil(state.content)
        XCTAssertNil(state.localTimelineSession)
    }
}
