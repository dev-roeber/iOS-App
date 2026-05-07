import XCTest
@testable import LocationHistoryConsumerAppSupport

final class AppPreferencesUploadURLValidationTests: XCTestCase {
    private let urlKey = "app.preferences.liveTrackingServerUploadURL"
    private let bearerTokenKey = "app.preferences.liveTrackingServerUploadBearerToken"
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "AppPreferencesUploadURLValidationTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        KeychainHelper.delete(key: bearerTokenKey)
    }

    override func tearDown() {
        KeychainHelper.delete(key: bearerTokenKey)
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Valid inputs

    func testValidHTTPSURLAccepted() {
        MainActor.assumeIsolated {
            let prefs = AppPreferences(userDefaults: defaults)
            prefs.liveLocationServerUploadURLString = "https://example.com/upload"
            XCTAssertEqual(prefs.liveLocationServerUploadURLString, "https://example.com/upload")
            XCTAssertEqual(defaults.string(forKey: urlKey), "https://example.com/upload")
        }
    }

    func testHTTPLocalhostAccepted() {
        MainActor.assumeIsolated {
            let prefs = AppPreferences(userDefaults: defaults)
            prefs.liveLocationServerUploadURLString = "http://localhost:8080"
            XCTAssertEqual(prefs.liveLocationServerUploadURLString, "http://localhost:8080")
            XCTAssertEqual(defaults.string(forKey: urlKey), "http://localhost:8080")
        }
    }

    func testHTTP127AddressAccepted() {
        MainActor.assumeIsolated {
            let prefs = AppPreferences(userDefaults: defaults)
            prefs.liveLocationServerUploadURLString = "http://127.0.0.1:3000"
            XCTAssertEqual(prefs.liveLocationServerUploadURLString, "http://127.0.0.1:3000")
            XCTAssertEqual(defaults.string(forKey: urlKey), "http://127.0.0.1:3000")
        }
    }

    func testHTTPIPv6LocalhostAccepted() {
        MainActor.assumeIsolated {
            let prefs = AppPreferences(userDefaults: defaults)
            prefs.liveLocationServerUploadURLString = "http://[::1]:3000"
            XCTAssertEqual(prefs.liveLocationServerUploadURLString, "http://[::1]:3000")
            XCTAssertEqual(defaults.string(forKey: urlKey), "http://[::1]:3000")
        }
    }

    func testEmptyStringAccepted() {
        MainActor.assumeIsolated {
            let prefs = AppPreferences(userDefaults: defaults)
            // Seed a valid URL first so we can confirm it gets cleared.
            prefs.liveLocationServerUploadURLString = "https://example.com/upload"
            XCTAssertEqual(prefs.liveLocationServerUploadURLString, "https://example.com/upload")

            prefs.liveLocationServerUploadURLString = ""
            XCTAssertEqual(prefs.liveLocationServerUploadURLString, "")
            XCTAssertEqual(defaults.string(forKey: urlKey), "")
        }
    }

    // MARK: - Invalid inputs

    func testHTTPRemoteURLRejected() {
        MainActor.assumeIsolated {
            let prefs = AppPreferences(userDefaults: defaults)
            prefs.liveLocationServerUploadURLString = "https://good.example.com/u"
            prefs.liveLocationServerUploadURLString = "http://evil.example.com"
            // Setter must have reverted to previous valid value.
            XCTAssertEqual(prefs.liveLocationServerUploadURLString, "https://good.example.com/u")
            XCTAssertEqual(defaults.string(forKey: urlKey), "https://good.example.com/u")
        }
    }

    func testGarbageInputRejected() {
        MainActor.assumeIsolated {
            let prefs = AppPreferences(userDefaults: defaults)
            prefs.liveLocationServerUploadURLString = "https://good.example.com/u"
            prefs.liveLocationServerUploadURLString = "not a url"
            XCTAssertEqual(prefs.liveLocationServerUploadURLString, "https://good.example.com/u")
            XCTAssertEqual(defaults.string(forKey: urlKey), "https://good.example.com/u")
        }
    }

    func testTokenUntouchedWhenURLRejected() {
        MainActor.assumeIsolated {
            let prefs = AppPreferences(userDefaults: defaults)
            prefs.liveLocationServerUploadBearerToken = "secret-token-xyz"
            let tokenBefore = prefs.liveLocationServerUploadBearerToken

            prefs.liveLocationServerUploadURLString = "http://evil.example.com"
            XCTAssertEqual(prefs.liveLocationServerUploadBearerToken, tokenBefore)
            XCTAssertEqual(prefs.liveLocationServerUploadBearerToken, "secret-token-xyz")
        }
    }
}
