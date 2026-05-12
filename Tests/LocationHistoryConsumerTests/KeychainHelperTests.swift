import XCTest
@testable import LocationHistoryConsumerAppSupport

#if canImport(Security)
import Security
#endif

final class KeychainHelperTests: XCTestCase {

    private static let testKey = "lh2gpx.tests.keychain.helper.afterFirstUnlock"
    private static let testValue = "test-token-value"

    override func setUp() {
        super.setUp()
        KeychainHelper.delete(key: Self.testKey)
    }

    override func tearDown() {
        KeychainHelper.delete(key: Self.testKey)
        super.tearDown()
    }

    func testSaveAndReadRoundTrip() throws {
        try KeychainHelper.save(key: Self.testKey, value: Self.testValue)
        XCTAssertEqual(KeychainHelper.get(key: Self.testKey), Self.testValue)
        KeychainHelper.delete(key: Self.testKey)
        XCTAssertNil(KeychainHelper.get(key: Self.testKey))
    }

    func testOverwriteUpdatesValue() throws {
        try KeychainHelper.save(key: Self.testKey, value: "first")
        try KeychainHelper.save(key: Self.testKey, value: "second")
        XCTAssertEqual(KeychainHelper.get(key: Self.testKey), "second")
    }

    func testSaveEmptyStringRoundTrip() throws {
        try KeychainHelper.save(key: Self.testKey, value: "")
        XCTAssertEqual(KeychainHelper.get(key: Self.testKey), "")
    }

    func testEncodingFailedErrorCaseExists() {
        let error: KeychainHelper.KeychainError = .encodingFailed
        XCTAssertNotNil(error)
    }

    #if canImport(Security)
    /// Reads the `kSecAttrAccessible` value for a stored item, or returns
    /// `nil` if the test host doesn't expose it. The SwiftPM macOS test host
    /// uses the user's file-based login keychain, which silently omits
    /// `kSecAttrAccessible` from the attribute dictionary even though the
    /// API call accepts the attribute on write — the same code path on iOS
    /// stores the value as set. We surface this difference as an XCTSkip
    /// rather than a false failure.
    private func readAccessibilityAttribute(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnAttributes as String: true as CFBoolean,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var ref: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &ref)
        guard status == errSecSuccess, let attrs = ref as? [String: Any] else {
            return nil
        }
        return attrs[kSecAttrAccessible as String] as? String
    }

    /// On hosts where the read-back actually surfaces the accessibility
    /// attribute, this test verifies that `save(...)` sets
    /// `kSecAttrAccessibleAfterFirstUnlock`. On the SwiftPM macOS test host
    /// the attribute is not returned in the attribute dictionary, so the
    /// test is skipped with a clear note rather than passed silently.
    func testSaveSetsAfterFirstUnlockAccessibility() throws {
        try KeychainHelper.save(key: Self.testKey, value: Self.testValue)
        guard let accessible = readAccessibilityAttribute(for: Self.testKey) else {
            throw XCTSkip("This keychain host does not surface kSecAttrAccessible on read-back (typical for SwiftPM macOS test host using the file-based login keychain). Save path itself returned success; iOS device/simulator tests are required to verify the stored class.")
        }
        XCTAssertEqual(
            accessible,
            kSecAttrAccessibleAfterFirstUnlock as String,
            "Stored keychain item must use AfterFirstUnlock so the live-upload background task can read the bearer token while the device is locked."
        )
    }

    /// On hosts that surface the attribute, verify that overwriting an item
    /// previously stored with WhenUnlocked migrates it to AfterFirstUnlock.
    /// Skipped on hosts that don't return the attribute (see comment above).
    func testOverwriteMigratesAccessibilityToAfterFirstUnlock() throws {
        let seedData = Data("legacy".utf8)
        let seedQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.testKey,
            kSecValueData as String: seedData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        let seedStatus = SecItemAdd(seedQuery as CFDictionary, nil)
        guard seedStatus == errSecSuccess else {
            throw XCTSkip("Could not seed legacy keychain item (OSStatus \(seedStatus)).")
        }

        try KeychainHelper.save(key: Self.testKey, value: Self.testValue)

        guard let accessible = readAccessibilityAttribute(for: Self.testKey) else {
            throw XCTSkip("This keychain host does not surface kSecAttrAccessible on read-back. Save/update path itself returned success.")
        }
        XCTAssertEqual(
            accessible,
            kSecAttrAccessibleAfterFirstUnlock as String
        )
    }
    #endif
}
