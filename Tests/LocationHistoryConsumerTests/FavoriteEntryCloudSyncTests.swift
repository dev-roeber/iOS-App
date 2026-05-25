import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Phase F — schließt die Verträge des FavoriteEntry-CloudKit-Sync fest:
/// Schema-Konstanten, Merge-Regel (jüngeres updatedAt gewinnt), Mock-
/// Cloud push/pull/delete, idempotente Sync-Calls.
final class FavoriteEntryCloudSyncTests: XCTestCase {

    // MARK: - Schema

    func testSchemaRecordTypeAndFieldsAreStable() {
        XCTAssertEqual(CloudKitFavoriteEntrySchema.recordType, "LH2GPXFavoriteEntry")
        XCTAssertEqual(CloudKitFavoriteEntrySchema.schemaVersion, 1)
        XCTAssertEqual(CloudKitFavoriteEntrySchema.Field.favoriteID, "favoriteID")
        XCTAssertEqual(CloudKitFavoriteEntrySchema.Field.legacyID, "legacyID")
        XCTAssertEqual(CloudKitFavoriteEntrySchema.Field.isFavorite, "isFavorite")
    }

    func testRecordNameIsDeterministicFromFavoriteID() {
        let id = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let entry = FavoriteEntry(
            favoriteID: id, legacyID: "2026-05-25", itemKind: .day,
            isFavorite: true, createdAt: Date(), updatedAt: Date()
        )
        XCTAssertEqual(CloudKitFavoriteEntrySchema.recordName(for: entry),
                       "favorite-11111111-1111-1111-1111-111111111111")
    }

    // MARK: - Merge logic (pure)

    #if canImport(Combine)
    func testMergeKeepsNewerUpdatedAtPerFavoriteID() {
        let id = UUID()
        let older = FavoriteEntry(favoriteID: id, legacyID: "x", itemKind: .day,
                                  isFavorite: true,
                                  createdAt: Date(timeIntervalSince1970: 0),
                                  updatedAt: Date(timeIntervalSince1970: 100))
        let newer = FavoriteEntry(favoriteID: id, legacyID: "x", itemKind: .day,
                                  isFavorite: false,
                                  createdAt: Date(timeIntervalSince1970: 0),
                                  updatedAt: Date(timeIntervalSince1970: 200))
        let merged = FavoriteEntryCloudSyncCoordinator.merge(local: [older], cloud: [newer])
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.isFavorite, false)
    }

    func testMergeAddsCloudOnlyEntries() {
        let local = FavoriteEntry(
            favoriteID: UUID(), legacyID: "a", itemKind: .day,
            isFavorite: true,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let cloudOnly = FavoriteEntry(
            favoriteID: UUID(), legacyID: "b", itemKind: .day,
            isFavorite: true,
            createdAt: Date(timeIntervalSince1970: 200),
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        let merged = FavoriteEntryCloudSyncCoordinator.merge(local: [local], cloud: [cloudOnly])
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(Set(merged.map(\.legacyID)), Set(["a", "b"]))
    }

    func testMergeKeepsLocalWhenNewer() {
        let id = UUID()
        let local = FavoriteEntry(favoriteID: id, legacyID: "x", itemKind: .day,
                                  isFavorite: true,
                                  createdAt: Date(timeIntervalSince1970: 0),
                                  updatedAt: Date(timeIntervalSince1970: 300))
        let cloudOlder = FavoriteEntry(favoriteID: id, legacyID: "x", itemKind: .day,
                                       isFavorite: false,
                                       createdAt: Date(timeIntervalSince1970: 0),
                                       updatedAt: Date(timeIntervalSince1970: 100))
        let merged = FavoriteEntryCloudSyncCoordinator.merge(local: [local], cloud: [cloudOlder])
        XCTAssertEqual(merged.first?.isFavorite, true)
    }
    #endif

    // MARK: - In-memory cloud

    func testInMemoryCloudPushPullDeleteRoundtrip() async throws {
        let cloud = InMemoryFavoriteEntryCloudSync()
        let entry = FavoriteEntry(
            favoriteID: UUID(), legacyID: "2026-05-25", itemKind: .day,
            isFavorite: true, createdAt: Date(), updatedAt: Date()
        )
        try await cloud.push([entry])
        let pulled = try await cloud.pull()
        XCTAssertEqual(pulled.count, 1)
        XCTAssertEqual(pulled.first?.favoriteID, entry.favoriteID)

        try await cloud.delete(entry)
        let afterDelete = try await cloud.pull()
        XCTAssertEqual(afterDelete.count, 0)
    }

    // MARK: - Per-record failure handling

    /// Mock, der beim N-ten Pull-Eintrag einen harten Fehler simuliert,
    /// indem `pull()` direkt `FavoriteEntryCloudSyncError.partialFetchFailure`
    /// wirft. Erlaubt Coordinator-Tests ohne CloudKit-Pfad.
    final class MockFailingFavoriteEntryCloudSync: FavoriteEntryCloudSyncing, @unchecked Sendable {
        let pullError: Error
        init(pullError: Error) { self.pullError = pullError }
        func push(_ entries: [FavoriteEntry]) async throws {}
        func pull() async throws -> [FavoriteEntry] { throw pullError }
        func delete(_ entry: FavoriteEntry) async throws {}
        func deleteAll() async throws {}
    }

    func testPartialFetchFailureErrorCarriesCountAndFirstError() {
        let underlying = NSError(domain: "CKErrorDomain", code: 2,
                                 userInfo: [NSLocalizedDescriptionKey: "boom"])
        let err = FavoriteEntryCloudSyncError.partialFetchFailure(
            failedRecordCount: 3, firstError: underlying
        )
        switch err {
        case .partialFetchFailure(let count, let first):
            XCTAssertEqual(count, 3)
            XCTAssertEqual(first.domain, "CKErrorDomain")
            XCTAssertEqual(first.code, 2)
        }
    }

    #if canImport(Combine)
    @MainActor
    func testCoordinatorReportsFailureWhenPullThrowsPartialFetchFailure() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("fav-store-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmp) }
        let defaults = UserDefaults(suiteName: "fav-cloud-test-\(UUID().uuidString)")!
        let store = FavoriteEntryStore(
            fileURL: tmp,
            userDefaults: defaults,
            legacySource: { [] }
        )
        let underlying = NSError(domain: "CKErrorDomain", code: 2,
                                 userInfo: [NSLocalizedDescriptionKey: "boom"])
        let cloud = MockFailingFavoriteEntryCloudSync(
            pullError: FavoriteEntryCloudSyncError.partialFetchFailure(
                failedRecordCount: 1, firstError: underlying
            )
        )
        let coordinator = FavoriteEntryCloudSyncCoordinator(store: store, cloud: cloud)
        await coordinator.sync()
        XCTAssertTrue(coordinator.actionFailed)
        XCTAssertNil(coordinator.lastSyncAt)
        XCTAssertNotNil(coordinator.actionMessage)
    }
    #endif

    func testInMemoryCloudDeleteAllClearsStorage() async throws {
        let cloud = InMemoryFavoriteEntryCloudSync()
        let entries = (0..<3).map { i in
            FavoriteEntry(
                favoriteID: UUID(), legacyID: "id-\(i)", itemKind: .day,
                isFavorite: true, createdAt: Date(), updatedAt: Date()
            )
        }
        try await cloud.push(entries)
        let beforeDelete = try await cloud.pull()
        XCTAssertEqual(beforeDelete.count, 3)
        try await cloud.deleteAll()
        let afterDelete = try await cloud.pull()
        XCTAssertEqual(afterDelete.count, 0)
    }
}
