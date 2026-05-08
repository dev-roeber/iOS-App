import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-9A — `LH2GPXAppFlow.apply(envelopeOutcome:to:preserveOnFailure:)`
/// ist die geteilte Routing-Helper-Funktion für Wrapper-ContentView und
/// Package-AppShellRootView. Tests sichern, daß die Outcome-Cases
/// deterministisch in `AppSessionState.show(content:)`,
/// `show(localTimeline:)` bzw. `showFailure(...)` münden, und daß die
/// AppSessionState-Invariante (content/localTimelineSession nie beide
/// gleichzeitig aktiv) erhalten bleibt.
final class WrapperLocalTimelineEnvelopeRoutingTests: XCTestCase {

    private func makeStoreSession() -> LocalTimelineSession {
        LocalTimelineSession(
            importID: "imp-1",
            sourceFilename: "location-history.json",
            storeURL: URL(fileURLWithPath: "/tmp/x.sqlite"),
            createdAt: "2026-05-08T00:00:00Z",
            importedAt: "2026-05-08T00:00:00Z",
            summary: .init(dayCount: 2, pathCount: 1, visitCount: 1,
                           activityCount: 0, totalDistanceM: 0,
                           dateRange: "2026-05-07"..."2026-05-08")
        )
    }

    private func makeLegacyContent() throws -> AppSessionContent {
        let export = try AppExportDecoder.decode(
            contentsOf: TestSupport.contractFixtureURL(named: "golden_app_export_sample_small.json")
        )
        return AppSessionContent(export: export, source: .importedFile(filename: "x.json"))
    }

    func testLegacyOutcomeRoutesToShowContent() throws {
        var session = AppSessionState()
        let content = try makeLegacyContent()
        let routing = LH2GPXAppFlow.apply(
            envelopeOutcome: .legacy(content),
            to: &session,
            preserveOnFailure: false
        )
        XCTAssertEqual(routing, .legacy)
        XCTAssertNotNil(session.content)
        XCTAssertNil(session.localTimelineSession,
                     "Invariante: content und localTimelineSession nie gleichzeitig aktiv")
    }

    func testLocalTimelineOutcomeRoutesToShowLocalTimeline() {
        var session = AppSessionState()
        let store = makeStoreSession()
        let routing = LH2GPXAppFlow.apply(
            envelopeOutcome: .localTimeline(store),
            to: &session,
            preserveOnFailure: false
        )
        XCTAssertEqual(routing, .localTimeline)
        XCTAssertNil(session.content,
                     "Invariante: content und localTimelineSession nie gleichzeitig aktiv")
        XCTAssertEqual(session.localTimelineSession?.importID, "imp-1")
    }

    func testFailureOutcomeWithoutBookmarkClear() {
        var session = AppSessionState()
        let routing = LH2GPXAppFlow.apply(
            envelopeOutcome: .failure(title: "T", message: "M", clearBookmark: false),
            to: &session,
            preserveOnFailure: false
        )
        XCTAssertEqual(routing, .failure(clearBookmark: false))
        XCTAssertEqual(session.message?.kind, .error)
        XCTAssertNil(session.content)
        XCTAssertNil(session.localTimelineSession)
    }

    func testFailureOutcomeWithBookmarkClear() {
        var session = AppSessionState()
        let routing = LH2GPXAppFlow.apply(
            envelopeOutcome: .failure(title: "T", message: "M", clearBookmark: true),
            to: &session,
            preserveOnFailure: false
        )
        XCTAssertEqual(routing, .failure(clearBookmark: true))
    }

    func testLocalTimelineOutcomeReplacesPreviousLegacyContent() throws {
        var session = AppSessionState()
        let content = try makeLegacyContent()
        session.show(content: content)
        XCTAssertNotNil(session.content)

        let store = makeStoreSession()
        _ = LH2GPXAppFlow.apply(
            envelopeOutcome: .localTimeline(store),
            to: &session,
            preserveOnFailure: false
        )
        XCTAssertNil(session.content,
                     "show(localTimeline:) muß bestehenden content ablösen")
        XCTAssertEqual(session.localTimelineSession?.importID, "imp-1")
    }

    func testLegacyOutcomeReplacesPreviousLocalTimelineSession() throws {
        var session = AppSessionState()
        session.show(localTimeline: makeStoreSession())
        XCTAssertNotNil(session.localTimelineSession)

        let content = try makeLegacyContent()
        _ = LH2GPXAppFlow.apply(
            envelopeOutcome: .legacy(content),
            to: &session,
            preserveOnFailure: false
        )
        XCTAssertNil(session.localTimelineSession,
                     "show(content:) muß bestehende localTimelineSession ablösen")
        XCTAssertNotNil(session.content)
    }
}
