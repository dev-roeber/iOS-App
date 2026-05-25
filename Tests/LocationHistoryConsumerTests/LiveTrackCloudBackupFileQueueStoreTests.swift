import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Phase B — Tests für den file-basierten LiveTrack-CloudKit-Outbox-Store.
/// Validiert Roundtrip, Atomic-Write, Migration aus UserDefaults,
/// Idempotenz und (auf Darwin) das Backup-Exclusion-Flag.
final class LiveTrackCloudBackupFileQueueStoreTests: XCTestCase {

    // MARK: - Fixtures

    private var tempRoot: URL!
    private var fileURL: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiveTrackCloudBackupFileQueueStoreTests-\(UUID().uuidString)",
                                    isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        fileURL = tempRoot.appendingPathComponent("livetrack_queue.json", isDirectory: false)

        suiteName = "lt.cloud.outbox.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        // Frisch, falls eine vorherige Testsuite Reste hinterlassen hat.
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: tempRoot)
        try super.tearDownWithError()
    }

    // MARK: - Roundtrip

    func testSaveThenLoadReturnsSameEnvelopes() throws {
        let store = LiveTrackCloudBackupFileQueueStore(fileURL: fileURL, userDefaults: defaults)
        let envelopes = try [
            LiveTrackCloudSchema.makeEnvelope(for: makeTrack(points: 3), includePointBatches: true),
            LiveTrackCloudSchema.makeEnvelope(for: makeTrack(points: 1, start: Date(timeIntervalSince1970: 1_710_000_000)),
                                              includePointBatches: false)
        ]

        store.saveEnvelopes(envelopes)
        let reloaded = store.loadEnvelopes()

        XCTAssertEqual(reloaded.count, envelopes.count)
        XCTAssertEqual(reloaded.map(\.summary.id), envelopes.map(\.summary.id))
    }

    func testSaveCreatesExactlyOneJSONFileAtomically() throws {
        let store = LiveTrackCloudBackupFileQueueStore(fileURL: fileURL, userDefaults: defaults)
        let envelopes = try [
            LiveTrackCloudSchema.makeEnvelope(for: makeTrack(points: 2), includePointBatches: true)
        ]
        store.saveEnvelopes(envelopes)

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        // Nach atomic-write darf kein temporäres ".tmp"-Sibling stehenbleiben.
        let dirContents = try FileManager.default.contentsOfDirectory(atPath: fileURL.deletingLastPathComponent().path)
        let jsonFiles = dirContents.filter { $0.hasSuffix("livetrack_queue.json") }
        XCTAssertEqual(jsonFiles.count, 1)

        // Inhalt ist valides JSON.
        let raw = try Data(contentsOf: fileURL)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: raw))
    }

    // MARK: - Empty save löscht File

    func testEmptySaveRemovesFile() throws {
        let store = LiveTrackCloudBackupFileQueueStore(fileURL: fileURL, userDefaults: defaults)
        let envelopes = try [
            LiveTrackCloudSchema.makeEnvelope(for: makeTrack(points: 2), includePointBatches: true)
        ]
        store.saveEnvelopes(envelopes)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        store.saveEnvelopes([])
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertTrue(store.loadEnvelopes().isEmpty)
    }

    // MARK: - Migration aus UserDefaults

    func testLoadMigratesLegacyUserDefaultsEnvelopesAndClearsKey() throws {
        // Vorab: Legacy-Outbox via UserDefaults befüllen, KEINE Datei.
        let original = try [
            LiveTrackCloudSchema.makeEnvelope(for: makeTrack(points: 4), includePointBatches: true)
        ]
        let encoded = try Self.makeEncoder().encode(original)
        defaults.set(encoded, forKey: LiveTrackCloudBackupFileQueueStore.legacyUserDefaultsKey)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))

        let store = LiveTrackCloudBackupFileQueueStore(fileURL: fileURL, userDefaults: defaults)
        let loaded = store.loadEnvelopes()

        XCTAssertEqual(loaded.map(\.summary.id), original.map(\.summary.id))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path),
                      "Migration muss File persistieren")
        XCTAssertNil(defaults.data(forKey: LiveTrackCloudBackupFileQueueStore.legacyUserDefaultsKey),
                     "Legacy-Key muss nach Migration entfernt sein")
        XCTAssertTrue(defaults.bool(forKey: LiveTrackCloudBackupFileQueueStore.migrationMarkerKey),
                      "Marker muss gesetzt sein")
    }

    func testMigrationIsIdempotentOnSecondLoad() throws {
        // Erst-Migration durchführen.
        let original = try [
            LiveTrackCloudSchema.makeEnvelope(for: makeTrack(points: 2), includePointBatches: true)
        ]
        let encoded = try Self.makeEncoder().encode(original)
        defaults.set(encoded, forKey: LiveTrackCloudBackupFileQueueStore.legacyUserDefaultsKey)

        let store = LiveTrackCloudBackupFileQueueStore(fileURL: fileURL, userDefaults: defaults)
        _ = store.loadEnvelopes()
        XCTAssertNil(defaults.data(forKey: LiveTrackCloudBackupFileQueueStore.legacyUserDefaultsKey))
        let markerAfterFirst = defaults.bool(forKey: LiveTrackCloudBackupFileQueueStore.migrationMarkerKey)
        XCTAssertTrue(markerAfterFirst)

        // Provokation: jemand schreibt erneut etwas in den Legacy-Key.
        // Der zweite Load darf das NICHT mehr migrieren.
        let intruder = try Self.makeEncoder().encode([
            try LiveTrackCloudSchema.makeEnvelope(for: makeTrack(points: 9, start: Date(timeIntervalSince1970: 1_720_000_000)),
                                                  includePointBatches: false)
        ])
        defaults.set(intruder, forKey: LiveTrackCloudBackupFileQueueStore.legacyUserDefaultsKey)

        let store2 = LiveTrackCloudBackupFileQueueStore(fileURL: fileURL, userDefaults: defaults)
        let reloaded = store2.loadEnvelopes()
        XCTAssertEqual(reloaded.map(\.summary.id), original.map(\.summary.id),
                       "Nach abgeschlossener Migration darf der Legacy-Key nicht erneut konsultiert werden")
        // Legacy-Key bleibt unverändert (kein erneutes removeObject).
        XCTAssertNotNil(defaults.data(forKey: LiveTrackCloudBackupFileQueueStore.legacyUserDefaultsKey))
    }

    func testMigrationMarksDoneEvenWithoutLegacyData() {
        // Kein Legacy-Key gesetzt, keine Datei. loadEnvelopes() liefert [],
        // setzt aber den Marker, damit der Legacy-Pfad nicht erneut probiert wird.
        let store = LiveTrackCloudBackupFileQueueStore(fileURL: fileURL, userDefaults: defaults)
        XCTAssertTrue(store.loadEnvelopes().isEmpty)
        XCTAssertTrue(defaults.bool(forKey: LiveTrackCloudBackupFileQueueStore.migrationMarkerKey))
    }

    // MARK: - Backup-Exclusion (Darwin)

    func testFileIsMarkedExcludedFromBackupOnDarwin() throws {
        #if canImport(Darwin)
        let store = LiveTrackCloudBackupFileQueueStore(fileURL: fileURL, userDefaults: defaults)
        let envelopes = try [
            LiveTrackCloudSchema.makeEnvelope(for: makeTrack(points: 1), includePointBatches: true)
        ]
        store.saveEnvelopes(envelopes)

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        let excluded = try LocalTimelineFileAttributes.isExcludedFromBackup(url: fileURL)
        XCTAssertTrue(excluded, "Outbox-Datei muss aus dem Backup ausgeschlossen sein")
        #else
        throw XCTSkip("Backup-Exclusion ist eine Apple-Plattform-Eigenschaft")
        #endif
    }

    // MARK: - Helpers

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

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
