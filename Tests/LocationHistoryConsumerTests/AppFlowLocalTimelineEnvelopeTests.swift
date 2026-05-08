import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-7B — `LH2GPXAppFlow.loadImportedFileEnvelope` routet je nach
/// Feature-Flag in den Legacy-Pfad oder in den Store-Pfad.
final class AppFlowLocalTimelineEnvelopeTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTFlow-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    private func writeTimelineJSON() throws -> URL {
        let json = """
        [
          { "startTime": "2024-07-01T08:00:00Z",
            "endTime":   "2024-07-01T08:30:00Z",
            "visit": {
              "topCandidate": {
                "placeLocation": "geo:48.137154,11.576124",
                "semanticType": "HOME"
              }
            }
          }
        ]
        """
        let url = tempDir.appendingPathComponent("location-history.json")
        try Data(json.utf8).write(to: url)
        return url
    }

    private func factoryProvider() -> @Sendable () throws -> LocalTimelineStoreFactory {
        let storeRoot = tempDir!.appendingPathComponent("store-root", isDirectory: true)
        return { LocalTimelineStoreFactory.temporary(under: storeRoot) }
    }

    func testFlagDisabledRoutesToLegacy() async throws {
        let url = try writeTimelineJSON()
        let outcome = await LH2GPXAppFlow.loadImportedFileEnvelope(
            at: url, source: .manual,
            flags: LocalTimelineFeatureFlags(isLocalTimelineStoreEnabled: false),
            storeFactoryProvider: factoryProvider()
        )
        guard case .legacy = outcome else {
            return XCTFail("expected .legacy, got \(outcome)")
        }
    }

    func testFlagEnabledRoutesGoogleTimelineToStore() async throws {
        let url = try writeTimelineJSON()
        let outcome = await LH2GPXAppFlow.loadImportedFileEnvelope(
            at: url, source: .manual,
            flags: LocalTimelineFeatureFlags(isLocalTimelineStoreEnabled: true),
            storeFactoryProvider: factoryProvider()
        )
        guard case let .localTimeline(session) = outcome else {
            return XCTFail("expected .localTimeline, got \(outcome)")
        }
        XCTAssertEqual(session.sourceFilename, "location-history.json")
    }

    func testFailureSurfacesAsFailure() async throws {
        let missing = tempDir.appendingPathComponent("does-not-exist.json")
        let outcome = await LH2GPXAppFlow.loadImportedFileEnvelope(
            at: missing, source: .manual,
            flags: LocalTimelineFeatureFlags(isLocalTimelineStoreEnabled: false),
            storeFactoryProvider: factoryProvider()
        )
        guard case .failure = outcome else {
            return XCTFail("expected .failure, got \(outcome)")
        }
    }
}
