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
    public static func save(url: URL) -> Data? {
        let options: URL.BookmarkCreationOptions
        #if os(macOS)
        options = [.withSecurityScope]
        #else
        options = []
        #endif

        guard let data = try? url.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil) else {
            return nil
        }
        UserDefaults.standard.set(data, forKey: bookmarkKey)
        return data
    }

    /// Resolves the stored bookmark and returns the URL.
    /// Automatically refreshes a stale bookmark if possible.
    /// Returns nil if no bookmark is stored, the bookmark is invalid, or the file is gone.
    public static func restore() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else {
            return nil
        }

        let resolutionOptions: URL.BookmarkResolutionOptions
        #if os(macOS)
        resolutionOptions = [.withSecurityScope]
        #else
        resolutionOptions = []
        #endif

        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: resolutionOptions, relativeTo: nil, bookmarkDataIsStale: &isStale) else {
            clear()
            return nil
        }

        if isStale {
            // Try to refresh the bookmark while we still have access.
            let refreshOptions: URL.BookmarkCreationOptions
            #if os(macOS)
            refreshOptions = [.withSecurityScope]
            #else
            refreshOptions = []
            #endif
            if let refreshed = try? url.bookmarkData(options: refreshOptions, includingResourceValuesForKeys: nil, relativeTo: nil) {
                UserDefaults.standard.set(refreshed, forKey: bookmarkKey)
            }
        }

        return url
    }

    /// Removes the stored bookmark.
    public static func clear() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
    }

    /// Returns true if a bookmark is currently stored.
    public static var hasStoredBookmark: Bool {
        UserDefaults.standard.data(forKey: bookmarkKey) != nil
    }
}
