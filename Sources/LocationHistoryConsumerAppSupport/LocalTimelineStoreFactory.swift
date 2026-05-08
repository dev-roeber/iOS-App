import Foundation

/// Phase-4 production-shaped open-lifecycle for the LocalTimelineStore.
///
/// `LocalTimelineStoreFactory` ties together the three other Phase-4
/// pieces — `LocalTimelineStorageLocations`, `LocalTimelineFileAttributes`,
/// `LocalTimelineFileProtection` — and produces an opened
/// `LocalTimelineStore` at the production-shaped path layout.
///
/// **Scope (deliberately limited):**
///
/// - No UI hook, no `AppContentLoader` hook, no App-Session switch.
/// - No automatic migration of existing in-memory `AppExport` data.
/// - No backfill of older app caches into the store.
///
/// The factory is consumed by Phase-4 tests and by future Darwin/iOS
/// rollout code. Production reads still go through the in-memory
/// `AppExport` pipeline.
public final class LocalTimelineStoreFactory {

    public let locations: LocalTimelineStorageLocations
    private let fileManager: FileManager

    public init(locations: LocalTimelineStorageLocations,
                fileManager: FileManager = .default) {
        self.locations = locations
        self.fileManager = fileManager
    }

    /// Convenience initialiser that resolves to the production layout.
    public static func production(fileManager: FileManager = .default) throws -> LocalTimelineStoreFactory {
        let locations = try LocalTimelineStorageLocations.production(fileManager: fileManager)
        return LocalTimelineStoreFactory(locations: locations, fileManager: fileManager)
    }

    /// Convenience initialiser that puts the entire layout under `root`,
    /// for tests and self-contained sandboxes.
    public static func temporary(under root: URL,
                                 fileManager: FileManager = .default) -> LocalTimelineStoreFactory {
        LocalTimelineStoreFactory(
            locations: LocalTimelineStorageLocations.temporary(under: root),
            fileManager: fileManager
        )
    }

    /// Open or create the SQLite store at `locations.databaseFileURL`.
    ///
    /// Steps:
    ///
    /// 1. `ensureDirectoriesExist` for all four roots (idempotent).
    /// 2. Mark every root as excluded-from-backup (Apple-only; no-op on
    ///    Linux).
    /// 3. Apply default FileProtection to every root (Apple-rollout
    ///    hook; no-op on Linux).
    /// 4. Open `LocalTimelineStore(url:)` at `locations.databaseFileURL`.
    /// 5. Apply default FileProtection to the freshly created DB file.
    ///
    /// Returns the opened store. Callers own the lifetime and must call
    /// `close()` when done.
    @discardableResult
    public func openStore() throws -> LocalTimelineStore {
        try locations.ensureDirectoriesExist(fileManager: fileManager)
        try LocalTimelineFileAttributes.markExcludedFromBackupIfPresent(urls: locations.allRoots)
        try LocalTimelineFileProtection.applyDefaultProtectionIfPresent(urls: locations.allRoots)

        let store = try LocalTimelineStore(url: locations.databaseFileURL)

        // Once the file actually exists, push the same flags onto it.
        // `markExcludedFromBackup` and `applyDefaultProtection` both
        // require an existing path, which is why this happens after open.
        try LocalTimelineFileAttributes.markExcludedFromBackupIfPresent(urls: [locations.databaseFileURL])
        try LocalTimelineFileProtection.applyDefaultProtectionIfPresent(urls: [locations.databaseFileURL])

        return store
    }
}
