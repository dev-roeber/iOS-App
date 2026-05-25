import Foundation

/// Phase F — CloudKit-Schema für `FavoriteEntry`-Records über die
/// private CloudKit-Datenbank.
///
/// **Anti-Claim-Reset (Master-Train Phase F):** Ab diesem Schema sind
/// `CKQuery`/`save`/`fetch`/`delete` für `FavoriteEntry`-Records
/// erlaubt. History/Tracks/Koordinaten bleiben weiterhin **NICHT**
/// synchronisierbar — diese Datei adressiert ausschließlich
/// `FavoriteEntry`.
public enum CloudKitFavoriteEntrySchema {
    public static let recordType = "LH2GPXFavoriteEntry"
    public static let schemaVersion = 1

    public enum Field {
        public static let schemaVersion = "schemaVersion"
        public static let favoriteID = "favoriteID"
        public static let legacyID = "legacyID"
        public static let itemKind = "itemKind"
        public static let isFavorite = "isFavorite"
        public static let createdAt = "createdAt"
        public static let updatedAt = "updatedAt"
        public static let deletedAt = "deletedAt"
    }

    /// Stabiler Record-Name aus dem deterministischen `favoriteID` —
    /// derselbe Favorit liefert in jeder Umgebung denselben Record.
    public static func recordName(for entry: FavoriteEntry) -> String {
        "favorite-\(entry.favoriteID.uuidString)"
    }
}

/// Fehler-Typ für den FavoriteEntry-CloudKit-Sync. Wird geworfen,
/// wenn ein Pull zwar einzelne Records erfolgreich liefert, aber
/// mindestens ein per-record Fehler auftrat (anders als beim
/// idempotenten Top-Level-Skip). Sync gilt dann als nicht erfolgreich.
public enum FavoriteEntryCloudSyncError: Error {
    /// Mindestens ein Record konnte nicht gelesen werden. Enthält die
    /// Anzahl der harten per-record-Fehler sowie den ersten Fehler als
    /// `NSError` (CloudKit-Domain bleibt erhalten).
    case partialFetchFailure(failedRecordCount: Int, firstError: NSError)
}

/// Foundation-only Protokoll für den Favoriten-CloudKit-Sync. Erlaubt
/// Linux-Tests gegen Mock-Implementierung ohne `import CloudKit`.
public protocol FavoriteEntryCloudSyncing: Sendable {
    /// Lädt einen oder mehrere Einträge nach iCloud (upsert).
    func push(_ entries: [FavoriteEntry]) async throws

    /// Holt alle gespeicherten Favoriten-Records aus der Cloud.
    func pull() async throws -> [FavoriteEntry]

    /// Löscht einen Eintrag in der Cloud. Idempotent.
    func delete(_ entry: FavoriteEntry) async throws

    /// Löscht ALLE Favoriten-Records aus der Cloud. Wird vom „Cloud-
    /// Daten löschen"-Pfad in den iCloud-Optionen mit einbezogen.
    func deleteAll() async throws
}

/// Default-No-op-Impl. Wird verwendet, wenn iCloud-Sync deaktiviert
/// ist oder CloudKit auf der Plattform nicht verfügbar ist (Linux).
public struct NoopFavoriteEntryCloudSync: FavoriteEntryCloudSyncing {
    public init() {}
    public func push(_ entries: [FavoriteEntry]) async throws {}
    public func pull() async throws -> [FavoriteEntry] { [] }
    public func delete(_ entry: FavoriteEntry) async throws {}
    public func deleteAll() async throws {}
}

/// Mock-Impl für Tests — speichert in-memory.
public actor InMemoryFavoriteEntryCloudSync: FavoriteEntryCloudSyncing {
    public private(set) var stored: [UUID: FavoriteEntry] = [:]
    public var scriptedPushError: Error?
    public var scriptedPullError: Error?

    public init(initial: [FavoriteEntry] = []) {
        for entry in initial { stored[entry.favoriteID] = entry }
    }

    public func push(_ entries: [FavoriteEntry]) async throws {
        if let scriptedPushError { throw scriptedPushError }
        for entry in entries {
            stored[entry.favoriteID] = entry
        }
    }

    public func pull() async throws -> [FavoriteEntry] {
        if let scriptedPullError { throw scriptedPullError }
        return Array(stored.values).sorted { $0.updatedAt > $1.updatedAt }
    }

    public func delete(_ entry: FavoriteEntry) async throws {
        stored.removeValue(forKey: entry.favoriteID)
    }

    public func deleteAll() async throws {
        stored.removeAll()
    }
}

#if canImport(CloudKit)
import CloudKit

/// Produktiv-Implementation gegen die private CloudKit-Datenbank des
/// konfigurierten App-Containers. Nur für `FavoriteEntry`-Records.
public struct CloudKitFavoriteEntryCloudSync: FavoriteEntryCloudSyncing {
    private let containerIdentifier: String

    public init(containerIdentifier: String = CloudKitCloudSyncService.defaultContainerIdentifier) {
        self.containerIdentifier = containerIdentifier
    }

    public func push(_ entries: [FavoriteEntry]) async throws {
        guard !entries.isEmpty else { return }
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        let records = entries.map(Self.makeRecord)
        let expectedIDs = records.map(\.recordID)
        let (saveResults, _) = try await database.modifyRecords(
            saving: records,
            deleting: [],
            savePolicy: .changedKeys,
            atomically: false
        )
        try ICloudCloudKitMVPResultValidator.assertAllSaved(
            expectedIDs: expectedIDs,
            in: saveResults
        )
    }

    public func pull() async throws -> [FavoriteEntry] {
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        let query = CKQuery(recordType: CloudKitFavoriteEntrySchema.recordType,
                            predicate: NSPredicate(format: "TRUEPREDICATE"))
        var collected: [CKRecord] = []
        var perRecordErrors: [NSError] = []
        func ingest(_ matchResults: [(CKRecord.ID, Result<CKRecord, Error>)]) {
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    collected.append(record)
                case .failure(let err):
                    let ns = err as NSError
                    // Per-record `unknownItem` (code 11) ist idempotent —
                    // Record wurde während Iteration gelöscht. Skippen.
                    if ns.domain == "CKErrorDomain", ns.code == 11 { continue }
                    perRecordErrors.append(ns)
                }
            }
        }
        do {
            let firstPage = try await database.records(matching: query, resultsLimit: 200)
            ingest(firstPage.matchResults)
            var cursor = firstPage.queryCursor
            while let next = cursor {
                let nextPage = try await database.records(continuingMatchFrom: next, resultsLimit: 200)
                ingest(nextPage.matchResults)
                cursor = nextPage.queryCursor
            }
        } catch {
            let ns = error as NSError
            // Idempotente Skip-Pattern (analog zum LiveTrack-Delete-Pfad):
            // `unknownItem` oder „Type is not marked indexable" = leer.
            if ns.domain == "CKErrorDomain", ns.code == 11 { return [] }
            if ns.domain == "CKErrorDomain", ns.code == 12 {
                let server = (ns.userInfo["ServerErrorDescription"] as? String) ?? ""
                let underlying = (ns.userInfo[NSUnderlyingErrorKey] as? NSError)?.localizedDescription ?? ""
                let combined = server + " " + underlying
                if combined.contains("not marked indexable")
                    || combined.contains("not marked queryable") {
                    return []
                }
            }
            throw error
        }
        if let firstError = perRecordErrors.first {
            throw FavoriteEntryCloudSyncError.partialFetchFailure(
                failedRecordCount: perRecordErrors.count,
                firstError: firstError
            )
        }
        return collected.compactMap(Self.decode)
    }

    public func delete(_ entry: FavoriteEntry) async throws {
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        let recordID = CKRecord.ID(recordName: CloudKitFavoriteEntrySchema.recordName(for: entry))
        let (_, deleteResults) = try await database.modifyRecords(
            saving: [],
            deleting: [recordID],
            savePolicy: .changedKeys,
            atomically: false
        )
        do {
            try ICloudCloudKitMVPResultValidator.assertDeleted(recordID: recordID, in: deleteResults)
        } catch {
            let ns = error as NSError
            if ns.domain == "CKErrorDomain", ns.code == 11 { return }
            throw error
        }
    }

    public func deleteAll() async throws {
        let entries = try await pull()
        guard !entries.isEmpty else { return }
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        let ids = entries.map { CKRecord.ID(recordName: CloudKitFavoriteEntrySchema.recordName(for: $0)) }
        let chunkSize = 200
        for chunkStart in stride(from: 0, to: ids.count, by: chunkSize) {
            let chunk = Array(ids[chunkStart..<min(chunkStart + chunkSize, ids.count)])
            let (_, deleteResults) = try await database.modifyRecords(
                saving: [],
                deleting: chunk,
                savePolicy: .changedKeys,
                atomically: false
            )
            for recordID in chunk {
                do {
                    try ICloudCloudKitMVPResultValidator.assertDeleted(recordID: recordID, in: deleteResults)
                } catch {
                    let ns = error as NSError
                    if ns.domain == "CKErrorDomain", ns.code == 11 { continue }
                    throw error
                }
            }
        }
    }

    private static func makeRecord(_ entry: FavoriteEntry) -> CKRecord {
        let record = CKRecord(
            recordType: CloudKitFavoriteEntrySchema.recordType,
            recordID: CKRecord.ID(recordName: CloudKitFavoriteEntrySchema.recordName(for: entry))
        )
        record[CloudKitFavoriteEntrySchema.Field.schemaVersion] = entry.schemaVersion as CKRecordValue
        record[CloudKitFavoriteEntrySchema.Field.favoriteID] = entry.favoriteID.uuidString as CKRecordValue
        record[CloudKitFavoriteEntrySchema.Field.legacyID] = entry.legacyID as CKRecordValue
        record[CloudKitFavoriteEntrySchema.Field.itemKind] = entry.itemKind.rawValue as CKRecordValue
        record[CloudKitFavoriteEntrySchema.Field.isFavorite] = entry.isFavorite as CKRecordValue
        record[CloudKitFavoriteEntrySchema.Field.createdAt] = entry.createdAt as CKRecordValue
        record[CloudKitFavoriteEntrySchema.Field.updatedAt] = entry.updatedAt as CKRecordValue
        if let deletedAt = entry.deletedAt {
            record[CloudKitFavoriteEntrySchema.Field.deletedAt] = deletedAt as CKRecordValue
        }
        return record
    }

    private static func decode(_ record: CKRecord) -> FavoriteEntry? {
        guard let favoriteIDString = record[CloudKitFavoriteEntrySchema.Field.favoriteID] as? String,
              let favoriteID = UUID(uuidString: favoriteIDString),
              let legacyID = record[CloudKitFavoriteEntrySchema.Field.legacyID] as? String,
              let itemKindRaw = record[CloudKitFavoriteEntrySchema.Field.itemKind] as? String,
              let itemKind = FavoriteItemKind(rawValue: itemKindRaw),
              let isFavorite = record[CloudKitFavoriteEntrySchema.Field.isFavorite] as? Bool,
              let createdAt = record[CloudKitFavoriteEntrySchema.Field.createdAt] as? Date,
              let updatedAt = record[CloudKitFavoriteEntrySchema.Field.updatedAt] as? Date
        else { return nil }
        let schemaVersion = (record[CloudKitFavoriteEntrySchema.Field.schemaVersion] as? Int)
            ?? (record[CloudKitFavoriteEntrySchema.Field.schemaVersion] as? NSNumber)?.intValue
            ?? CloudKitFavoriteEntrySchema.schemaVersion
        let deletedAt = record[CloudKitFavoriteEntrySchema.Field.deletedAt] as? Date
        return FavoriteEntry(
            favoriteID: favoriteID,
            legacyID: legacyID,
            itemKind: itemKind,
            isFavorite: isFavorite,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            schemaVersion: schemaVersion
        )
    }
}
#endif
