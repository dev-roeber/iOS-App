import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-10A P1-A/B — Service-Schicht propagiert Progress + Cancel im
/// Store-Pfad. Legacy-Pfad bleibt unberührt.
final class AppFlowImportProgressCancelTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("FlowPC-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

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

    private func factoryProvider() -> @Sendable () throws -> LocalTimelineStoreFactory {
        let storeRoot = tempDir!.appendingPathComponent("store-root", isDirectory: true)
        return { LocalTimelineStoreFactory.temporary(under: storeRoot) }
    }

    func testStorePathReportsProgressOnEnvelopeLoad() async throws {
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
        XCTAssertEqual(controller.latestProgress?.phase, .completed)
        XCTAssertGreaterThan(controller.latestProgress?.entriesProcessed ?? 0, 0)
        XCTAssertFalse(controller.latestProgress?.isCancellable ?? true)
    }

    func testStorePathCancellationProducesFailureOutcomeWithoutPartialImport() async throws {
        let url = try writeTimelineJSON(filename: "cancelflow.json")
        let controller = LocalTimelineImportController()
        controller.cancel() // pre-cancel

        let outcome = await LH2GPXAppFlow.loadImportedFileEnvelope(
            at: url, source: .manual,
            flags: LocalTimelineFeatureFlags(isLocalTimelineStoreEnabled: true),
            storeFactoryProvider: factoryProvider(),
            importProgress: controller.progressSink,
            importCancellation: controller.cancellation
        )

        switch outcome {
        case let .failure(title, _, clearBookmark):
            XCTAssertEqual(title, "Import cancelled")
            XCTAssertFalse(clearBookmark)
        default:
            XCTFail("expected cancel to surface as .failure, got \(outcome)")
        }
        XCTAssertEqual(controller.latestProgress?.phase, .cancelled)
    }

    func testLegacyPathIsUnchangedWhenFlagDisabled() async throws {
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
            return XCTFail("expected .legacy, got \(outcome)")
        }
        // Legacy path receives no Store-Importer progress snapshots.
        XCTAssertNil(controller.latestProgress)
    }
}
