import Foundation

/// Source of a recent file — used by the Welcome screen to render a
/// badge ("LOCAL" / "iCLOUD" / "FILE") so the user can tell at a glance
/// whether the file lives on-device or in iCloud Drive. Persisted with
/// each `RecentFileEntry`; legacy entries without the field decode to
/// `.unknown` thanks to the manual `Codable` implementation below.
public enum RecentFileSource: String, Codable, Equatable, Sendable {
    case local
    case iCloudDrive
    case unknown
}

/// A single entry in the recent-files list.
public struct RecentFileEntry: Codable, Identifiable, Equatable {
    public var id: UUID
    public var displayName: String
    public var bookmarkData: Data
    public var lastOpenedAt: Date
    public var fileSizeBytes: Int64?
    /// Train F.4 — Welcome screen surfaces this as a badge. Legacy
    /// entries (pre-F.4) decode as `.unknown`.
    public var source: RecentFileSource

    public init(
        id: UUID = UUID(),
        displayName: String,
        bookmarkData: Data,
        lastOpenedAt: Date = Date(),
        fileSizeBytes: Int64? = nil,
        source: RecentFileSource = .unknown
    ) {
        self.id = id
        self.displayName = displayName
        self.bookmarkData = bookmarkData
        self.lastOpenedAt = lastOpenedAt
        self.fileSizeBytes = fileSizeBytes
        self.source = source
    }

    // MARK: - Manual Codable (backward-compat with pre-F.4 JSON)

    private enum CodingKeys: String, CodingKey {
        case id, displayName, bookmarkData, lastOpenedAt, fileSizeBytes, source
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.displayName = try c.decode(String.self, forKey: .displayName)
        self.bookmarkData = try c.decode(Data.self, forKey: .bookmarkData)
        self.lastOpenedAt = try c.decode(Date.self, forKey: .lastOpenedAt)
        self.fileSizeBytes = try c.decodeIfPresent(Int64.self, forKey: .fileSizeBytes)
        // decodeIfPresent → legacy JSON ohne `source` ergibt `.unknown`.
        self.source = try c.decodeIfPresent(RecentFileSource.self, forKey: .source) ?? .unknown
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(displayName, forKey: .displayName)
        try c.encode(bookmarkData, forKey: .bookmarkData)
        try c.encode(lastOpenedAt, forKey: .lastOpenedAt)
        try c.encodeIfPresent(fileSizeBytes, forKey: .fileSizeBytes)
        try c.encode(source, forKey: .source)
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

        let entry = RecentFileEntry(
            displayName: displayName,
            bookmarkData: bookmarkData,
            lastOpenedAt: Date(),
            fileSizeBytes: fileSize(for: url),
            source: detectSource(for: url)
        )
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

    // MARK: - Detect source (Train F.4)

    /// Detects whether `url` lives in iCloud Drive (Mobile Documents /
    /// `com~apple~CloudDocs` tree) or on the local sandbox. No entitlement
    /// required — `FileManager.isUbiquitousItem(at:)` answers on every URL.
    public static func detectSource(for url: URL) -> RecentFileSource {
        #if os(iOS) || os(macOS)
        if FileManager.default.isUbiquitousItem(at: url) { return .iCloudDrive }
        let p = url.path
        if p.contains("/Mobile Documents/") || p.contains("com~apple~CloudDocs") {
            return .iCloudDrive
        }
        return .local
        #else
        return .local
        #endif
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

        // Build a synthetic entry from the legacy bookmark. The original
        // URL is no longer known here, so the source stays `.unknown`.
        let entry = RecentFileEntry(
            displayName: "Imported File",
            bookmarkData: legacyData,
            lastOpenedAt: Date(),
            source: .unknown
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

    private static func fileSize(for url: URL) -> Int64? {
        #if os(macOS) || os(iOS)
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey])
        if let allocated = values?.totalFileAllocatedSize {
            return Int64(allocated)
        }
        if let fileSize = values?.fileSize {
            return Int64(fileSize)
        }
        #endif
        return nil
    }
}
