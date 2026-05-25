import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-4 coverage for `LocalTimelineFileProtection` — Data-Protection
/// kapselung. Linux ist No-Op; Darwin-Hooks bleiben passiv.
final class LocalTimelineFileProtectionTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTSFileProtection-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    func testDefaultProtectionDescriptionIsNoopOnLinux() {
        let description = LocalTimelineFileProtection.defaultProtectionDescription
        #if !canImport(Darwin)
        XCTAssertEqual(description, "noop-linux")
        #else
        XCTAssertFalse(description.isEmpty)
        #endif
    }

    func testApplyDefaultProtectionOnExistingDirectoryDoesNotThrow() throws {
        let dir = tempDir.appendingPathComponent("subdir", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        XCTAssertNoThrow(try LocalTimelineFileProtection.applyDefaultProtection(to: dir))
    }

    func testApplyDefaultProtectionOnMissingPathThrowsFileNotFound() {
        let missing = tempDir.appendingPathComponent("missing-\(UUID().uuidString)")
        XCTAssertThrowsError(try LocalTimelineFileProtection.applyDefaultProtection(to: missing)) { error in
            guard let protectionError = error as? LocalTimelineFileProtection.ProtectionError else {
                XCTFail("Expected ProtectionError, got \(error)")
                return
            }
            switch protectionError {
            case .fileNotFound(let path):
                XCTAssertEqual(path, missing.path)
            }
        }
    }

    func testApplyDefaultProtectionIfPresentSkipsMissing() throws {
        let existing = tempDir.appendingPathComponent("present", isDirectory: true)
        try FileManager.default.createDirectory(at: existing, withIntermediateDirectories: true)
        let missing = tempDir.appendingPathComponent("absent-\(UUID().uuidString)")

        XCTAssertNoThrow(
            try LocalTimelineFileProtection.applyDefaultProtectionIfPresent(urls: [existing, missing])
        )
    }

    /// Darwin: setAttributes must actually flip the protection class
    /// to `completeUnlessOpen` on a real file.
    func testApplyDefaultProtectionSetsAttributeOnDarwin() throws {
        let fileURL = tempDir.appendingPathComponent("protected.bin")
        try Data([0x01, 0x02]).write(to: fileURL)

        XCTAssertNoThrow(try LocalTimelineFileProtection.applyDefaultProtection(to: fileURL))

        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        let current = LocalTimelineFileProtection.currentProtection(of: fileURL)
        XCTAssertEqual(current, FileProtectionType.completeUnlessOpen.rawValue)
        #elseif canImport(Darwin)
        // macOS reports the system default (CompleteUntilFirstUserAuthentication
        // or none) — setAttributes(.protectionKey) is iOS-family only.
        XCTAssertNotNil(LocalTimelineFileProtection.currentProtection(of: fileURL))
        #else
        XCTAssertNil(LocalTimelineFileProtection.currentProtection(of: fileURL))
        #endif
    }

    func testFavoriteEntryStoreWritesWithProtectionOnDarwin() throws {
        let fileURL = tempDir.appendingPathComponent("fav.json")
        let suiteName = "LTSFavTest-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = FavoriteEntryStore(
            fileURL: fileURL,
            userDefaults: defaults,
            legacySource: { [] }
        )

        _ = store.setDayFavorite("2026-05-25", isFavorite: true)

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        let current = LocalTimelineFileProtection.currentProtection(of: fileURL)
        XCTAssertEqual(current, FileProtectionType.completeUnlessOpen.rawValue)
        #endif
        defaults.removePersistentDomain(forName: suiteName)
    }
}
