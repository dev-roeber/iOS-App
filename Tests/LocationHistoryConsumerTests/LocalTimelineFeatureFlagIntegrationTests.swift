import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-7A — Integration zwischen `LocalTimelineFeatureFlags` und
/// `AppContentLoader.loadImportedContentEnvelope`. Stellt sicher, dass das
/// Flag deterministisch über den Resolver-Path wirkt und der Default-Pfad
/// niemals den Store anfasst.
final class LocalTimelineFeatureFlagIntegrationTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTIntegration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    private func writeTimelineJSON() throws -> URL {
        let json = """
        [
          { "startTime": "2024-06-01T07:00:00Z",
            "endTime":   "2024-06-01T07:30:00Z",
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

    func testResolverViaArgumentsRoutesToStore() async throws {
        let url = try writeTimelineJSON()
        let flags = LocalTimelineFeatureFlags.resolve(
            arguments: ["--LH2GPX_LOCAL_TIMELINE_STORE"], environment: [:]
        )
        XCTAssertTrue(flags.isLocalTimelineStoreEnabled)

        let envelope = try await AppContentLoader.loadImportedContentEnvelope(
            from: url, flags: flags, storeFactoryProvider: factoryProvider()
        )
        XCTAssertNotNil(envelope.localTimelineSession)
    }

    func testResolverViaEnvironmentRoutesToStore() async throws {
        let url = try writeTimelineJSON()
        let flags = LocalTimelineFeatureFlags.resolve(
            arguments: [], environment: ["LH2GPX_LOCAL_TIMELINE_STORE": "yes"]
        )
        XCTAssertTrue(flags.isLocalTimelineStoreEnabled)

        let envelope = try await AppContentLoader.loadImportedContentEnvelope(
            from: url, flags: flags, storeFactoryProvider: factoryProvider()
        )
        XCTAssertNotNil(envelope.localTimelineSession)
    }

    func testResolverDefaultLeavesStoreUntouched() async throws {
        let url = try writeTimelineJSON()
        let flags = LocalTimelineFeatureFlags.resolve(arguments: [], environment: [:])
        XCTAssertFalse(flags.isLocalTimelineStoreEnabled)

        let envelope = try await AppContentLoader.loadImportedContentEnvelope(
            from: url, flags: flags, storeFactoryProvider: factoryProvider()
        )
        XCTAssertNotNil(envelope.inMemoryContent)
        XCTAssertNil(envelope.localTimelineSession)
    }

    func testEnvelopeSourceFilenameMatchesPathInBothBranches() async throws {
        let url = try writeTimelineJSON()

        let off = try await AppContentLoader.loadImportedContentEnvelope(
            from: url,
            flags: LocalTimelineFeatureFlags(isLocalTimelineStoreEnabled: false),
            storeFactoryProvider: factoryProvider()
        )
        XCTAssertEqual(off.sourceFilename, url.lastPathComponent)

        let on = try await AppContentLoader.loadImportedContentEnvelope(
            from: url,
            flags: LocalTimelineFeatureFlags(isLocalTimelineStoreEnabled: true),
            storeFactoryProvider: factoryProvider()
        )
        XCTAssertEqual(on.sourceFilename, url.lastPathComponent)
    }
}
