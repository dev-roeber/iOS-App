import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-4 coverage for `LocalTimelineStoreLifecycle` — the high-level
/// "user pressed Delete imported data" boundary that wipes DB rows, the
/// SQLite file (incl. WAL/SHM siblings) and the cache/staging trees.
final class LocalTimelineStoreLifecycleManagerTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTSLifecycleMgr-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    private func assertAllRootsExist(_ locations: LocalTimelineStorageLocations,
                                     file: StaticString = #file, line: UInt = #line) {
        let fm = FileManager.default
        for url in locations.allRoots {
            var isDir: ObjCBool = false
            XCTAssertTrue(fm.fileExists(atPath: url.path, isDirectory: &isDir),
                          "\(url.lastPathComponent) should exist", file: file, line: line)
            XCTAssertTrue(isDir.boolValue,
                          "\(url.lastPathComponent) should be a directory",
                          file: file, line: line)
        }
    }

    func testDeleteAllOnEmptyLifecycleSucceeds() throws {
        let locations = LocalTimelineStorageLocations.temporary(under: tempDir)
        let lifecycle = LocalTimelineStoreLifecycle(locations: locations)

        let report = try lifecycle.deleteAllLocalTimelineData(store: nil)
        XCTAssertFalse(report.didWipeRowsViaStore)
        XCTAssertNil(report.rowWipeError)
        XCTAssertTrue(report.removedDBFiles.isEmpty)
        XCTAssertTrue(report.removedDirectories.isEmpty)

        // Roots must be re-created (idempotent ensure pass).
        assertAllRootsExist(locations)
    }

    func testDeleteAllAfterImportRemovesDBRowsAndFiles() throws {
        let factory = LocalTimelineStoreFactory.temporary(under: tempDir)
        let store = try factory.openStore()
        try store.insertImport(.init(id: "imp-1", sourceFilename: "a.json",
                                     createdAt: "2026-05-08T00:00:00Z"))
        try store.insertDay(.init(id: "day-1", importId: "imp-1", date: "2026-05-08",
                                  routeCount: 0, visitCount: 0, distanceM: 0))
        store.close()

        // Drop a stray file under each cache/staging root.
        let renderFile = factory.locations.renderCacheRoot.appendingPathComponent("tile.bin")
        let importFile = factory.locations.importStagingRoot.appendingPathComponent("scratch.json")
        let exportFile = factory.locations.exportStagingRoot.appendingPathComponent("draft.gpx")
        try Data("r".utf8).write(to: renderFile)
        try Data("i".utf8).write(to: importFile)
        try Data("e".utf8).write(to: exportFile)

        let lifecycle = LocalTimelineStoreLifecycle(factory: factory)
        let report = try lifecycle.deleteAllLocalTimelineData(store: nil)

        XCTAssertFalse(report.didWipeRowsViaStore,
                       "No store handle was passed; row-wipe must not be claimed")
        XCTAssertTrue(report.removedDBFiles.contains("store.sqlite"),
                      "Report must list the removed DB file")
        XCTAssertTrue(report.removedDirectories.contains("RenderCache"))
        XCTAssertTrue(report.removedDirectories.contains("ImportStaging"))
        XCTAssertTrue(report.removedDirectories.contains("ExportStaging"))

        let fm = FileManager.default
        XCTAssertFalse(fm.fileExists(atPath: factory.locations.databaseFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: renderFile.path))
        XCTAssertFalse(fm.fileExists(atPath: importFile.path))
        XCTAssertFalse(fm.fileExists(atPath: exportFile.path))

        // All roots must be back as empty directories.
        assertAllRootsExist(factory.locations)
        for root in [factory.locations.renderCacheRoot,
                     factory.locations.importStagingRoot,
                     factory.locations.exportStagingRoot] {
            let contents = try fm.contentsOfDirectory(atPath: root.path)
            XCTAssertTrue(contents.isEmpty,
                          "\(root.lastPathComponent) must be empty after deleteAll, got \(contents)")
        }
    }

    func testDeleteAllWithOpenStoreWipesRowsAndClosesHandle() throws {
        let factory = LocalTimelineStoreFactory.temporary(under: tempDir)
        let store = try factory.openStore()
        try store.insertImport(.init(id: "imp-1", sourceFilename: "a.json",
                                     createdAt: "2026-05-08T00:00:00Z"))

        let lifecycle = LocalTimelineStoreLifecycle(factory: factory)
        let report = try lifecycle.deleteAllLocalTimelineData(store: store)
        XCTAssertTrue(report.didWipeRowsViaStore)
        XCTAssertNil(report.rowWipeError)

        XCTAssertFalse(FileManager.default.fileExists(atPath: factory.locations.databaseFileURL.path))

        let reopened = try factory.openStore()
        defer { reopened.close() }
        XCTAssertEqual(try reopened.countImports(), 0)
        XCTAssertEqual(try reopened.userVersion(), 2)
    }

    func testDeleteAllIsIdempotent() throws {
        let factory = LocalTimelineStoreFactory.temporary(under: tempDir)
        let store = try factory.openStore()
        store.close()

        let lifecycle = LocalTimelineStoreLifecycle(factory: factory)
        XCTAssertNoThrow(try lifecycle.deleteAllLocalTimelineData(store: nil))
        XCTAssertNoThrow(try lifecycle.deleteAllLocalTimelineData(store: nil))
        assertAllRootsExist(factory.locations)
    }

    func testDeleteAllWalShmFilesAreRemovedIfPresent() throws {
        let locations = LocalTimelineStorageLocations.temporary(under: tempDir)
        try locations.ensureDirectoriesExist()

        // Manually create the DB plus WAL/SHM siblings so we can observe
        // their removal independently of an active SQLite handle.
        try Data("db".utf8).write(to: locations.databaseFileURL)
        try Data("wal".utf8).write(to: locations.walFileURL)
        try Data("shm".utf8).write(to: locations.shmFileURL)

        let lifecycle = LocalTimelineStoreLifecycle(locations: locations)
        let report = try lifecycle.deleteAllLocalTimelineData(store: nil)

        XCTAssertTrue(report.removedDBFiles.contains("store.sqlite"))
        XCTAssertTrue(report.removedDBFiles.contains("store.sqlite-wal"))
        XCTAssertTrue(report.removedDBFiles.contains("store.sqlite-shm"))

        let fm = FileManager.default
        XCTAssertFalse(fm.fileExists(atPath: locations.databaseFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: locations.walFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: locations.shmFileURL.path))
    }

    func testDeleteAllSurvivesMissingDirectories() throws {
        // Do NOT call ensureDirectoriesExist beforehand — none of the four
        // roots exist when the lifecycle is asked to clean up.
        let locations = LocalTimelineStorageLocations.temporary(under: tempDir)
        let lifecycle = LocalTimelineStoreLifecycle(locations: locations)
        XCTAssertNoThrow(try lifecycle.deleteAllLocalTimelineData(store: nil))
        assertAllRootsExist(locations)
    }

    func testReopenAfterDeleteAllReturnsEmptyStore() throws {
        let factory = LocalTimelineStoreFactory.temporary(under: tempDir)
        let firstStore = try factory.openStore()
        try firstStore.insertImport(.init(id: "imp-x", sourceFilename: "x.json",
                                          createdAt: "2026-05-08T00:00:00Z"))

        let lifecycle = LocalTimelineStoreLifecycle(factory: factory)
        _ = try lifecycle.deleteAllLocalTimelineData(store: firstStore)

        let reopened = try factory.openStore()
        defer { reopened.close() }
        XCTAssertEqual(try reopened.countImports(), 0)
    }
}
