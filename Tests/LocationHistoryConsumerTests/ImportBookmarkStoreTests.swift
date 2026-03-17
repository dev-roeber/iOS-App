import XCTest
@testable import LocationHistoryConsumerAppSupport

final class ImportBookmarkStoreTests: XCTestCase {
    override func tearDown() {
        ImportBookmarkStore.clear()
        super.tearDown()
    }

    func testHasStoredBookmarkIsFalseInitially() {
        ImportBookmarkStore.clear()
        XCTAssertFalse(ImportBookmarkStore.hasStoredBookmark)
    }

    func testClearRemovesStoredBookmark() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test_bookmark.json")
        FileManager.default.createFile(atPath: url.path, contents: Data("{}".utf8))
        defer { try? FileManager.default.removeItem(at: url) }

        ImportBookmarkStore.save(url: url)
        ImportBookmarkStore.clear()
        XCTAssertFalse(ImportBookmarkStore.hasStoredBookmark)
        XCTAssertNil(ImportBookmarkStore.restore())
    }

    func testSaveStoresBookmarkData() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test_save_bookmark.json")
        FileManager.default.createFile(atPath: url.path, contents: Data("{}".utf8))
        defer { try? FileManager.default.removeItem(at: url) }

        let data = ImportBookmarkStore.save(url: url)
        XCTAssertNotNil(data)
        XCTAssertTrue(ImportBookmarkStore.hasStoredBookmark)
    }

    func testRestoreReturnsUrlAfterSave() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test_restore_bookmark.json")
        FileManager.default.createFile(atPath: url.path, contents: Data("{}".utf8))
        defer { try? FileManager.default.removeItem(at: url) }

        ImportBookmarkStore.save(url: url)
        let restored = ImportBookmarkStore.restore()
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.lastPathComponent, "test_restore_bookmark.json")
    }

    func testRestoreReturnsNilWhenNoBookmarkStored() {
        ImportBookmarkStore.clear()
        XCTAssertNil(ImportBookmarkStore.restore())
    }

    func testRestoreClearsBookmarkWhenFileIsGone() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test_gone_\(UUID().uuidString).json")
        FileManager.default.createFile(atPath: url.path, contents: Data("{}".utf8))

        ImportBookmarkStore.save(url: url)
        XCTAssertTrue(ImportBookmarkStore.hasStoredBookmark)

        try? FileManager.default.removeItem(at: url)

        let restored = ImportBookmarkStore.restore()
        // Bookmark resolution may still succeed for recently deleted files on some platforms,
        // but if it fails the store should clean up.
        if restored == nil {
            XCTAssertFalse(ImportBookmarkStore.hasStoredBookmark)
        }
    }

    func testRestoreReturnsNilForCorruptBookmarkData() {
        UserDefaults.standard.set(Data("not-a-bookmark".utf8), forKey: "lastImportedFileBookmark")
        let restored = ImportBookmarkStore.restore()
        XCTAssertNil(restored)
        XCTAssertFalse(ImportBookmarkStore.hasStoredBookmark)
    }
}
