import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-10A P1-A/B (Weg 2) — Round-Trip-Tests Loader → AppSessionState
/// für den Store-Pfad: Erfolgs-Routing, Cancel-Routing inkl.
/// Fehler-Banner, Reimport nach Cancel und Legacy-Fallback bei
/// deaktivem Feature-Flag.
final class AppFlowImportCancelRoutingTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("FlowCR-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func writeTimelineJSON(filename: String = "location-history.json") throws -> URL {
        var entries: [String] = []
        for i in 0..<20 {
            let h = String(format: "%02d", i % 24)
            entries.append("""
            { "startTime": "2024-07-01T\(h):00:00Z",
              "visit": { "topCandidate": {
                "placeLocation": "geo:48.13,11.57", "semanticType": "HOME" } } }
            """)
        }
        let json = "[" + entries.joined(separator: ",") + "]"
        let url = tempDir.appendingPathComponent(filename)
        try Data(json.utf8).write(to: url)
        return url
    }

    private func factoryProvider(
        storeRoot: URL? = nil
    ) -> @Sendable () throws -> LocalTimelineStoreFactory {
        let root = storeRoot ?? tempDir!.appendingPathComponent("store-root", isDirectory: true)
        return { LocalTimelineStoreFactory.temporary(under: root) }
    }

    // MARK: - Tests

    func testStorePathSuccessRoutesToLocalTimelineSession() async throws {
        let url = try writeTimelineJSON()
        let controller = LocalTimelineImportController()

        let outcome = await LH2GPXAppFlow.loadImportedFileEnvelope(
            at: url, source: .manual,
            flags: LocalTimelineFeatureFlags(isLocalTimelineStoreEnabled: true),
            storeFactoryProvider: factoryProvider(),
            importProgress: controller.progressSink,
            importCancellation: controller.cancellation
        )

        guard case .localTimeline = outcome else {
            return XCTFail("expected .localTimeline, got \(outcome)")
        }

        var session = AppSessionState()
        session.beginLoading()
        let routing = LH2GPXAppFlow.apply(
            envelopeOutcome: outcome,
            to: &session,
            preserveOnFailure: false
        )

        XCTAssertEqual(routing, .localTimeline)
        XCTAssertNotNil(session.localTimelineSession)
        XCTAssertNil(session.content)
        XCTAssertFalse(session.isLoading)
    }

    func testCancellationLeavesSessionWithoutLocalTimelineAndShowsErrorMessage() async throws {
        let url = try writeTimelineJSON(filename: "cancelflow.json")
        let controller = LocalTimelineImportController()
        controller.cancel() // pre-cancel before loader runs

        let outcome = await LH2GPXAppFlow.loadImportedFileEnvelope(
            at: url, source: .manual,
            flags: LocalTimelineFeatureFlags(isLocalTimelineStoreEnabled: true),
            storeFactoryProvider: factoryProvider(),
            importProgress: controller.progressSink,
            importCancellation: controller.cancellation
        )

        guard case .failure = outcome else {
            return XCTFail("expected .failure for pre-cancel, got \(outcome)")
        }

        var session = AppSessionState()
        session.beginLoading()
        _ = LH2GPXAppFlow.apply(
            envelopeOutcome: outcome,
            to: &session,
            preserveOnFailure: false
        )

        XCTAssertNil(session.localTimelineSession)
        XCTAssertNil(session.content)
        XCTAssertFalse(session.isLoading)
        XCTAssertEqual(session.message?.kind, .error)
        XCTAssertEqual(session.message?.title, "Import cancelled")
    }

    func testReimportAfterCancelSucceeds() async throws {
        let url = try writeTimelineJSON(filename: "reimport.json")
        // Same store root for both attempts so the second import targets
        // the same DB layout the first attempt would have populated.
        let storeRoot = tempDir!.appendingPathComponent("shared-store-root", isDirectory: true)
        let provider = factoryProvider(storeRoot: storeRoot)

        // First attempt: pre-cancelled.
        let cancelController = LocalTimelineImportController()
        cancelController.cancel()
        let cancelOutcome = await LH2GPXAppFlow.loadImportedFileEnvelope(
            at: url, source: .manual,
            flags: LocalTimelineFeatureFlags(isLocalTimelineStoreEnabled: true),
            storeFactoryProvider: provider,
            importProgress: cancelController.progressSink,
            importCancellation: cancelController.cancellation
        )

        var session = AppSessionState()
        session.beginLoading()
        _ = LH2GPXAppFlow.apply(
            envelopeOutcome: cancelOutcome,
            to: &session,
            preserveOnFailure: false
        )
        XCTAssertNil(session.localTimelineSession)
        XCTAssertEqual(session.message?.kind, .error)

        // Second attempt: fresh controller, no pre-cancel, same path/provider.
        let freshController = LocalTimelineImportController()
        let freshOutcome = await LH2GPXAppFlow.loadImportedFileEnvelope(
            at: url, source: .manual,
            flags: LocalTimelineFeatureFlags(isLocalTimelineStoreEnabled: true),
            storeFactoryProvider: provider,
            importProgress: freshController.progressSink,
            importCancellation: freshController.cancellation
        )

        guard case .localTimeline = freshOutcome else {
            return XCTFail("expected .localTimeline on retry, got \(freshOutcome)")
        }

        session.beginLoading()
        let routing = LH2GPXAppFlow.apply(
            envelopeOutcome: freshOutcome,
            to: &session,
            preserveOnFailure: false
        )
        XCTAssertEqual(routing, .localTimeline)
        XCTAssertNotNil(session.localTimelineSession)
        XCTAssertNil(session.content)
        XCTAssertFalse(session.isLoading)
    }

    func testFeatureFlagDisabledKeepsLegacyRoutingUnchanged() async throws {
        let url = try writeTimelineJSON(filename: "legacy.json")
        let controller = LocalTimelineImportController()

        let outcome = await LH2GPXAppFlow.loadImportedFileEnvelope(
            at: url, source: .manual,
            flags: LocalTimelineFeatureFlags(isLocalTimelineStoreEnabled: false),
            storeFactoryProvider: factoryProvider(),
            importProgress: controller.progressSink,
            importCancellation: controller.cancellation
        )

        guard case .legacy = outcome else {
            return XCTFail("expected .legacy with flag disabled, got \(outcome)")
        }

        var session = AppSessionState()
        session.beginLoading()
        let routing = LH2GPXAppFlow.apply(
            envelopeOutcome: outcome,
            to: &session,
            preserveOnFailure: false
        )

        XCTAssertEqual(routing, .legacy)
        XCTAssertNotNil(session.content)
        XCTAssertNil(session.localTimelineSession)
        XCTAssertFalse(session.isLoading)
    }
}
