import Foundation

/// Phase-4 storage-path resolver for the LocalTimelineStore.
///
/// Defines where the production app *would* place its disk artefacts once
/// the store is wired up. Until then, this type is consumed only by the
/// `LocalTimelineStoreFactory` spike and by tests; no UI flow imports it.
///
/// **Production layout** (Apple platforms):
///
/// - DB Root:              `applicationSupportDirectory/LocationHistory2GPX/Imports/`
/// - Render Cache Root:    `cachesDirectory/LocationHistory2GPX/RenderCache/`
/// - Import Staging Root:  `temporaryDirectory/LocationHistory2GPX/ImportStaging/`
/// - Export Staging Root:  `temporaryDirectory/LocationHistory2GPX/ExportStaging/`
///
/// On Linux, `Foundation` resolves these to `~/.local/share`, `~/.cache`,
/// and `/tmp` respectively, which is fine for CI tests — directory layout
/// is plattformneutral, semantics aren't iOS-only.
///
/// **No location data lives in `Documents/`.** Documents is reserved for
/// user-initiated exports; the on-disk store is regenerable cache that
/// must be excluded from iCloud/iTunes backup (see
/// `LocalTimelineFileAttributes.markExcludedFromBackup(url:)`).
public struct LocalTimelineStorageLocations: Equatable {

    /// Root for the SQLite database file (`store.sqlite`) plus its WAL/SHM
    /// siblings. Sits under Application Support on iOS so iOS won't purge
    /// it under storage pressure, but it's still excluded from backup.
    public let databaseRoot: URL

    /// Root for derived render artefacts (tile snapshots, chart caches).
    /// Lives under `Caches/` so iOS may evict it under storage pressure.
    public let renderCacheRoot: URL

    /// Scratch root for in-progress imports (extracted ZIP, parsed JSON
    /// fragments). Lives under `tmp/` so it's wiped on app termination.
    public let importStagingRoot: URL

    /// Scratch root for in-progress exports (GPX/KMZ/CSV staging). Lives
    /// under `tmp/` so it's wiped on app termination.
    public let exportStagingRoot: URL

    public init(databaseRoot: URL,
                renderCacheRoot: URL,
                importStagingRoot: URL,
                exportStagingRoot: URL) {
        self.databaseRoot = databaseRoot
        self.renderCacheRoot = renderCacheRoot
        self.importStagingRoot = importStagingRoot
        self.exportStagingRoot = exportStagingRoot
    }

    /// Default URL for the SQLite database file inside `databaseRoot`.
    /// Phase-4 uses `store.sqlite`; the WAL/SHM siblings (`store.sqlite-wal`,
    /// `store.sqlite-shm`) are managed by SQLite itself.
    public var databaseFileURL: URL {
        databaseRoot.appendingPathComponent("store.sqlite", isDirectory: false)
    }

    public var walFileURL: URL {
        databaseRoot.appendingPathComponent("store.sqlite-wal", isDirectory: false)
    }

    public var shmFileURL: URL {
        databaseRoot.appendingPathComponent("store.sqlite-shm", isDirectory: false)
    }

    // MARK: - Production resolution

    private static let projectFolder = "LocationHistory2GPX"

    /// Resolve to the production-default layout via `FileManager`.
    public static func production(fileManager: FileManager = .default) throws -> LocalTimelineStorageLocations {
        let appSupport = try fileManager.url(for: .applicationSupportDirectory,
                                             in: .userDomainMask,
                                             appropriateFor: nil,
                                             create: true)
        let caches = try fileManager.url(for: .cachesDirectory,
                                         in: .userDomainMask,
                                         appropriateFor: nil,
                                         create: true)
        let tmp = fileManager.temporaryDirectory
        return LocalTimelineStorageLocations(
            databaseRoot: appSupport.appendingPathComponent(projectFolder, isDirectory: true)
                .appendingPathComponent("Imports", isDirectory: true),
            renderCacheRoot: caches.appendingPathComponent(projectFolder, isDirectory: true)
                .appendingPathComponent("RenderCache", isDirectory: true),
            importStagingRoot: tmp.appendingPathComponent(projectFolder, isDirectory: true)
                .appendingPathComponent("ImportStaging", isDirectory: true),
            exportStagingRoot: tmp.appendingPathComponent(projectFolder, isDirectory: true)
                .appendingPathComponent("ExportStaging", isDirectory: true)
        )
    }

    /// Resolve to a layout fully contained inside `root`. Used by tests and
    /// by callers who want a self-contained sandbox (e.g. UI tests).
    public static func temporary(under root: URL) -> LocalTimelineStorageLocations {
        LocalTimelineStorageLocations(
            databaseRoot: root.appendingPathComponent("Imports", isDirectory: true),
            renderCacheRoot: root.appendingPathComponent("RenderCache", isDirectory: true),
            importStagingRoot: root.appendingPathComponent("ImportStaging", isDirectory: true),
            exportStagingRoot: root.appendingPathComponent("ExportStaging", isDirectory: true)
        )
    }

    // MARK: - Idempotent directory creation

    public var allRoots: [URL] {
        [databaseRoot, renderCacheRoot, importStagingRoot, exportStagingRoot]
    }

    /// Idempotently create the four roots. Safe to call repeatedly.
    public func ensureDirectoriesExist(fileManager: FileManager = .default) throws {
        for url in allRoots {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
