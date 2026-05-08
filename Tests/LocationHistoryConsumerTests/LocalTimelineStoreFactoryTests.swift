import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-4 coverage for `LocalTimelineStoreFactory` — verifies the
/// production-shaped open lifecycle (ensure dirs, mark backup-excluded,
/// apply protection, open SQLite store) under a temporary sandbox root.
final class LocalTimelineStoreFactoryTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTSFactory-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    func testOpenStoreCreatesAllDirectoriesAndDBFile() throws {
        let factory = LocalTimelineStoreFactory.temporary(under: tempDir)
        let store = try factory.openStore()
        defer { store.close() }

        let fm = FileManager.default
        for url in factory.locations.allRoots {
            var isDir: ObjCBool = false
            XCTAssertTrue(fm.fileExists(atPath: url.path, isDirectory: &isDir),
                          "\(url.lastPathComponent) must exist")
            XCTAssertTrue(isDir.boolValue, "\(url.lastPathComponent) must be a directory")
        }
        XCTAssertTrue(fm.fileExists(atPath: factory.locations.databaseFileURL.path),
                      "DB file must exist after openStore")
        XCTAssertEqual(try store.userVersion(), 2)
    }

    func testOpenStorePreservesUserVersion2() throws {
        let factory = LocalTimelineStoreFactory.temporary(under: tempDir)
        let store = try factory.openStore()
        defer { store.close() }
        XCTAssertEqual(try store.userVersion(), 2)
    }

    func testOpenStoreIsIdempotent() throws {
        let factory = LocalTimelineStoreFactory.temporary(under: tempDir)
        do {
            let first = try factory.openStore()
            try first.insertImport(.init(id: "imp-1", sourceFilename: "a.json",
                                         createdAt: "2026-05-08T00:00:00Z"))
            first.close()
        }

        let second = try factory.openStore()
        defer { second.close() }
        XCTAssertEqual(try second.userVersion(), 2)
        XCTAssertEqual(try second.countImports(), 1,
                       "Reopen at the same path must preserve previously inserted rows")
    }

    func testOpenStoreRespectsInjectedTempRoot() throws {
        let factory = LocalTimelineStoreFactory.temporary(under: tempDir)
        let store = try factory.openStore()
        defer { store.close() }
        XCTAssertTrue(store.path.contains(tempDir.path),
                      "DB path \(store.path) must live under injected tempDir \(tempDir.path)")
    }

    func testFactoryDoesNotCreateAnyAppExportArtifact() throws {
        let factory = LocalTimelineStoreFactory.temporary(under: tempDir)
        let store = try factory.openStore()
        defer { store.close() }

        let fm = FileManager.default
        for root in factory.locations.allRoots {
            guard let enumerator = fm.enumerator(at: root,
                                                 includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in enumerator {
                XCTAssertNotEqual(url.lastPathComponent, "app_export.json",
                                  "Factory must not create app_export.json artefacts")
            }
        }
    }
}
