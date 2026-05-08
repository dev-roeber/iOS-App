import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-4 coverage for `LocalTimelineStorageLocations` — verifies the
/// production layout names and the temporary-sandbox helper used by tests.
final class LocalTimelineStorageLocationsTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTSStorageLocations-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    func testTemporaryLayoutPlacesRootsRelativeToInjectedRoot() {
        let locations = LocalTimelineStorageLocations.temporary(under: tempDir)
        XCTAssertEqual(locations.databaseRoot.lastPathComponent, "Imports")
        XCTAssertEqual(locations.renderCacheRoot.lastPathComponent, "RenderCache")
        XCTAssertEqual(locations.importStagingRoot.lastPathComponent, "ImportStaging")
        XCTAssertEqual(locations.exportStagingRoot.lastPathComponent, "ExportStaging")

        // All four roots must live directly under tempDir.
        for url in locations.allRoots {
            XCTAssertEqual(url.deletingLastPathComponent().path, tempDir.path)
        }
    }

    func testDatabaseFileURLsUseExpectedNames() {
        let locations = LocalTimelineStorageLocations.temporary(under: tempDir)
        XCTAssertEqual(locations.databaseFileURL.lastPathComponent, "store.sqlite")
        XCTAssertEqual(locations.walFileURL.lastPathComponent, "store.sqlite-wal")
        XCTAssertEqual(locations.shmFileURL.lastPathComponent, "store.sqlite-shm")
    }

    func testAllRootsContainsAllFour() {
        let locations = LocalTimelineStorageLocations.temporary(under: tempDir)
        XCTAssertEqual(locations.allRoots.count, 4)
        XCTAssertTrue(locations.allRoots.contains(locations.databaseRoot))
        XCTAssertTrue(locations.allRoots.contains(locations.renderCacheRoot))
        XCTAssertTrue(locations.allRoots.contains(locations.importStagingRoot))
        XCTAssertTrue(locations.allRoots.contains(locations.exportStagingRoot))
    }

    func testEnsureDirectoriesExistCreatesAllRoots() throws {
        let locations = LocalTimelineStorageLocations.temporary(under: tempDir)
        let fm = FileManager.default
        for url in locations.allRoots {
            XCTAssertFalse(fm.fileExists(atPath: url.path),
                           "Precondition: \(url.lastPathComponent) must not exist yet")
        }

        try locations.ensureDirectoriesExist()

        for url in locations.allRoots {
            var isDir: ObjCBool = false
            XCTAssertTrue(fm.fileExists(atPath: url.path, isDirectory: &isDir),
                          "\(url.lastPathComponent) should exist after ensureDirectoriesExist")
            XCTAssertTrue(isDir.boolValue, "\(url.lastPathComponent) should be a directory")
        }
    }

    func testEnsureDirectoriesExistIsIdempotent() throws {
        let locations = LocalTimelineStorageLocations.temporary(under: tempDir)
        try locations.ensureDirectoriesExist()
        // Drop a marker file so we can confirm the second call doesn't wipe it.
        let marker = locations.renderCacheRoot.appendingPathComponent("marker.txt")
        try Data("hi".utf8).write(to: marker)
        try locations.ensureDirectoriesExist()

        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path),
                      "Marker file must survive a second ensureDirectoriesExist call")
        for url in locations.allRoots {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        }
    }

    func testProductionLayoutContainsProjectFolder() throws {
        let locations = try LocalTimelineStorageLocations.production()
        XCTAssertTrue(locations.databaseRoot.path.contains("LocationHistory2GPX"),
                      "databaseRoot must live under the LocationHistory2GPX project folder")
        XCTAssertEqual(locations.databaseRoot.lastPathComponent, "Imports")
        XCTAssertEqual(locations.renderCacheRoot.lastPathComponent, "RenderCache")
        XCTAssertEqual(locations.importStagingRoot.lastPathComponent, "ImportStaging")
        XCTAssertEqual(locations.exportStagingRoot.lastPathComponent, "ExportStaging")
        XCTAssertTrue(locations.renderCacheRoot.path.contains("LocationHistory2GPX"))
        XCTAssertTrue(locations.importStagingRoot.path.contains("LocationHistory2GPX"))
        XCTAssertTrue(locations.exportStagingRoot.path.contains("LocationHistory2GPX"))
    }
}
