import Foundation
import XCTest
import ZIPFoundation
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-7A — `AppContentLoader.loadImportedContentEnvelope` schaltet bei
/// aktivem Feature-Flag den disk-first Store-Pfad frei und liefert
/// `.localTimeline(...)` ohne `AppExport` zu rekonstruieren. Bei
/// deaktiviertem Flag bleibt der Legacy-Pfad byte-identisch.
final class AppContentLoaderLocalTimelineStoreTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTLoader-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    private func writeTimelineJSON(filename: String = "location-history.json") throws -> URL {
        let json = """
        [
          { "startTime": "2024-05-01T08:00:00Z",
            "endTime":   "2024-05-01T08:30:00Z",
            "visit": {
              "topCandidate": {
                "placeLocation": "geo:52.520008,13.404954",
                "semanticType": "HOME"
              }
            }
          },
          { "startTime": "2024-05-01T09:00:00Z",
            "endTime":   "2024-05-01T09:45:00Z",
            "activity": {
              "start": "geo:52.520008,13.404954",
              "end":   "geo:52.530001,13.420000",
              "distanceMeters": 1234.5,
              "topCandidate": { "type": "WALKING", "probability": 0.88 }
            }
          }
        ]
        """
        let url = tempDir.appendingPathComponent(filename)
        try Data(json.utf8).write(to: url)
        return url
    }

    private func makeFactoryProvider() -> @Sendable () throws -> LocalTimelineStoreFactory {
        let storeRoot = tempDir!.appendingPathComponent("store-root", isDirectory: true)
        return { LocalTimelineStoreFactory.temporary(under: storeRoot) }
    }

    func testFlagDisabledFallsBackToLegacyInMemoryPath() async throws {
        let url = try writeTimelineJSON()
        let flags = LocalTimelineFeatureFlags(isLocalTimelineStoreEnabled: false)

        let envelope = try await AppContentLoader.loadImportedContentEnvelope(
            from: url, flags: flags, storeFactoryProvider: makeFactoryProvider()
        )

        guard case let .inMemory(content) = envelope else {
            return XCTFail("Flag disabled must yield .inMemory, got \(envelope)")
        }
        XCTAssertNotNil(content.export.meta.source.inputFormat)
    }

    func testFlagEnabledGoogleTimelineJSONUsesStorePath() async throws {
        let url = try writeTimelineJSON()
        let flags = LocalTimelineFeatureFlags(isLocalTimelineStoreEnabled: true)

        let envelope = try await AppContentLoader.loadImportedContentEnvelope(
            from: url, flags: flags, storeFactoryProvider: makeFactoryProvider()
        )

        guard case let .localTimeline(session) = envelope else {
            return XCTFail("Flag enabled + Google Timeline JSON must yield .localTimeline, got \(envelope)")
        }
        XCTAssertEqual(session.sourceFilename, "location-history.json")
        XCTAssertGreaterThan(session.summary.dayCount, 0)
        XCTAssertEqual(session.summary.visitCount, 1)
        XCTAssertEqual(session.summary.activityCount, 1)
    }

    func testStorePathDoesNotMaterializeAppExport() async throws {
        let url = try writeTimelineJSON()
        let flags = LocalTimelineFeatureFlags(isLocalTimelineStoreEnabled: true)

        let envelope = try await AppContentLoader.loadImportedContentEnvelope(
            from: url, flags: flags, storeFactoryProvider: makeFactoryProvider()
        )

        XCTAssertNil(envelope.inMemoryContent,
                     "Store-Pfad darf keinen AppSessionContent (und damit kein AppExport) materialisieren")
        XCTAssertNotNil(envelope.localTimelineSession)
    }

    func testFlagEnabledZipWithGoogleTimelineUsesStorePath() async throws {
        let url = try makeZIPWithTimelineEntry()
        let flags = LocalTimelineFeatureFlags(isLocalTimelineStoreEnabled: true)

        let envelope = try await AppContentLoader.loadImportedContentEnvelope(
            from: url, flags: flags, storeFactoryProvider: makeFactoryProvider()
        )

        guard case let .localTimeline(session) = envelope else {
            return XCTFail("Flag enabled + Google Timeline ZIP must yield .localTimeline, got \(envelope)")
        }
        XCTAssertGreaterThan(session.summary.dayCount, 0)
    }

    func testFlagEnabledNonGoogleTimelineFallsBackToLegacy() async throws {
        // LH2GPX-shaped JSON-Objekt darf den Store nicht treffen.
        let lhExport = try AppExportDecoder.decode(
            contentsOf: TestSupport.contractFixtureURL(named: "golden_app_export_sample_small.json")
        )
        // Wir reichen dieselbe Fixture-Datei direkt durch.
        let url = try TestSupport.contractFixtureURL(named: "golden_app_export_sample_small.json")
        let flags = LocalTimelineFeatureFlags(isLocalTimelineStoreEnabled: true)

        let envelope = try await AppContentLoader.loadImportedContentEnvelope(
            from: url, flags: flags, storeFactoryProvider: makeFactoryProvider()
        )

        guard case let .inMemory(content) = envelope else {
            return XCTFail("Non-Google-Timeline must fall back to .inMemory, got \(envelope)")
        }
        XCTAssertEqual(content.export.schemaVersion, lhExport.schemaVersion)
    }

    private func makeZIPWithTimelineEntry() throws -> URL {
        let zipURL = tempDir.appendingPathComponent("timeline.zip")
        let archive = try Archive(url: zipURL, accessMode: .create)
        let json = Data("""
        [
          { "startTime": "2024-05-01T08:00:00Z",
            "endTime":   "2024-05-01T08:30:00Z",
            "visit": {
              "topCandidate": {
                "placeLocation": "geo:52.5,13.4",
                "semanticType": "HOME"
              }
            }
          }
        ]
        """.utf8)
        try archive.addEntry(
            with: "location-history.json", type: .file, uncompressedSize: UInt32(json.count)
        ) { position, size in
            json.subdata(in: Int(position)..<Int(position) + size)
        }
        return zipURL
    }
}
