import Foundation

/// Phase-4 high-level lifecycle wrapper for the LocalTimelineStore.
///
/// Bundles the four storage roots (DB / RenderCache / ImportStaging /
/// ExportStaging) into a single "user pressed *Delete imported data*"
/// boundary. `deleteAllLocalTimelineData()` is what the future Settings
/// hook will invoke; until that UI exists, the helper is exercised by
/// Phase-4 tests only.
///
/// **Scope:**
///
/// - DB rows via `store.deleteAll()` (existing Phase-2 behaviour).
/// - DB file `store.sqlite` plus its `-wal` / `-shm` siblings, if any.
/// - The entire `RenderCache` directory tree.
/// - The entire `ImportStaging` directory tree.
/// - The entire `ExportStaging` directory tree.
///
/// **Out of scope (documented for the eventual UI iteration):**
///
/// - `UserDefaults` cleanup. **No location data is ever persisted in
///   `UserDefaults`** — the only related keys today are bookmark URLs and
///   feature preferences, none of which are managed here. When a Settings
///   hook lands, the bookmark/preferences sweep belongs there, not in
///   this lifecycle.
/// - Keychain entries (live-upload bearer token). Out of scope; the
///   live-upload subsystem is strictly separate.
public final class LocalTimelineStoreLifecycle {

    public let locations: LocalTimelineStorageLocations
    private let fileManager: FileManager

    public init(locations: LocalTimelineStorageLocations,
                fileManager: FileManager = .default) {
        self.locations = locations
        self.fileManager = fileManager
    }

    /// Convenience: derive a lifecycle from the same locations a factory
    /// owns. Both can coexist; the lifecycle does not own the store
    /// handle.
    public convenience init(factory: LocalTimelineStoreFactory) {
        self.init(locations: factory.locations, fileManager: .default)
    }

    /// Idempotent reset of all local-timeline data.
    ///
    /// - Parameter store: optional already-open store. If non-nil, its
    ///   rows are wiped via `store.deleteAll()` and the handle is closed
    ///   before the file is removed (SQLite holds the file open under
    ///   WAL mode, so we must close before unlinking).
    /// - Returns: a `Report` summarising what was actually removed, for
    ///   diagnostic logging in the future Settings hook.
    @discardableResult
    public func deleteAllLocalTimelineData(store: LocalTimelineStore? = nil) throws -> Report {
        var report = Report()

        if let store {
            do {
                try store.deleteAll()
                report.didWipeRowsViaStore = true
            } catch {
                report.rowWipeError = "\(error)"
            }
            store.close()
        }

        for url in [locations.databaseFileURL, locations.walFileURL, locations.shmFileURL] {
            if removeIfExists(url: url) {
                report.removedDBFiles.append(url.lastPathComponent)
            }
        }

        for url in [locations.renderCacheRoot,
                    locations.importStagingRoot,
                    locations.exportStagingRoot] {
            if removeIfExists(url: url) {
                report.removedDirectories.append(url.lastPathComponent)
            }
        }

        // Re-create the directory shells so a subsequent `openStore()` is
        // immediately usable. The DB-Root is also recreated; the DB file
        // itself will be created on next open.
        try locations.ensureDirectoriesExist(fileManager: fileManager)

        return report
    }

    /// Removes `url` if it exists. Returns `true` iff something was
    /// actually removed. Errors during removal are absorbed — the caller
    /// can detect partial failure by re-checking the report.
    @discardableResult
    private func removeIfExists(url: URL) -> Bool {
        guard fileManager.fileExists(atPath: url.path) else { return false }
        do {
            try fileManager.removeItem(at: url)
            return true
        } catch {
            return false
        }
    }

    public struct Report: Equatable {
        public var didWipeRowsViaStore: Bool = false
        public var rowWipeError: String? = nil
        public var removedDBFiles: [String] = []
        public var removedDirectories: [String] = []
    }
}
