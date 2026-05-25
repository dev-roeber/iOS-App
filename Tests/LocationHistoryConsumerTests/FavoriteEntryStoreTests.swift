import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Phase E (2026-05-25) — local FavoriteEntry model + persistence + legacy migration.
/// **No CloudKit reach** — Phase F will add the sync engine on top.
final class FavoriteEntryStoreTests: XCTestCase {

    // MARK: - FavoriteEntry Codable

    func testFavoriteEntryCodableRoundtrip() throws {
        let original = FavoriteEntry(
            favoriteID: FavoriteIDFactory.deterministicID(legacyID: "2024-04-12", itemKind: .day),
            legacyID: "2024-04-12",
            itemKind: .day,
            isFavorite: true,
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 2_000),
            deletedAt: nil
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(FavoriteEntry.self, from: data)

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.schemaVersion, FavoriteEntry.currentSchemaVersion)
    }

    func testFavoriteEntryHasNoSensitiveFields() throws {
        // Lock down the privacy promise from the Phase-E spec: the JSON
        // never carries coordinates, polylines, altitudes, place IDs,
        // bearer tokens, or raw payloads.
        let entry = FavoriteEntry(
            favoriteID: FavoriteIDFactory.deterministicID(legacyID: "2024-04-12", itemKind: .day),
            legacyID: "2024-04-12",
            itemKind: .day,
            isFavorite: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = String(data: try encoder.encode(entry), encoding: .utf8) ?? ""

        let forbidden = [
            "latitude", "longitude", "coordinate", "polyline",
            "altitude", "elevation", "verticalAccuracy", "placeID",
            "visitedPlace", "rawLocation", "filePath", "file://",
            "Bearer", "Authorization", "Token",
        ]
        for needle in forbidden {
            XCTAssertFalse(
                json.localizedCaseInsensitiveContains(needle),
                "FavoriteEntry JSON unexpectedly mentions \(needle): \(json)"
            )
        }
    }

    // MARK: - Deterministic favoriteID

    func testFavoriteIDFactoryIsDeterministic() {
        let id1 = FavoriteIDFactory.deterministicID(legacyID: "2024-04-12", itemKind: .day)
        let id2 = FavoriteIDFactory.deterministicID(legacyID: "2024-04-12", itemKind: .day)
        XCTAssertEqual(id1, id2)
    }

    func testFavoriteIDFactoryDiffersByLegacyIDAndKind() {
        let dayApr = FavoriteIDFactory.deterministicID(legacyID: "2024-04-12", itemKind: .day)
        let dayMay = FavoriteIDFactory.deterministicID(legacyID: "2024-05-12", itemKind: .day)
        XCTAssertNotEqual(dayApr, dayMay)
    }

    // MARK: - Disk persistence

    func testMissingFileReturnsEmptyStoreWhenNoLegacy() throws {
        let env = try TestEnvironment.make()
        defer { env.cleanup() }
        let store = FavoriteEntryStore(
            fileURL: env.fileURL,
            userDefaults: env.userDefaults,
            legacySource: { [] }
        )

        XCTAssertTrue(store.loadEntries().isEmpty)
        XCTAssertTrue(store.loadActiveDayIDs().isEmpty)
    }

    func testCorruptFileDoesNotCrashAndQuarantines() throws {
        let env = try TestEnvironment.make()
        defer { env.cleanup() }
        try "this is not valid json {".data(using: .utf8)!.write(to: env.fileURL)
        let store = FavoriteEntryStore(
            fileURL: env.fileURL,
            userDefaults: env.userDefaults,
            legacySource: { [] }
        )

        let entries = store.loadEntries()
        XCTAssertTrue(entries.isEmpty)
        // Quarantine renamed the corrupt file out of the way — the
        // primary fileURL must either be gone or hold a fresh empty envelope.
        if FileManager.default.fileExists(atPath: env.fileURL.path) {
            let data = try Data(contentsOf: env.fileURL)
            XCTAssertFalse(data.isEmpty)
        }
        let folder = env.fileURL.deletingLastPathComponent()
        let siblings = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        XCTAssertTrue(siblings.contains { $0.hasPrefix("favorite_entries.corrupt-") })
    }

    func testSetAndRemoveDayFavoritePersists() throws {
        let env = try TestEnvironment.make()
        defer { env.cleanup() }
        let store = FavoriteEntryStore(
            fileURL: env.fileURL,
            userDefaults: env.userDefaults,
            legacySource: { [] }
        )

        store.setDayFavorite("2024-06-01", isFavorite: true)
        XCTAssertTrue(store.contains(dayIdentifier: "2024-06-01"))
        XCTAssertEqual(store.loadActiveDayIDs(), ["2024-06-01"])

        // Re-instantiate to confirm the data survived a re-read.
        let reloaded = FavoriteEntryStore(
            fileURL: env.fileURL,
            userDefaults: env.userDefaults,
            legacySource: { [] }
        )
        XCTAssertTrue(reloaded.contains(dayIdentifier: "2024-06-01"))

        reloaded.setDayFavorite("2024-06-01", isFavorite: false)
        XCTAssertFalse(reloaded.contains(dayIdentifier: "2024-06-01"))

        // Tombstone is retained for future sync — entry stays on disk
        // with isFavorite=false and a deletedAt timestamp.
        let entriesAfterRemove = reloaded.loadEntries()
        let removed = entriesAfterRemove.first { $0.legacyID == "2024-06-01" }
        XCTAssertNotNil(removed?.deletedAt)
        XCTAssertFalse(removed?.isFavorite ?? true)
    }

    func testToggleDayFavoriteReturnsNewState() throws {
        let env = try TestEnvironment.make()
        defer { env.cleanup() }
        let store = FavoriteEntryStore(
            fileURL: env.fileURL,
            userDefaults: env.userDefaults,
            legacySource: { [] }
        )

        XCTAssertTrue(store.toggleDayFavorite("2024-07-04"))
        XCTAssertTrue(store.contains(dayIdentifier: "2024-07-04"))
        XCTAssertFalse(store.toggleDayFavorite("2024-07-04"))
        XCTAssertFalse(store.contains(dayIdentifier: "2024-07-04"))
    }

    // MARK: - Legacy migration (idempotent)

    func testLegacyMigrationImportsExistingDayFavoritesOnce() throws {
        let env = try TestEnvironment.make()
        defer { env.cleanup() }
        var legacyReads = 0
        let store = FavoriteEntryStore(
            fileURL: env.fileURL,
            userDefaults: env.userDefaults,
            legacySource: {
                legacyReads += 1
                return ["2024-01-01", "2024-02-02", "2024-03-03"]
            }
        )

        let entries = store.loadEntries()
        let ids = Set(entries.filter(\.isFavorite).map(\.legacyID))
        XCTAssertEqual(ids, ["2024-01-01", "2024-02-02", "2024-03-03"])
        XCTAssertEqual(entries.count, 3)
        XCTAssertTrue(env.userDefaults.bool(forKey: FavoriteEntryStore.legacyMigrationMarker))

        // Second read must not re-import.
        _ = store.loadEntries()
        XCTAssertEqual(legacyReads, 1)
    }

    func testLegacyMigrationIsIdempotentAcrossNewStoreInstances() throws {
        let env = try TestEnvironment.make()
        defer { env.cleanup() }
        let store1 = FavoriteEntryStore(
            fileURL: env.fileURL,
            userDefaults: env.userDefaults,
            legacySource: { ["2024-01-01"] }
        )
        _ = store1.loadEntries()
        XCTAssertTrue(env.userDefaults.bool(forKey: FavoriteEntryStore.legacyMigrationMarker))

        // User unstars the migrated favorite locally.
        store1.setDayFavorite("2024-01-01", isFavorite: false)

        // A fresh store on the same file/userDefaults must NOT re-import
        // the deleted favorite from legacy.
        let store2 = FavoriteEntryStore(
            fileURL: env.fileURL,
            userDefaults: env.userDefaults,
            legacySource: { ["2024-01-01"] }
        )
        XCTAssertFalse(store2.contains(dayIdentifier: "2024-01-01"))
    }

    func testMigrationWithEmptyLegacyProducesEmptyStoreAndMarker() throws {
        let env = try TestEnvironment.make()
        defer { env.cleanup() }
        let store = FavoriteEntryStore(
            fileURL: env.fileURL,
            userDefaults: env.userDefaults,
            legacySource: { [] }
        )

        XCTAssertTrue(store.loadEntries().isEmpty)
        XCTAssertTrue(env.userDefaults.bool(forKey: FavoriteEntryStore.legacyMigrationMarker))
    }

    // MARK: - Backward compatibility with existing DayFavoritesStore

    func testDayFavoritesStoreStillWorksUnchanged() {
        let suiteName = "FavoriteEntryStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        DayFavoritesStore.add(dayIdentifier: "2024-08-15", userDefaults: defaults)
        XCTAssertTrue(DayFavoritesStore.contains(dayIdentifier: "2024-08-15", userDefaults: defaults))
        XCTAssertEqual(DayFavoritesStore.load(userDefaults: defaults), ["2024-08-15"])
    }
}

// MARK: - Test environment helper

private struct TestEnvironment {
    let fileURL: URL
    let userDefaults: UserDefaults
    let suiteName: String

    static func make(file: StaticString = #file, line: UInt = #line) throws -> TestEnvironment {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("FavoriteEntryStoreTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let fileURL = folder.appendingPathComponent("favorite_entries.json")
        let suiteName = "FavoriteEntryStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return TestEnvironment(fileURL: fileURL, userDefaults: defaults, suiteName: suiteName)
    }

    func cleanup() {
        let folder = fileURL.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: folder)
        userDefaults.removePersistentDomain(forName: suiteName)
    }
}
