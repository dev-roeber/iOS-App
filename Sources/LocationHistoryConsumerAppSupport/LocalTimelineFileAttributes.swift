import Foundation

/// Phase-4 backup-exclusion helper for the LocalTimelineStore.
///
/// On Apple platforms, sets/reads `URLResourceKey.isExcludedFromBackupKey`
/// so the regenerable on-disk store is not copied into iCloud or iTunes
/// backups. On Linux, all helpers are deliberate no-ops returning `false`
/// for `isExcludedFromBackup(url:)` — the build never breaks, but no
/// platform guarantee is made.
public enum LocalTimelineFileAttributes {

    public enum AttributeError: Error, Equatable, CustomStringConvertible {
        /// The URL did not point to an existing file or directory.
        case fileNotFound(path: String)
        /// The underlying `URL.setResourceValues` / `resourceValues` call
        /// failed. The wrapped message is the localized description from
        /// Foundation; preserved for diagnostics only.
        case underlyingFailure(path: String, message: String)

        public var description: String {
            switch self {
            case let .fileNotFound(path):
                return "fileNotFound(path: \(path))"
            case let .underlyingFailure(path, message):
                return "underlyingFailure(path: \(path), message: \(message))"
            }
        }
    }

    /// Mark the resource at `url` as excluded from backup. The URL must
    /// point to an existing file or directory; the helper itself does not
    /// create anything.
    ///
    /// - On Apple platforms (`canImport(Darwin)`): writes
    ///   `URLResourceKey.isExcludedFromBackupKey = true`.
    /// - On Linux: no-op, returns silently.
    public static func markExcludedFromBackup(url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AttributeError.fileNotFound(path: url.path)
        }
        #if canImport(Darwin)
        var mutable = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        do {
            try mutable.setResourceValues(values)
        } catch {
            throw AttributeError.underlyingFailure(path: url.path,
                                                   message: error.localizedDescription)
        }
        #else
        // Linux no-op — backup semantics are an Apple concept. The directory
        // continues to live wherever Foundation places `applicationSupportDirectory`,
        // but no backup-exclusion flag is persisted.
        _ = url
        #endif
    }

    /// Return whether the resource at `url` is currently flagged as
    /// excluded-from-backup. On Linux this always returns `false`.
    public static func isExcludedFromBackup(url: URL) throws -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AttributeError.fileNotFound(path: url.path)
        }
        #if canImport(Darwin)
        do {
            let values = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
            return values.isExcludedFromBackup ?? false
        } catch {
            throw AttributeError.underlyingFailure(path: url.path,
                                                   message: error.localizedDescription)
        }
        #else
        return false
        #endif
    }

    /// Apply backup-exclusion to every URL in `urls` that already exists.
    /// Missing entries are silently skipped — caller is expected to have
    /// created them via `LocalTimelineStorageLocations.ensureDirectoriesExist`
    /// first; this convenience is for the factory's open-time pass.
    public static func markExcludedFromBackupIfPresent(urls: [URL]) throws {
        let fm = FileManager.default
        for url in urls where fm.fileExists(atPath: url.path) {
            try markExcludedFromBackup(url: url)
        }
    }
}
