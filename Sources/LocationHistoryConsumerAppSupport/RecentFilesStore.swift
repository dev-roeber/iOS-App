import Foundation

/// A single entry in the recent-files list.
public struct RecentFileEntry: Codable, Identifiable, Equatable {
    public var id: UUID
    public var displayName: String
    public var bookmarkData: Data
    public var lastOpenedAt: Date

    public init(id: UUID = UUID(), displayName: String, bookmarkData: Data, lastOpenedAt: Date = Date()) {
        self.id = id
        self.displayName = displayName
        self.bookmarkData = bookmarkData
        self.lastOpenedAt = lastOpenedAt
    }
}

/// Stores a list of recently opened files as security-scoped bookmarks.
///
/// Replaces the single-bookmark `ImportBookmarkStore` and provides migration
/// support: on first load it reads the legacy `lastImportedFileBookmark` key
/// and imports it as the first recent entry.
public enum RecentFilesStore {
    private static let recentFilesKey = "app.recentImportedFiles"
    private static let legacyBookmarkKey = "lastImportedFileBookmark"
    private static let maxEntries = 10

    // MARK: - Load

    /// Returns the stored recent file entries, newest first.
    /// Automatically migrates a legacy single-bookmark on first call.
    public static func load(userDefaults: UserDefaults = .standard) -> [RecentFileEntry] {
        migrateIfNeeded(userDefaults: userDefaults)
        return storedEntries(userDefaults: userDefaults)
    }

    // MARK: - Mutate

    /// Adds or updates a recent entry for the given URL.
    /// Existing entries with the same display name are replaced to avoid duplicates.
    @discardableResult
    public static func add(url: URL, userDefaults: UserDefaults = .standard) -> RecentFileEntry? {
        guard let bookmarkData = makeBookmarkData(for: url) else { return nil }

        var entries = storedEntries(userDefaults: userDefaults)

        // Remove existing entry with same display name to avoid duplicates
        let displayName = url.lastPathComponent
        entries.removeAll { $0.displayName == displayName }

        let entry = RecentFileEntry(displayName: displayName, bookmarkData: bookmarkData, lastOpenedAt: Date())
        entries.insert(entry, at: 0)

        // Trim to max
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        save(entries, userDefaults: userDefaults)
        return entry
    }

    /// Removes the entry with the given ID.
    public static func remove(id: UUID, userDefaults: UserDefaults = .standard) {
        var entries = storedEntries(userDefaults: userDefaults)
        entries.removeAll { $0.id == id }
        save(entries, userDefaults: userDefaults)
    }

    /// Removes all stored entries.
    public static func clear(userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: recentFilesKey)
    }

    // MARK: - Resolve

    /// Resolves a stored entry to a URL.
    /// Returns `nil` if the bookmark is stale or the file is no longer accessible.
    public static func resolveURL(entry: RecentFileEntry) -> URL? {
        #if os(macOS) || os(iOS)
        let resolutionOptions: URL.BookmarkResolutionOptions
        #if os(macOS)
        resolutionOptions = [.withSecurityScope]
        #else
        resolutionOptions = []
        #endif

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: entry.bookmarkData,
            options: resolutionOptions,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        return isStale ? nil : url
        #else
        // Linux/test path: store raw path in bookmark data
        guard let path = String(data: entry.bookmarkData, encoding: .utf8), !path.isEmpty else {
            return nil
        }
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
        #endif
    }

    /// Returns true if the entry's file is still accessible.
    public static func isAvailable(entry: RecentFileEntry) -> Bool {
        resolveURL(entry: entry) != nil
    }

    // MARK: - Private helpers

    private static func storedEntries(userDefaults: UserDefaults) -> [RecentFileEntry] {
        guard let data = userDefaults.data(forKey: recentFilesKey) else { return [] }
        return (try? JSONDecoder().decode([RecentFileEntry].self, from: data)) ?? []
    }

    private static func save(_ entries: [RecentFileEntry], userDefaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        userDefaults.set(data, forKey: recentFilesKey)
    }

    private static func migrateIfNeeded(userDefaults: UserDefaults) {
        // Only migrate if recent files list is empty and legacy key exists
        guard userDefaults.data(forKey: recentFilesKey) == nil,
              let legacyData = userDefaults.data(forKey: legacyBookmarkKey) else { return }

        // Build a synthetic entry from the legacy bookmark
        let entry = RecentFileEntry(
            displayName: "Imported File",
            bookmarkData: legacyData,
            lastOpenedAt: Date()
        )
        save([entry], userDefaults: userDefaults)
        userDefaults.removeObject(forKey: legacyBookmarkKey)
    }

    private static func makeBookmarkData(for url: URL) -> Data? {
        #if os(macOS) || os(iOS)
        let options: URL.BookmarkCreationOptions
        #if os(macOS)
        options = [.withSecurityScope]
        #else
        options = []
        #endif
        return try? url.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil)
        #else
        return Data(url.path.utf8)
        #endif
    }
}
