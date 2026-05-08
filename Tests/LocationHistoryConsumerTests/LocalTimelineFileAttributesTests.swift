import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-4 coverage for `LocalTimelineFileAttributes` — verifies the
/// backup-exclusion helper's no-op semantics on Linux and the
/// `fileNotFound` error path that's shared across platforms.
final class LocalTimelineFileAttributesTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTSFileAttributes-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    func testMarkExcludedFromBackupOnExistingDirectoryIsLinuxNoOp() throws {
        let dir = tempDir.appendingPathComponent("subdir", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        XCTAssertNoThrow(try LocalTimelineFileAttributes.markExcludedFromBackup(url: dir))
        let isExcluded = try LocalTimelineFileAttributes.isExcludedFromBackup(url: dir)
        #if !canImport(Darwin)
        XCTAssertFalse(isExcluded, "Linux helper must always report false")
        #else
        // On Darwin either value is acceptable; the call must succeed.
        _ = isExcluded
        #endif
    }

    func testMarkExcludedFromBackupOnMissingPathThrowsFileNotFound() {
        let missing = tempDir.appendingPathComponent("does-not-exist-\(UUID().uuidString)")
        XCTAssertThrowsError(try LocalTimelineFileAttributes.markExcludedFromBackup(url: missing)) { error in
            guard let attributeError = error as? LocalTimelineFileAttributes.AttributeError else {
                XCTFail("Expected AttributeError, got \(error)")
                return
            }
            switch attributeError {
            case .fileNotFound(let path):
                XCTAssertEqual(path, missing.path)
            default:
                XCTFail("Expected .fileNotFound, got \(attributeError)")
            }
        }
    }

    func testIsExcludedFromBackupThrowsForMissingPath() {
        let missing = tempDir.appendingPathComponent("missing-\(UUID().uuidString)")
        XCTAssertThrowsError(try LocalTimelineFileAttributes.isExcludedFromBackup(url: missing)) { error in
            guard let attributeError = error as? LocalTimelineFileAttributes.AttributeError else {
                XCTFail("Expected AttributeError, got \(error)")
                return
            }
            switch attributeError {
            case .fileNotFound(let path):
                XCTAssertEqual(path, missing.path)
            default:
                XCTFail("Expected .fileNotFound, got \(attributeError)")
            }
        }
    }

    func testMarkExcludedFromBackupIfPresentSkipsMissing() throws {
        let existing = tempDir.appendingPathComponent("present", isDirectory: true)
        try FileManager.default.createDirectory(at: existing, withIntermediateDirectories: true)
        let missing = tempDir.appendingPathComponent("absent-\(UUID().uuidString)")

        XCTAssertNoThrow(
            try LocalTimelineFileAttributes.markExcludedFromBackupIfPresent(urls: [existing, missing])
        )
    }
}
