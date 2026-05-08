import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-10A P1-A + P1-B coverage: progress callbacks must report
/// preparing→importing→finalizing→completed with running counters, and
/// cooperative cancellation must roll back the open transaction without
/// leaving a successful import behind.
final class GoogleTimelineStoreImporterProgressCancelTests: XCTestCase {

    private final class Recorder: @unchecked Sendable {
        private let lock = NSLock()
        private var phases: [LocalTimelineImportProgress.Phase] = []
        private var last: LocalTimelineImportProgress?
        func record(_ snap: LocalTimelineImportProgress) {
            lock.lock()
            phases.append(snap.phase)
            last = snap
            lock.unlock()
        }
        var allPhases: [LocalTimelineImportProgress.Phase] {
            lock.lock(); defer { lock.unlock() }
            return phases
        }
        var lastSnapshot: LocalTimelineImportProgress? {
            lock.lock(); defer { lock.unlock() }
            return last
        }
    }

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("GTSImporterPC-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    private func makeStore(_ name: String = "store.sqlite") throws -> LocalTimelineStore {
        try LocalTimelineStore(url: tempDir.appendingPathComponent(name))
    }

    private func smallFixtureJSON() -> String {
        """
        [
          { "startTime": "2026-05-08T08:00:00Z", "endTime": "2026-05-08T08:30:00Z",
            "visit": { "topCandidate": {
              "placeLocation": "geo:52.5,13.4",
              "semanticType": "HOME",
              "placeID": "P1", "probability": "0.9" } } },
          { "startTime": "2026-05-08T09:00:00Z", "endTime": "2026-05-08T09:45:00Z",
            "activity": { "start": "geo:52.5,13.4", "end": "geo:52.51,13.41",
              "distanceMeters": 1000.0,
              "topCandidate": { "type": "WALKING", "probability": 0.8 } } },
          { "startTime": "2026-05-08T10:00:00Z", "endTime": "2026-05-08T10:15:00Z",
            "timelinePath": [
              { "point": "geo:52.51,13.41" },
              { "point": "geo:52.52,13.42" },
              { "point": "geo:52.53,13.43" }
            ] }
        ]
        """
    }

    // MARK: - Progress

    func testImporterReportsPreparingImportingFinalizingCompleted() throws {
        let store = try makeStore()
        defer { store.close() }

        let recorder = Recorder()
        let hooks = GoogleTimelineStoreImporter.Hooks(
            progress: { recorder.record($0) },
            throttle: .init(entryStride: 1)
        )

        let summary = try GoogleTimelineStoreImporter.importFromData(
            Data(smallFixtureJSON().utf8),
            sourceFilename: "fixture.json",
            store: store,
            hooks: hooks
        )

        let phases = recorder.allPhases
        let last = recorder.lastSnapshot
        // Writer counts 4: visit + activity + activity-derived path + timelinePath.
        XCTAssertEqual(summary.totalEntries, 4)
        XCTAssertTrue(phases.contains(.preparing), "expected preparing phase")
        XCTAssertTrue(phases.contains(.importing), "expected importing phase")
        XCTAssertTrue(phases.contains(.finalizing), "expected finalizing phase")
        XCTAssertEqual(phases.last, .completed)
        XCTAssertEqual(last?.phase, .completed)
        // Importer side counts 3 JSON entries (visit + activity + timelinePath).
        XCTAssertEqual(last?.entriesProcessed, 3)
        XCTAssertEqual(last?.visitsWritten, 1)
        XCTAssertEqual(last?.activitiesWritten, 1)
        XCTAssertEqual(last?.pathsWritten, 1)
        XCTAssertFalse(last?.isCancellable ?? true)
    }

    func testImporterCountsSkippedEntries() throws {
        let json = """
        [
          { "startTime": "2026-05-08T08:00:00Z",
            "visit": { "topCandidate": {
              "placeLocation": "geo:52.5,13.4", "semanticType": "HOME" } } },
          { "startTime": "2026-05-08T09:00:00Z",
            "timelinePath": [ { "point": "not-geo" } ] },
          { "startTime": "2026-05-08T10:00:00Z" },
          { "startTime": "2026-05-08T11:00:00Z",
            "activity": { "start": "geo:52.5,13.4", "end": "geo:52.51,13.41",
              "topCandidate": { "type": "WALKING" } } }
        ]
        """
        let store = try makeStore("skipped.sqlite")
        defer { store.close() }

        let recorder = Recorder()
        let hooks = GoogleTimelineStoreImporter.Hooks(
            progress: { recorder.record($0) },
            throttle: .init(entryStride: 1)
        )

        let summary = try GoogleTimelineStoreImporter.importFromData(
            Data(json.utf8), sourceFilename: "skipped.json",
            store: store, hooks: hooks)

        let last = recorder.lastSnapshot
        XCTAssertEqual(last?.phase, .completed)
        XCTAssertGreaterThanOrEqual(last?.skippedEntries ?? 0, 2)
        // Importer-side skips union with writer-side skips.
        XCTAssertGreaterThanOrEqual(last?.skippedEntries ?? 0, summary.skippedEntries)
    }

    func testImporterIsSilentWhenNoProgressSinkProvided() throws {
        let store = try makeStore("silent.sqlite")
        defer { store.close() }
        let summary = try GoogleTimelineStoreImporter.importFromData(
            Data(smallFixtureJSON().utf8),
            sourceFilename: "silent.json",
            store: store)
        XCTAssertEqual(summary.totalEntries, 4)
        XCTAssertEqual(summary.skippedEntries, 0)
    }

    // MARK: - Cancellation

    func testCancelBeforeImportLeavesEmptyStore() throws {
        let store = try makeStore("cancelpre.sqlite")
        defer { store.close() }

        let token = LocalTimelineImportCancellation()
        token.cancel()
        let hooks = GoogleTimelineStoreImporter.Hooks(cancellation: token)

        XCTAssertThrowsError(
            try GoogleTimelineStoreImporter.importFromData(
                Data(smallFixtureJSON().utf8),
                sourceFilename: "cancelpre.json",
                store: store, hooks: hooks)
        ) { err in
            XCTAssertEqual(err as? LocalTimelineImportCancellationError, .cancelled)
        }

        XCTAssertEqual(try store.countImports(), 0)
        XCTAssertEqual(try store.countVisits(), 0)
        XCTAssertEqual(try store.countActivities(), 0)
        XCTAssertEqual(try store.countPaths(), 0)
    }

    func testCancelMidStreamRollsBackTransaction() throws {
        var entries: [String] = []
        for i in 0..<50 {
            let h = String(format: "%02d", i % 24)
            entries.append("""
            { "startTime": "2026-05-08T\(h):00:00Z",
              "visit": { "topCandidate": {
                "placeLocation": "geo:52.5,13.4", "semanticType": "HOME" } } }
            """)
        }
        let json = "[" + entries.joined(separator: ",") + "]"

        let store = try makeStore("cancelmid.sqlite")
        defer { store.close() }

        let token = LocalTimelineImportCancellation()
        let hooks = GoogleTimelineStoreImporter.Hooks(
            progress: { snap in
                if snap.entriesProcessed >= 1 { token.cancel() }
            },
            throttle: .init(entryStride: 1),
            cancellation: token
        )

        XCTAssertThrowsError(
            try GoogleTimelineStoreImporter.importFromData(
                Data(json.utf8), sourceFilename: "cancelmid.json",
                store: store, hooks: hooks)
        ) { err in
            XCTAssertEqual(err as? LocalTimelineImportCancellationError, .cancelled)
        }

        XCTAssertEqual(try store.countImports(), 0,
                       "rolled-back transaction must leave no imports row")
        XCTAssertEqual(try store.countVisits(), 0,
                       "rolled-back transaction must leave no visits")
        XCTAssertEqual(try store.countActivities(), 0)
        XCTAssertEqual(try store.countPaths(), 0)
    }

    func testCancelEmitsCancelledTerminalSnapshot() throws {
        let store = try makeStore("cancelterm.sqlite")
        defer { store.close() }

        let token = LocalTimelineImportCancellation()
        token.cancel()

        let recorder = Recorder()
        let hooks = GoogleTimelineStoreImporter.Hooks(
            progress: { recorder.record($0) },
            throttle: .init(entryStride: 1),
            cancellation: token
        )

        _ = try? GoogleTimelineStoreImporter.importFromData(
            Data(smallFixtureJSON().utf8),
            sourceFilename: "cancelterm.json",
            store: store, hooks: hooks)

        let last = recorder.lastSnapshot
        XCTAssertEqual(last?.phase, .cancelled)
        XCTAssertFalse(last?.isCancellable ?? true)
    }

    func testCancellationIsIdempotentAcrossRetries() throws {
        let store = try makeStore("cancelidem.sqlite")
        defer { store.close() }

        let token = LocalTimelineImportCancellation()
        token.cancel()
        token.cancel()

        let hooks = GoogleTimelineStoreImporter.Hooks(cancellation: token)
        XCTAssertThrowsError(
            try GoogleTimelineStoreImporter.importFromData(
                Data(smallFixtureJSON().utf8),
                sourceFilename: "cancelidem.json",
                store: store, hooks: hooks))

        XCTAssertThrowsError(
            try GoogleTimelineStoreImporter.importFromData(
                Data(smallFixtureJSON().utf8),
                sourceFilename: "cancelidem2.json",
                store: store, hooks: hooks))
        XCTAssertEqual(try store.countImports(), 0)
    }
}
