import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Prompt 2 — schließt die Verträge des LiveTrack Upload/Restore-Pfads fest:
/// Envelope-Reverse-Mapping, Restore-Service mit Dedupe, manueller Upload.
final class LiveTrackCloudRestoreTests: XCTestCase {

    // MARK: - Schema reverse-mapping

    func testDecodeRecordedTrackPreservesPointsAndDayKey() throws {
        let originalTrack = makeTrack(points: 5)
        let envelope = try LiveTrackCloudSchema.makeEnvelope(for: originalTrack, includePointBatches: true)
        let restored = try LiveTrackCloudSchema.decodeRecordedTrack(
            from: envelope,
            freshID: { UUID(uuidString: "11111111-1111-1111-1111-111111111111")! }
        )
        XCTAssertEqual(restored.id, UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        XCTAssertEqual(restored.points.count, 5)
        XCTAssertEqual(restored.startedAt, originalTrack.startedAt)
        XCTAssertEqual(restored.endedAt, originalTrack.endedAt)
        XCTAssertEqual(restored.distanceM, originalTrack.distanceM)
        XCTAssertEqual(restored.dayKey, LiveTrackCloudSchema.dayKey(from: originalTrack.startedAt))
    }

    func testDecodeRecordedTrackReassemblesBatchesInIndexOrder() throws {
        let original = makeTrack(points: 150) // → mehrere PointBatches (chunkSize 100)
        let envelope = try LiveTrackCloudSchema.makeEnvelope(for: original, includePointBatches: true)
        XCTAssertGreaterThan(envelope.pointBatches.count, 1)
        // Vertausche die Reihenfolge der Batches im Envelope, um zu zeigen,
        // dass decodeRecordedTrack stabil über batchIndex sortiert.
        let shuffled = LiveTrackCloudBackupEnvelope(
            summary: envelope.summary,
            pointBatches: envelope.pointBatches.reversed(),
            queuedAt: envelope.queuedAt
        )
        let restored = try LiveTrackCloudSchema.decodeRecordedTrack(from: shuffled)
        XCTAssertEqual(restored.points.count, original.points.count)
        // Zeitstempel-Reihenfolge muss monoton bleiben (Test-Fixture nutzt
        // monoton steigende Timestamps).
        let timestamps = restored.points.map(\.timestamp)
        XCTAssertEqual(timestamps, timestamps.sorted())
    }

    func testDecodeRecordedTrackThrowsForCorruptPointPayload() {
        var summary = LiveTrackCloudSummary.empty()
        summary.localTrackIDHash = "abc"
        summary.title = "x"
        summary.startedAt = Date(timeIntervalSince1970: 0)
        summary.endedAt = Date(timeIntervalSince1970: 1)
        var batch = LiveTrackCloudPointBatch.empty()
        batch.encodedPointsPayload = "!!!not-base64!!!"
        batch.batchIndex = 7
        let envelope = LiveTrackCloudBackupEnvelope(summary: summary, pointBatches: [batch])
        XCTAssertThrowsError(try LiveTrackCloudSchema.decodeRecordedTrack(from: envelope)) { error in
            XCTAssertEqual(error as? LiveTrackCloudRestoreError, .corruptPointPayload(batchIndex: 7))
        }
    }

    func testDecodeRecordedTrackThrowsWhenRequiredBatchIsMissing() throws {
        let original = makeTrack(points: 150)
        let envelope = try LiveTrackCloudSchema.makeEnvelope(for: original, includePointBatches: true)
        let incomplete = LiveTrackCloudBackupEnvelope(
            summary: envelope.summary,
            pointBatches: Array(envelope.pointBatches.prefix(1)),
            queuedAt: envelope.queuedAt
        )

        XCTAssertThrowsError(try LiveTrackCloudSchema.decodeRecordedTrack(from: incomplete)) { error in
            XCTAssertEqual(
                error as? LiveTrackCloudRestoreError,
                .incompletePointBatches(localTrackIDHash: envelope.summary.localTrackIDHash)
            )
        }
    }

    func testDecodeRecordedTrackThrowsWhenPointCountDoesNotMatchSummary() throws {
        let source = try LiveTrackCloudSchema.makeEnvelope(
            for: makeTrack(points: 1),
            includePointBatches: true
        )
        var summary = source.summary
        summary.pointCount = 2

        XCTAssertThrowsError(
            try LiveTrackCloudSchema.decodeRecordedTrack(
                from: LiveTrackCloudBackupEnvelope(summary: summary, pointBatches: source.pointBatches)
            )
        ) { error in
            XCTAssertEqual(error as? LiveTrackCloudRestoreError, .pointCountMismatch(expected: 2, actual: 1))
        }
    }

    func testDayKeyUsesUTC() {
        let date = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14 22:13:20 UTC
        XCTAssertEqual(LiveTrackCloudSchema.dayKey(from: date), "2023-11-14")
    }

    // MARK: - Restore service (Combine path)

    #if canImport(Combine)
    @MainActor
    func testRestoreServiceLoadsAvailableEnvelopesFromCoordinator() async throws {
        let coordinator = ScriptedRestoreCoordinator()
        coordinator.scriptedEnvelopes = [
            try LiveTrackCloudSchema.makeEnvelope(for: makeTrack(points: 3), includePointBatches: true)
        ]
        let store = RestoreTestRecordedTrackStore()
        let service = LiveTrackCloudRestoreService(coordinator: coordinator, trackStore: store)

        await service.loadAvailable()

        XCTAssertEqual(service.availableEnvelopes.count, 1)
        XCTAssertFalse(service.actionFailed)
        XCTAssertEqual(service.actionState, .idle)
        XCTAssertTrue((service.actionMessage ?? "").contains("geladen"))
    }

    @MainActor
    func testRestoreServiceWritesIntoTrackStore() async throws {
        let track = makeTrack(points: 4)
        let envelope = try LiveTrackCloudSchema.makeEnvelope(for: track, includePointBatches: true)
        let coordinator = ScriptedRestoreCoordinator()
        let store = RestoreTestRecordedTrackStore()
        let service = LiveTrackCloudRestoreService(coordinator: coordinator, trackStore: store)

        let outcome = await service.restore(envelope)

        XCTAssertNotNil(outcome)
        XCTAssertEqual(outcome?.pointCount, 4)
        XCTAssertEqual(store.savedTracks.count, 1)
        XCTAssertTrue((service.actionMessage ?? "").contains("wiederhergestellt"))
    }

    @MainActor
    func testRestoreServiceSkipsDuplicateByLocalHash() async throws {
        let track = makeTrack(points: 2)
        let envelope = try LiveTrackCloudSchema.makeEnvelope(for: track, includePointBatches: true)
        let store = RestoreTestRecordedTrackStore()
        // Vorbelege Store mit demselben Track (gleiche UUID → gleicher Hash).
        try store.saveTracks([track])
        let service = LiveTrackCloudRestoreService(
            coordinator: ScriptedRestoreCoordinator(),
            trackStore: store
        )

        let outcome = await service.restore(envelope)

        XCTAssertNil(outcome, "Doppelter Hash → kein neuer Restore")
        XCTAssertEqual(store.savedTracks.count, 1, "Store unverändert")
        XCTAssertTrue((service.actionMessage ?? "").contains("bereits"))
    }

    @MainActor
    func testRestoreServiceSkipsSecondRestoreInSameSession() async throws {
        let track = makeTrack(points: 2)
        let envelope = try LiveTrackCloudSchema.makeEnvelope(for: track, includePointBatches: true)
        let store = RestoreTestRecordedTrackStore()
        let service = LiveTrackCloudRestoreService(
            coordinator: ScriptedRestoreCoordinator(),
            trackStore: store
        )

        let first = await service.restore(envelope)
        let second = await service.restore(envelope)

        XCTAssertNotNil(first)
        XCTAssertNil(second)
        XCTAssertEqual(store.savedTracks.count, 1)
        XCTAssertTrue((service.actionMessage ?? "").contains("bereits"))
    }

    @MainActor
    func testRestoreServiceSkipsSecondRestoreAfterReload() async throws {
        let track = makeTrack(points: 2)
        let envelope = try LiveTrackCloudSchema.makeEnvelope(for: track, includePointBatches: true)
        let store = RestoreTestRecordedTrackStore()
        let suiteName = "LiveTrackCloudRestoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let service = LiveTrackCloudRestoreService(
            coordinator: ScriptedRestoreCoordinator(),
            trackStore: store,
            userDefaults: defaults
        )

        _ = await service.restore(envelope)
        let reloadedService = LiveTrackCloudRestoreService(
            coordinator: ScriptedRestoreCoordinator(),
            trackStore: store,
            userDefaults: defaults
        )
        let second = await reloadedService.restore(envelope)

        XCTAssertNil(second)
        XCTAssertEqual(store.savedTracks.count, 1)
    }

    @MainActor
    func testRestoreServiceLoadFailureShowsErrorMessage() async {
        let coordinator = ScriptedRestoreCoordinator()
        coordinator.scriptedLoadError = NSError(
            domain: "test", code: 42,
            userInfo: [NSLocalizedDescriptionKey: "Cloud-Fehler"]
        )
        let service = LiveTrackCloudRestoreService(
            coordinator: coordinator,
            trackStore: RestoreTestRecordedTrackStore()
        )
        await service.loadAvailable()
        XCTAssertTrue(service.actionFailed)
        XCTAssertTrue((service.actionMessage ?? "").contains("Cloud-Fehler"))
    }

    @MainActor
    func testRestoreServiceUploadsLatestLocalTrack() async throws {
        let older = makeTrack(points: 1, start: Date(timeIntervalSince1970: 1_600_000_000))
        let latest = makeTrack(points: 3, start: Date(timeIntervalSince1970: 1_700_000_000))
        let coordinator = ScriptedRestoreCoordinator()
        let store = RestoreTestRecordedTrackStore(initialTracks: [older, latest])
        let service = LiveTrackCloudRestoreService(coordinator: coordinator, trackStore: store)

        await service.uploadLatestLocalTrack(includePointBatches: true)

        XCTAssertEqual(coordinator.manualUploadCount, 1)
        XCTAssertEqual(coordinator.lastUploadedTrackID, latest.id)
        XCTAssertTrue((service.actionMessage ?? "").contains("abgeschlossen"))
    }

    @MainActor
    func testRestoreServiceUploadLatestShowsNoLocalTrackMessage() async {
        let coordinator = ScriptedRestoreCoordinator()
        let service = LiveTrackCloudRestoreService(
            coordinator: coordinator,
            trackStore: RestoreTestRecordedTrackStore()
        )

        await service.uploadLatestLocalTrack(includePointBatches: true)

        XCTAssertEqual(coordinator.manualUploadCount, 0)
        XCTAssertTrue((service.actionMessage ?? "").contains("Kein lokaler LiveTrack"))
    }
    #endif

    // MARK: - Manual upload

    @MainActor
    func testManualUploadThroughBackupServicePassesHealthGateAndCallsUploader() async throws {
        let uploader = SpyUploadingBackupUploader()
        let service = LiveTrackCloudBackupService(
            settingsProvider: {
                LiveTrackCloudBackupSettings(
                    iCloudSyncEnabled: false, // Auto-Backup explizit AUS
                    liveTrackMetadataEnabled: false,
                    automaticLiveTrackBackupEnabled: false,
                    allowCellular: true
                )
            },
            uploader: uploader,
            healthGate: { true }
        )
        try await service.uploadManually(makeTrack(points: 2), includePointBatches: true)
        let uploadCount = await uploader.uploadCount
        XCTAssertEqual(uploadCount, 1)
    }

    @MainActor
    func testManualUploadRespectsHealthGate() async {
        let uploader = SpyUploadingBackupUploader()
        let service = LiveTrackCloudBackupService(
            settingsProvider: {
                LiveTrackCloudBackupSettings(
                    iCloudSyncEnabled: true,
                    liveTrackMetadataEnabled: true,
                    automaticLiveTrackBackupEnabled: true,
                    allowCellular: true
                )
            },
            uploader: uploader,
            healthGate: { false }
        )
        do {
            try await service.uploadManually(makeTrack(points: 1), includePointBatches: false)
            XCTFail("Expected health-gate failure")
        } catch {
            XCTAssertEqual(error as? LiveTrackManualUploadError, .healthGateClosed)
        }
        let uploadCount = await uploader.uploadCount
        XCTAssertEqual(uploadCount, 0)
    }

    // MARK: - Helpers

    private func makeTrack(
        points: Int,
        start: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> RecordedTrack {
        let pts = (0..<points).map { i in
            RecordedTrackPoint(
                latitude: 52.5 + Double(i) * 0.0001,
                longitude: 13.4 + Double(i) * 0.0001,
                timestamp: start.addingTimeInterval(Double(i)),
                horizontalAccuracyM: 5.0
            )
        }
        return RecordedTrack(
            startedAt: start,
            endedAt: start.addingTimeInterval(Double(points)),
            dayKey: "2023-11-14",
            distanceM: Double(points) * 10,
            captureMode: .foregroundWhileInUse,
            points: pts
        )
    }
}

#if canImport(Combine)
@MainActor
private final class ScriptedRestoreCoordinator: LiveTrackCloudBackupCoordinator {
    var overview: ICloudStorageOverview = .init()
    var pendingCount: Int = 0
    var scriptedEnvelopes: [LiveTrackCloudBackupEnvelope] = []
    var scriptedLoadError: Error?
    private(set) var manualUploadCount = 0
    private(set) var lastUploadedTrackID: UUID?

    func handleCompletedLiveTrack(_ track: RecordedTrack) {}
    func retryPendingBackups() async {}
    func refreshOverview() async -> ICloudStorageOverview { overview }
    func deleteCloudData() async throws {}
    func uploadManually(_ track: RecordedTrack, includePointBatches: Bool) async throws {
        manualUploadCount += 1
        lastUploadedTrackID = track.id
    }

    func fetchRestorableEnvelopes() async throws -> [LiveTrackCloudBackupEnvelope] {
        if let error = scriptedLoadError { throw error }
        return scriptedEnvelopes
    }
}
#endif

private final class RestoreTestRecordedTrackStore: RecordedTrackStoring {
    private(set) var savedTracks: [RecordedTrack]
    init(initialTracks: [RecordedTrack] = []) {
        self.savedTracks = initialTracks
    }
    func loadTracks() throws -> [RecordedTrack] { savedTracks }
    func saveTracks(_ tracks: [RecordedTrack]) throws { savedTracks = tracks }
}

private actor SpyUploadCounter {
    private var value = 0
    func increment() { value += 1 }
    var count: Int { value }
}

private final class SpyUploadingBackupUploader: LiveTrackCloudBackupUploading, @unchecked Sendable {
    private let counter = SpyUploadCounter()
    var uploadCount: Int {
        get async { await counter.count }
    }
    func upload(_ envelope: LiveTrackCloudBackupEnvelope) async throws {
        await counter.increment()
    }
    func fetchOverview() async throws -> ICloudStorageOverview { .init() }
    func deleteCloudData() async throws {}
    func fetchAllEnvelopes() async throws -> [LiveTrackCloudBackupEnvelope] { [] }
}
