import XCTest
@testable import LocationHistoryConsumerAppSupport

final class ICloudCloudKitMVPTests: XCTestCase {
    @MainActor
    func testHealthCheckDisabledDoesNotProbePrivateDatabase() async {
        let service = InMemoryICloudHealthCheckService(
            scriptedResult: ICloudHealthStatus(
                accountStatus: .available,
                privateDatabaseReachability: .reachable,
                lastProbeResult: ICloudHealthProbeResult(
                    writeSucceeded: true,
                    readSucceeded: true,
                    deleteSucceeded: true
                )
            )
        )

        let status = await service.runHealthCheck(isEnabled: false)

        XCTAssertEqual(status.accountStatus, .disabled)
        XCTAssertEqual(status.privateDatabaseReachability, .notChecked)
        XCTAssertNil(status.lastProbeResult)
    }

    @MainActor
    func testHealthCheckSuccessExposesWriteReadDeleteResult() async {
        let probe = ICloudHealthProbeResult(
            checkedAt: Date(timeIntervalSince1970: 1_000),
            writeSucceeded: true,
            readSucceeded: true,
            deleteSucceeded: true,
            durationSeconds: 0.42
        )
        let service = InMemoryICloudHealthCheckService(
            scriptedResult: ICloudHealthStatus(
                accountStatus: .available,
                privateDatabaseReachability: .reachable,
                lastProbeResult: probe
            )
        )

        let status = await service.runHealthCheck(isEnabled: true)

        XCTAssertEqual(status.accountStatus, .available)
        XCTAssertEqual(status.privateDatabaseReachability, .reachable)
        XCTAssertEqual(status.lastProbeResult, probe)
        XCTAssertEqual(status.userFacingStatusKey, "Privater CloudKit-Bereich erreichbar")
    }

    @MainActor
    func testICloudSettingsDefaultsAreConservative() {
        let suiteName = "ICloudCloudKitMVPTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = AppPreferences(userDefaults: defaults)

        XCTAssertFalse(preferences.iCloudSyncEnabled)
        XCTAssertFalse(preferences.syncLiveTrackMetadataEnabled)
        XCTAssertFalse(preferences.syncLiveTrackPointBatchesEnabled)
        XCTAssertFalse(preferences.syncAppSettingsEnabled)
        XCTAssertFalse(preferences.syncExportHintsEnabled)
        XCTAssertFalse(preferences.automaticLiveTrackICloudBackupEnabled)
        XCTAssertFalse(preferences.iCloudSyncAllowCellular)
        XCTAssertEqual(preferences.iCloudSyncConflictPolicy, .manual)
        XCTAssertFalse(preferences.liveTrackCloudBackupSettings.canQueueCompletedLiveTrack)
    }

    @MainActor
    func testICloudSettingsPersistAndReset() {
        let suiteName = "ICloudCloudKitMVPTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var preferences = AppPreferences(userDefaults: defaults)
        preferences.iCloudSyncEnabled = true
        preferences.syncLiveTrackMetadataEnabled = true
        preferences.syncLiveTrackPointBatchesEnabled = true
        preferences.syncAppSettingsEnabled = true
        preferences.syncExportHintsEnabled = true
        preferences.automaticLiveTrackICloudBackupEnabled = true
        preferences.iCloudSyncAllowCellular = true
        preferences.iCloudSyncConflictPolicy = .preferLocal

        preferences = AppPreferences(userDefaults: defaults)

        XCTAssertTrue(preferences.iCloudSyncEnabled)
        XCTAssertTrue(preferences.syncLiveTrackMetadataEnabled)
        XCTAssertTrue(preferences.syncLiveTrackPointBatchesEnabled)
        XCTAssertTrue(preferences.syncAppSettingsEnabled)
        XCTAssertTrue(preferences.syncExportHintsEnabled)
        XCTAssertTrue(preferences.automaticLiveTrackICloudBackupEnabled)
        XCTAssertTrue(preferences.iCloudSyncAllowCellular)
        XCTAssertEqual(preferences.iCloudSyncConflictPolicy, .preferLocal)
        XCTAssertTrue(preferences.liveTrackCloudBackupSettings.canQueueCompletedLiveTrack)

        preferences.reset()

        XCTAssertFalse(preferences.iCloudSyncEnabled)
        XCTAssertFalse(preferences.syncLiveTrackMetadataEnabled)
        XCTAssertFalse(preferences.syncLiveTrackPointBatchesEnabled)
        XCTAssertFalse(preferences.syncAppSettingsEnabled)
        XCTAssertFalse(preferences.syncExportHintsEnabled)
        XCTAssertFalse(preferences.automaticLiveTrackICloudBackupEnabled)
        XCTAssertFalse(preferences.iCloudSyncAllowCellular)
        XCTAssertEqual(preferences.iCloudSyncConflictPolicy, .manual)
    }

    func testCellularPolicyBlocksUploadWhenDisabled() {
        let settings = LiveTrackCloudBackupSettings(
            iCloudSyncEnabled: true,
            liveTrackMetadataEnabled: true,
            automaticLiveTrackBackupEnabled: true,
            allowCellular: false
        )

        XCTAssertFalse(LiveTrackCloudBackupPolicy.allowsUpload(settings: settings, networkInterface: .cellular))
        XCTAssertTrue(LiveTrackCloudBackupPolicy.allowsUpload(settings: settings, networkInterface: .wifiOrWired))
    }

    func testCloudSummaryDoesNotContainCoordinates() throws {
        let track = Self.makeTrack()
        let envelope = try LiveTrackCloudSchema.makeEnvelope(for: track, includePointBatches: false)
        let encoded = String(data: try JSONEncoder().encode(envelope.summary), encoding: .utf8) ?? ""

        XCTAssertFalse(encoded.contains("latitude"))
        XCTAssertFalse(encoded.contains("longitude"))
        XCTAssertFalse(encoded.contains("coordinate"))
        XCTAssertEqual(envelope.summary.localTrackIDHash.count, 16)
        XCTAssertTrue(envelope.pointBatches.isEmpty)
    }

    func testPointBatchRequiresExplicitPointSyncAndDoesNotInventAltitude() throws {
        let track = Self.makeTrack(
            points: [
                RecordedTrackPoint(
                    latitude: 52.52,
                    longitude: 13.4,
                    timestamp: Date(timeIntervalSince1970: 1_000),
                    horizontalAccuracyM: 5,
                    altitudeM: 0,
                    verticalAccuracyM: -1
                ),
            ]
        )

        let withoutPoints = try LiveTrackCloudSchema.makeEnvelope(for: track, includePointBatches: false)
        let withPoints = try LiveTrackCloudSchema.makeEnvelope(for: track, includePointBatches: true)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(
            [LiveTrackCloudPointPayload].self,
            from: Data(base64Encoded: withPoints.pointBatches[0].encodedPointsPayload)!
        )

        XCTAssertTrue(withoutPoints.pointBatches.isEmpty)
        XCTAssertEqual(withPoints.pointBatches.count, 1)
        XCTAssertNil(decoded[0].altitudeM)
        XCTAssertNil(decoded[0].verticalAccuracyM)
    }

    @MainActor
    func testBackupServiceQueuesOnlyWithOptInAndDeduplicatesTrackIDs() {
        let store = InMemoryLiveTrackCloudBackupQueueStore()
        var settings = LiveTrackCloudBackupSettings()
        let service = LiveTrackCloudBackupService(
            settingsProvider: { settings },
            queueStore: store,
            uploader: FailingBackupUploader(),
            networkInterfaceProvider: { .wifiOrWired }
        )
        let track = Self.makeTrack()

        service.handleCompletedLiveTrack(track)
        XCTAssertTrue(store.envelopes.isEmpty)

        settings = LiveTrackCloudBackupSettings(
            iCloudSyncEnabled: true,
            liveTrackMetadataEnabled: true,
            automaticLiveTrackBackupEnabled: true
        )
        service.handleCompletedLiveTrack(track)
        service.handleCompletedLiveTrack(track)

        XCTAssertEqual(store.envelopes.count, 1)
        XCTAssertEqual(store.envelopes[0].summary.id, track.id)
    }

    @MainActor
    func testLiveLocationFeatureModelCallsCloudBackupOnlyAfterCompletedTrackPersists() {
        let client = MockLiveLocationClient(authorization: .authorizedWhenInUse)
        let store = InMemoryRecordedTrackStore()
        let backup = SpyLiveTrackCloudBackupCoordinator()
        let model = LiveLocationFeatureModel(client: client, store: store, cloudBackup: backup)

        model.setRecordingEnabled(true)
        client.emitLocationSamples([
            Self.sample(offsetSeconds: 0, latitude: 52.52, longitude: 13.40),
            Self.sample(offsetSeconds: 12, latitude: 52.5203, longitude: 13.4003),
        ])
        model.setRecordingEnabled(false)

        XCTAssertEqual(store.savedTracks.count, 1)
        XCTAssertEqual(backup.completedTrackIDs, [store.savedTracks[0].id])
    }

    private static func makeTrack(
        points: [RecordedTrackPoint] = [
            RecordedTrackPoint(
                latitude: 52.52,
                longitude: 13.4,
                timestamp: Date(timeIntervalSince1970: 1_000),
                horizontalAccuracyM: 5
            ),
            RecordedTrackPoint(
                latitude: 52.521,
                longitude: 13.401,
                timestamp: Date(timeIntervalSince1970: 1_030),
                horizontalAccuracyM: 5
            ),
        ]
    ) -> RecordedTrack {
        RecordedTrack(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            startedAt: points.first?.timestamp ?? Date(timeIntervalSince1970: 1_000),
            endedAt: points.last?.timestamp ?? Date(timeIntervalSince1970: 1_030),
            dayKey: "2026-05-25",
            distanceM: 140,
            captureMode: .foregroundWhileInUse,
            points: points
        )
    }

    private static func sample(offsetSeconds: TimeInterval, latitude: Double, longitude: Double) -> LiveLocationSample {
        LiveLocationSample(
            latitude: latitude,
            longitude: longitude,
            timestamp: Date(timeIntervalSince1970: 1_000 + offsetSeconds),
            horizontalAccuracyM: 5
        )
    }
}

private struct FailingBackupUploader: LiveTrackCloudBackupUploading {
    func upload(_ envelope: LiveTrackCloudBackupEnvelope) async throws {
        throw NSError(domain: "test", code: 1)
    }

    func fetchOverview() async throws -> ICloudStorageOverview { .init() }
    func deleteCloudData() async throws {}
}

@MainActor
private final class SpyLiveTrackCloudBackupCoordinator: LiveTrackCloudBackupCoordinator {
    var overview = ICloudStorageOverview()
    var pendingCount = 0
    private(set) var completedTrackIDs: [UUID] = []

    func handleCompletedLiveTrack(_ track: RecordedTrack) {
        completedTrackIDs.append(track.id)
    }

    func retryPendingBackups() async {}
    func refreshOverview() async -> ICloudStorageOverview { overview }
    func deleteCloudData() async throws {}
}
