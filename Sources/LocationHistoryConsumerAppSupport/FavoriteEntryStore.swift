import Foundation
#if canImport(OSLog)
import OSLog
#endif

/// Phase E (2026-05-25) — local-only persistent store for `FavoriteEntry`.
///
/// On-disk shape:
/// ```
/// Application Support/LocationHistory2GPX/Favorites/favorite_entries.json
/// {
///   "schemaVersion": 1,
///   "entries": [ FavoriteEntry, ... ]
/// }
/// ```
///
/// Migration: on first load that finds no file, the existing
/// `DayFavoritesStore` (UserDefaults `Set<String>` of ISO-8601 day IDs) is
/// read once, mapped into `FavoriteEntry.day` rows with deterministic
/// `favoriteID`s, and persisted as the initial JSON. The legacy
/// UserDefaults entry is **kept**, so existing UI/tests keep working;
/// migration is idempotent (a `UserDefaults` marker guards against
/// re-running it on already-migrated devices).
///
/// **Phase-E scope:** local only. No CloudKit. No coordinates. No tracks.
public final class FavoriteEntryStore {

    // MARK: - Disk envelope

    private struct Envelope: Codable {
        var schemaVersion: Int
        var entries: [FavoriteEntry]
    }

    // MARK: - Persistence wiring

    private let fileURL: URL
    private let userDefaults: UserDefaults
    private let legacySource: () -> Set<String>

    /// UserDefaults key that flips to `true` after the first successful
    /// legacy migration; prevents re-importing already-deleted favorites.
    public static let legacyMigrationMarker = "app.favorites.entry.legacyMigrated.v1"

    /// Default ctor uses Application Support + standard UserDefaults +
    /// the live `DayFavoritesStore` as legacy source.
    public convenience init() throws {
        let fileURL = try FavoriteEntryStore.defaultFileURL()
        self.init(
            fileURL: fileURL,
            userDefaults: .standard,
            legacySource: { DayFavoritesStore.load() }
        )
    }

    /// Injectable ctor for tests.
    public init(
        fileURL: URL,
        userDefaults: UserDefaults,
        legacySource: @escaping () -> Set<String>
    ) {
        self.fileURL = fileURL
        self.userDefaults = userDefaults
        self.legacySource = legacySource
    }

    /// Phase F — Fallback wenn `defaultFileURL()` fehlschlägt (z. B.
    /// Application-Support nicht zugreifbar). Schreibt in `tmp/`, damit
    /// die App nicht crasht.
    public static func makeInMemoryFallback() -> FavoriteEntryStore {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("FavoriteEntryStore-fallback-\(UUID().uuidString).json")
        return FavoriteEntryStore(
            fileURL: tmp,
            userDefaults: .standard,
            legacySource: { [] }
        )
    }

    /// Resolves the canonical disk path under Application Support.
    /// `Application Support/LocationHistory2GPX/Favorites/favorite_entries.json`.
    public static func defaultFileURL() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = appSupport
            .appendingPathComponent("LocationHistory2GPX", isDirectory: true)
            .appendingPathComponent("Favorites", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.createDirectory(
                at: folder,
                withIntermediateDirectories: true
            )
        }
        return folder.appendingPathComponent("favorite_entries.json", isDirectory: false)
    }

    // MARK: - Read

    /// Loads the on-disk envelope, running the legacy migration once if
    /// the JSON file is missing. Returns an empty array on first-ever
    /// launch with no legacy favorites.
    public func loadEntries(now: Date = Date()) -> [FavoriteEntry] {
        if let onDisk = readEnvelopeFromDisk() {
            return onDisk.entries
        }
        // Either no file yet, or the file was corrupted and quarantined
        // by `readEnvelopeFromDisk`. Either way: attempt one-shot legacy
        // migration so the user does not lose their favorites.
        return migrateFromLegacyIfNeeded(now: now)
    }

    /// Convenience read for UI call-sites that previously consumed
    /// `Set<String>` ISO-day-ID — keeps the existing
    /// `favoritedDayIDs: Set<String>` SwiftUI state shape intact.
    public func loadActiveDayIDs() -> Set<String> {
        Set(loadEntries()
            .filter { $0.itemKind == .day && $0.isFavorite }
            .map(\.legacyID))
    }

    public func contains(dayIdentifier: String) -> Bool {
        loadEntries().contains { entry in
            entry.itemKind == .day
                && entry.isFavorite
                && entry.legacyID == dayIdentifier
        }
    }

    // MARK: - Write

    /// Sets the favorite state for a day. Idempotent — no-op if the
    /// requested state already matches what is on disk. Returns the
    /// updated `FavoriteEntry` (created if it did not exist).
    @discardableResult
    public func setDayFavorite(
        _ dayIdentifier: String,
        isFavorite: Bool,
        now: Date = Date()
    ) -> FavoriteEntry {
        var entries = loadEntries(now: now)
        let favoriteID = FavoriteIDFactory.deterministicID(
            legacyID: dayIdentifier,
            itemKind: .day
        )
        if let index = entries.firstIndex(where: { $0.favoriteID == favoriteID }) {
            var entry = entries[index]
            if entry.isFavorite == isFavorite && entry.deletedAt == nil {
                return entry
            }
            entry.isFavorite = isFavorite
            entry.updatedAt = now
            entry.deletedAt = isFavorite ? nil : now
            entries[index] = entry
            writeEnvelope(.init(schemaVersion: FavoriteEntry.currentSchemaVersion, entries: entries))
            return entry
        }
        let entry = FavoriteEntry(
            favoriteID: favoriteID,
            legacyID: dayIdentifier,
            itemKind: .day,
            isFavorite: isFavorite,
            createdAt: now,
            updatedAt: now,
            deletedAt: isFavorite ? nil : now
        )
        entries.append(entry)
        writeEnvelope(.init(schemaVersion: FavoriteEntry.currentSchemaVersion, entries: entries))
        return entry
    }

    /// Toggles the favorite state for a day. Returns the new
    /// `isFavorite` value.
    @discardableResult
    public func toggleDayFavorite(_ dayIdentifier: String, now: Date = Date()) -> Bool {
        let next = !contains(dayIdentifier: dayIdentifier)
        setDayFavorite(dayIdentifier, isFavorite: next, now: now)
        return next
    }

    /// Phase F — überschreibt den vollständigen On-Disk-Stand. Wird vom
    /// CloudKit-Merge-Pfad (`FavoriteEntryCloudSyncCoordinator`)
    /// aufgerufen, nachdem lokale + Cloud-Einträge merged wurden.
    public func replaceAll(with entries: [FavoriteEntry]) throws {
        writeEnvelope(.init(schemaVersion: FavoriteEntry.currentSchemaVersion, entries: entries))
    }

    // MARK: - Internal helpers

    private func readEnvelopeFromDisk() -> Envelope? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(Envelope.self, from: data)
        } catch {
            quarantineCorruptFile(reason: error)
            return nil
        }
    }

    private func writeEnvelope(_ envelope: Envelope) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(envelope)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            #if canImport(OSLog)
            FavoriteEntryStore.logger.error("Failed to persist favorite_entries.json (count=\(envelope.entries.count, privacy: .public))")
            #endif
        }
    }

    /// Renames a corrupted JSON file to `favorite_entries.corrupt-<timestamp>.json`
    /// so the next load starts clean — preserves the bad file for offline
    /// debugging without losing user data on the next legacy-migration pass.
    private func quarantineCorruptFile(reason: Error) {
        #if canImport(OSLog)
        FavoriteEntryStore.logger.error("favorite_entries.json corrupt — quarantining")
        #endif
        let stamp = Int(Date().timeIntervalSince1970)
        let backupURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent("favorite_entries.corrupt-\(stamp).json")
        _ = try? FileManager.default.moveItem(at: fileURL, to: backupURL)
    }

    /// Idempotent one-shot import of the legacy `DayFavoritesStore`
    /// `Set<String>` ISO-day-IDs into the new on-disk shape.
    private func migrateFromLegacyIfNeeded(now: Date) -> [FavoriteEntry] {
        if userDefaults.bool(forKey: FavoriteEntryStore.legacyMigrationMarker) {
            // Already migrated once and the file is gone (or was just
            // quarantined) — start with an empty store rather than
            // re-importing potentially-deleted favorites.
            writeEnvelope(.init(schemaVersion: FavoriteEntry.currentSchemaVersion, entries: []))
            return []
        }
        let legacyIDs = legacySource()
        let migrated: [FavoriteEntry] = legacyIDs.sorted().map { dayID in
            FavoriteEntry(
                favoriteID: FavoriteIDFactory.deterministicID(
                    legacyID: dayID,
                    itemKind: .day
                ),
                legacyID: dayID,
                itemKind: .day,
                isFavorite: true,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            )
        }
        let envelope = Envelope(
            schemaVersion: FavoriteEntry.currentSchemaVersion,
            entries: migrated
        )
        writeEnvelope(envelope)
        userDefaults.set(true, forKey: FavoriteEntryStore.legacyMigrationMarker)
        return migrated
    }

    #if canImport(OSLog)
    private static let logger = Logger(
        subsystem: "de.roeber.LH2GPXWrapper",
        category: "favorites"
    )
    #endif
}
