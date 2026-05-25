import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Phase D.2 — locks down the stage-granular Health-Probe semantics:
/// `writeSucceeded` / `readSucceeded` / `deleteSucceeded` reflect the
/// exact stage that failed, the `errorStage` enum pinpoints which one,
/// and the `ckErrorCodeName` / German hint mapping does not hide a
/// raw `CKError.Code` behind a generic „Schreiben fehlgeschlagen".
final class ICloudHealthStageMappingTests: XCTestCase {

    // MARK: - ICloudCKErrorMapping (rawCode → codeName + German hint)

    func testCKErrorMappingPermissionFailure() {
        let mapping = ICloudCKErrorMapping.mapping(forRawCode: 10)
        XCTAssertEqual(mapping.codeName, "permissionFailure")
        XCTAssertTrue(mapping.germanHint.contains("Entitlement"))
    }

    func testCKErrorMappingBadContainer() {
        let mapping = ICloudCKErrorMapping.mapping(forRawCode: 5)
        XCTAssertEqual(mapping.codeName, "badContainer")
        XCTAssertTrue(mapping.germanHint.contains("Container"))
    }

    func testCKErrorMappingNotAuthenticated() {
        let mapping = ICloudCKErrorMapping.mapping(forRawCode: 9)
        XCTAssertEqual(mapping.codeName, "notAuthenticated")
        XCTAssertTrue(mapping.germanHint.contains("iCloud"))
    }

    func testCKErrorMappingNetworkUnavailableAndFailure() {
        XCTAssertEqual(ICloudCKErrorMapping.mapping(forRawCode: 3).codeName, "networkUnavailable")
        XCTAssertEqual(ICloudCKErrorMapping.mapping(forRawCode: 4).codeName, "networkFailure")
    }

    func testCKErrorMappingQuotaExceeded() {
        let mapping = ICloudCKErrorMapping.mapping(forRawCode: 25)
        XCTAssertEqual(mapping.codeName, "quotaExceeded")
        XCTAssertTrue(mapping.germanHint.contains("Speicher"))
    }

    func testCKErrorMappingServerRejectedRequest() {
        let mapping = ICloudCKErrorMapping.mapping(forRawCode: 15)
        XCTAssertEqual(mapping.codeName, "serverRejectedRequest")
        XCTAssertTrue(mapping.germanHint.contains("Schema") || mapping.germanHint.contains("Container"))
    }

    func testCKErrorMappingUnknownItemPointsAtSchemaDeploy() {
        let mapping = ICloudCKErrorMapping.mapping(forRawCode: 11)
        XCTAssertEqual(mapping.codeName, "unknownItem")
        XCTAssertTrue(mapping.germanHint.contains("Production-Schema"))
    }

    func testCKErrorMappingUnknownCodeFallsBack() {
        let mapping = ICloudCKErrorMapping.mapping(forRawCode: 9999)
        XCTAssertEqual(mapping.codeName, "ckError9999")
        XCTAssertEqual(mapping.germanHint, "Unbekannter CloudKit-Fehler.")
    }

    // MARK: - ICloudHealthProbeResult Codable backward-compat

    func testProbeResultDecodesPreD2JSONWithoutErrorStage() throws {
        // Simulate a pre-D.2 JSON document (no errorStage/ckErrorCodeName
        // /retryAfterSeconds fields) — the decoder must succeed and leave
        // the new fields as `nil`.
        let json = """
        {
          "checkedAt": "2026-05-25T08:00:00Z",
          "writeSucceeded": false,
          "readSucceeded": false,
          "deleteSucceeded": false,
          "durationSeconds": 0.5,
          "errorCode": "10",
          "errorMessage": "old generic message"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let result = try decoder.decode(ICloudHealthProbeResult.self, from: json)

        XCTAssertEqual(result.errorCode, "10")
        XCTAssertEqual(result.errorMessage, "old generic message")
        XCTAssertNil(result.errorStage)
        XCTAssertNil(result.ckErrorCodeName)
        XCTAssertNil(result.retryAfterSeconds)
    }

    func testProbeResultRoundtripsAllD2Fields() throws {
        let original = ICloudHealthProbeResult(
            checkedAt: Date(timeIntervalSince1970: 1_700_000_000),
            writeSucceeded: true,
            readSucceeded: false,
            deleteSucceeded: false,
            durationSeconds: 1.234,
            errorCode: "11",
            errorMessage: "Production-Schema im CloudKit-Dashboard deployen.",
            errorStage: .read,
            ckErrorCodeName: "unknownItem",
            retryAfterSeconds: 30.0
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(original)
        let roundtrip = try decoder.decode(ICloudHealthProbeResult.self, from: data)

        XCTAssertEqual(roundtrip, original)
    }

    // MARK: - ICloudHealthStatus convenience accessors

    func testHealthStatusIsOperationalRequiresAvailableAndReachable() {
        XCTAssertTrue(ICloudHealthStatus(
            accountStatus: .available,
            privateDatabaseReachability: .reachable
        ).isOperational)

        XCTAssertFalse(ICloudHealthStatus(
            accountStatus: .available,
            privateDatabaseReachability: .failed
        ).isOperational)

        XCTAssertFalse(ICloudHealthStatus(
            accountStatus: .signedOut,
            privateDatabaseReachability: .reachable
        ).isOperational)

        XCTAssertFalse(ICloudHealthStatus(
            accountStatus: .disabled,
            privateDatabaseReachability: .notChecked
        ).isOperational)
    }

    func testHealthStatusAccountAndPrivateDatabaseSummariesAreDistinct() {
        let status = ICloudHealthStatus(
            accountStatus: .available,
            privateDatabaseReachability: .failed
        )
        XCTAssertEqual(status.accountSummary, "iCloud-Konto verfügbar")
        XCTAssertEqual(status.privateDatabaseSummary, "CloudKit-Speicher nicht schreibbar")
    }

    // MARK: - Health-gated backup retry

    @MainActor
    func testBackupServiceSkipsRetryWhenHealthGateIsClosed() async {
        let store = InMemoryLiveTrackCloudBackupQueueStore(envelopes: [
            makeEnvelope(id: UUID()),
        ])
        let uploader = CountingBackupUploader()
        let service = LiveTrackCloudBackupService(
            settingsProvider: {
                LiveTrackCloudBackupSettings(
                    iCloudSyncEnabled: true,
                    liveTrackMetadataEnabled: true,
                    automaticLiveTrackBackupEnabled: true,
                    allowCellular: true
                )
            },
            queueStore: store,
            uploader: uploader,
            networkInterfaceProvider: { .wifiOrWired },
            healthGate: { false }
        )

        await service.retryPendingBackups()

        XCTAssertEqual(uploader.uploadCount, 0)
        XCTAssertEqual(store.envelopes.count, 1)
    }

    @MainActor
    func testBackupServiceRetriesWhenHealthGateOpen() async {
        let store = InMemoryLiveTrackCloudBackupQueueStore(envelopes: [
            makeEnvelope(id: UUID()),
        ])
        let uploader = CountingBackupUploader()
        let service = LiveTrackCloudBackupService(
            settingsProvider: {
                LiveTrackCloudBackupSettings(
                    iCloudSyncEnabled: true,
                    liveTrackMetadataEnabled: true,
                    automaticLiveTrackBackupEnabled: true,
                    allowCellular: true
                )
            },
            queueStore: store,
            uploader: uploader,
            networkInterfaceProvider: { .wifiOrWired },
            healthGate: { true }
        )

        await service.retryPendingBackups()

        XCTAssertEqual(uploader.uploadCount, 1)
        XCTAssertEqual(store.envelopes.count, 0)
    }

    // MARK: - Helpers

    private func makeEnvelope(id: UUID) -> LiveTrackCloudBackupEnvelope {
        let track = RecordedTrack(
            id: id,
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 1_030),
            dayKey: "2026-05-25",
            distanceM: 140,
            captureMode: .foregroundWhileInUse,
            points: []
        )
        // safe — empty point list, .includePointBatches false
        return (try? LiveTrackCloudSchema.makeEnvelope(for: track, includePointBatches: false))
            ?? LiveTrackCloudBackupEnvelope(
                summary: LiveTrackCloudSummary(track: track, includePointBatches: false),
                pointBatches: []
            )
    }
}

private final class CountingBackupUploader: LiveTrackCloudBackupUploading {
    private let lock = NSLock()
    private var _uploadCount = 0

    var uploadCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _uploadCount
    }

    func upload(_ envelope: LiveTrackCloudBackupEnvelope) async throws {
        lock.lock()
        _uploadCount += 1
        lock.unlock()
    }

    func fetchOverview() async throws -> ICloudStorageOverview { .init() }
    func deleteCloudData() async throws {}
}
