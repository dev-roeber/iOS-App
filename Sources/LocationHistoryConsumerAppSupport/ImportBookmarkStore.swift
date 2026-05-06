import Foundation

/// Persists a security-scoped bookmark for the last imported file so the app
/// can re-open it after a restart without requiring the user to pick it again.
///
/// Uses UserDefaults for storage. Only one bookmark is kept at a time.
public enum ImportBookmarkStore {
    private static let bookmarkKey = "lastImportedFileBookmark"

    /// Creates and stores a security-scoped bookmark for the given URL.
    /// Call this while the security-scoped resource is still being accessed.
    /// Returns the bookmark data on success, or nil if bookmark creation fails.
    @discardableResult
    public static func save(url: URL, userDefaults: UserDefaults = .standard) -> Data? {
        #if os(macOS) || os(iOS)
        let options: URL.BookmarkCreationOptions
        #if os(macOS)
        options = [.withSecurityScope]
        #else
        options = []
        #endif

        guard let data = try? url.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil) else {
            return nil
        }
        userDefaults.set(data, forKey: bookmarkKey)
        return data
        #else
        let data = Data(url.path.utf8)
        userDefaults.set(data, forKey: bookmarkKey)
        return data
        #endif
    }

    /// Resolves the stored bookmark and returns the URL.
    /// Automatically refreshes a stale bookmark if possible.
    /// Returns nil if no bookmark is stored, the bookmark is invalid, or the file is gone.
    ///
    /// Convention: Returns a URL with security-scoped access already started;
    /// the caller MUST call `releaseAccessIfNeeded(url:)` when done reading.
    public static func restore(userDefaults: UserDefaults = .standard) -> URL? {
        guard let data = userDefaults.data(forKey: bookmarkKey) else {
            return nil
        }

        #if os(macOS) || os(iOS)
        let resolutionOptions: URL.BookmarkResolutionOptions
        #if os(macOS)
        resolutionOptions = [.withSecurityScope]
        #else
        resolutionOptions = []
        #endif

        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: resolutionOptions, relativeTo: nil, bookmarkDataIsStale: &isStale) else {
            clear(userDefaults: userDefaults)
            return nil
        }

        // Start security-scoped access immediately so the caller can read
        // safely. On iOS this is harmless if not strictly required.
        _ = url.startAccessingSecurityScopedResource()

        if isStale {
            // Try to refresh the bookmark while we still have access.
            let refreshOptions: URL.BookmarkCreationOptions
            #if os(macOS)
            refreshOptions = [.withSecurityScope]
            #else
            refreshOptions = []
            #endif
            if let refreshed = try? url.bookmarkData(options: refreshOptions, includingResourceValuesForKeys: nil, relativeTo: nil) {
                userDefaults.set(refreshed, forKey: bookmarkKey)
            }
        }

        return url
        #else
        guard let path = String(data: data, encoding: .utf8), !path.isEmpty else {
            clear(userDefaults: userDefaults)
            return nil
        }

        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            clear(userDefaults: userDefaults)
            return nil
        }
        return url
        #endif
    }

    /// Releases security-scoped access previously started by `restore(userDefaults:)`.
    /// Safe to call on any platform; on non-Apple platforms this is a no-op.
    public static func releaseAccessIfNeeded(url: URL) {
        #if os(macOS) || os(iOS)
        url.stopAccessingSecurityScopedResource()
        #endif
    }

    /// Removes the stored bookmark.
    public static func clear(userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: bookmarkKey)
    }

    /// Returns true if a bookmark is currently stored.
    public static var hasStoredBookmark: Bool {
        hasStoredBookmark(userDefaults: .standard)
    }

    public static func hasStoredBookmark(userDefaults: UserDefaults = .standard) -> Bool {
        userDefaults.data(forKey: bookmarkKey) != nil
    }
}
