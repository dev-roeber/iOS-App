import XCTest
import LocationHistoryConsumerAppSupport

final class RecentFilesStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "RecentFilesStoreTests-\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    // MARK: - load / add

    func testLoadReturnsEmptyInitially() {
        let entries = RecentFilesStore.load(userDefaults: defaults)
        XCTAssertTrue(entries.isEmpty)
    }

    // MARK: - Train F.4 — RecentFileSource backward-compat

    func testLegacyEntryWithoutSourceFieldDecodesAsUnknown() throws {
        // Simuliert eine pre-F.4-Persistenz: identische Felder, aber
        // ohne `source`. Muss weiter decoden und `.unknown` ergeben.
        let legacyJSON = """
        [{
            "id": "\(UUID().uuidString)",
            "displayName": "legacy.json",
            "bookmarkData": "\(Data("/tmp/legacy.json".utf8).base64EncodedString())",
            "lastOpenedAt": 0,
            "fileSizeBytes": 42
        }]
        """.data(using: .utf8)!
        defaults.set(legacyJSON, forKey: "app.recentImportedFiles")

        let entries = RecentFilesStore.load(userDefaults: defaults)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.source, .unknown)
        XCTAssertEqual(entries.first?.displayName, "legacy.json")
    }

    func testRoundTripPreservesExplicitSource() throws {
        let entry = RecentFileEntry(
            displayName: "icloud.json",
            bookmarkData: Data("/tmp/icloud.json".utf8),
            lastOpenedAt: Date(timeIntervalSince1970: 1700000000),
            fileSizeBytes: 1024,
            source: .iCloudDrive
        )
        let encoded = try JSONEncoder().encode([entry])
        let decoded = try JSONDecoder().decode([RecentFileEntry].self, from: encoded)
        XCTAssertEqual(decoded.first?.source, .iCloudDrive)
    }

    func testDetectSourceOnLocalPathReturnsLocal() {
        let url = URL(fileURLWithPath: "/tmp/local-only.json")
        XCTAssertEqual(RecentFilesStore.detectSource(for: url), .local)
    }

    #if os(iOS) || os(macOS)
    func testDetectSourceOnMobileDocumentsPathReturnsICloud() {
        // Path-Heuristik greift nur auf Apple — auf Linux ist `detectSource`
        // hartverdrahtet auf `.local`, deshalb der OS-Gate.
        let url = URL(fileURLWithPath: "/private/var/mobile/Library/Mobile Documents/com~apple~CloudDocs/file.json")
        XCTAssertEqual(RecentFilesStore.detectSource(for: url), .iCloudDrive)
    }
    #endif

    func testAddCreatesEntry() {
        let url = makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }

        let entry = RecentFilesStore.add(url: url, userDefaults: defaults)
        XCTAssertNotNil(entry)
        let entries = RecentFilesStore.load(userDefaults: defaults)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].displayName, url.lastPathComponent)
    }

    func testAddDeduplicatesByDisplayName() {
        let url = makeTemporaryFile(name: "dedup.json")
        defer { try? FileManager.default.removeItem(at: url) }

        RecentFilesStore.add(url: url, userDefaults: defaults)
        RecentFilesStore.add(url: url, userDefaults: defaults)
        let entries = RecentFilesStore.load(userDefaults: defaults)
        XCTAssertEqual(entries.count, 1)
    }

    func testAddNewestFirst() {
        let url1 = makeTemporaryFile(name: "file1.json")
        let url2 = makeTemporaryFile(name: "file2.json")
        defer {
            try? FileManager.default.removeItem(at: url1)
            try? FileManager.default.removeItem(at: url2)
        }

        RecentFilesStore.add(url: url1, userDefaults: defaults)
        RecentFilesStore.add(url: url2, userDefaults: defaults)
        let entries = RecentFilesStore.load(userDefaults: defaults)
        XCTAssertEqual(entries[0].displayName, "file2.json")
        XCTAssertEqual(entries[1].displayName, "file1.json")
    }

    // MARK: - remove

    func testRemoveDeletesEntry() {
        let url = makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }

        let entry = RecentFilesStore.add(url: url, userDefaults: defaults)!
        RecentFilesStore.remove(id: entry.id, userDefaults: defaults)
        XCTAssertTrue(RecentFilesStore.load(userDefaults: defaults).isEmpty)
    }

    // MARK: - clear

    func testClearRemovesAllEntries() {
        let url1 = makeTemporaryFile(name: "a.json")
        let url2 = makeTemporaryFile(name: "b.json")
        defer {
            try? FileManager.default.removeItem(at: url1)
            try? FileManager.default.removeItem(at: url2)
        }

        RecentFilesStore.add(url: url1, userDefaults: defaults)
        RecentFilesStore.add(url: url2, userDefaults: defaults)
        RecentFilesStore.clear(userDefaults: defaults)
        XCTAssertTrue(RecentFilesStore.load(userDefaults: defaults).isEmpty)
    }

    // MARK: - stale entries

    func testResolveURLReturnsNilForDeletedFile() {
        let url = makeTemporaryFile(name: "stale.json")
        let entry = RecentFilesStore.add(url: url, userDefaults: defaults)!
        try? FileManager.default.removeItem(at: url)

        let resolved = RecentFilesStore.resolveURL(entry: entry)
        XCTAssertNil(resolved)
    }

    // MARK: - migration from legacy key

    func testMigrationFromLegacySingleBookmark() {
        // Simulate old single-bookmark key
        let fakeBookmarkData = Data("legacy".utf8)
        defaults.set(fakeBookmarkData, forKey: "lastImportedFileBookmark")

        let entries = RecentFilesStore.load(userDefaults: defaults)
        // Migration creates one entry from legacy data
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].displayName, "Imported File")
        // Legacy key is removed
        XCTAssertNil(defaults.data(forKey: "lastImportedFileBookmark"))
    }

    func testMigrationDoesNotRunWhenEntriesAlreadyExist() {
        // Pre-populate with a valid entry
        let url = makeTemporaryFile(name: "existing.json")
        defer { try? FileManager.default.removeItem(at: url) }
        RecentFilesStore.add(url: url, userDefaults: defaults)

        // Set legacy key too
        defaults.set(Data("legacy".utf8), forKey: "lastImportedFileBookmark")

        let entries = RecentFilesStore.load(userDefaults: defaults)
        // Should still have only the one pre-existing entry; no migration
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].displayName, "existing.json")
    }

    // MARK: - Helpers

    private func makeTemporaryFile(name: String = "test_\(UUID().uuidString).json") -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        FileManager.default.createFile(atPath: url.path, contents: Data("{}".utf8))
        return url
    }
}
