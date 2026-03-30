import XCTest
@testable import LocationHistoryConsumerAppSupport

final class AppPreferencesTests: XCTestCase {
    private let bearerTokenKey = "app.preferences.liveTrackingServerUploadBearerToken"
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "AppPreferencesTests-\(UUID().uuidString)"
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

    func testDefaultsAreSensible() {
        MainActor.assumeIsolated {
            let preferences = AppPreferences(userDefaults: defaults)

            XCTAssertEqual(preferences.distanceUnit, .metric)
            XCTAssertEqual(preferences.startTab, .overview)
            XCTAssertEqual(preferences.preferredMapStyle, .standard)
            XCTAssertTrue(preferences.showsTechnicalImportDetails)
            XCTAssertEqual(preferences.appLanguage, .english)
            XCTAssertEqual(preferences.liveTrackingAccuracy, .balanced)
            XCTAssertEqual(preferences.liveTrackingDetail, .balanced)
            XCTAssertFalse(preferences.allowsBackgroundLiveTracking)
            XCTAssertFalse(preferences.sendsLiveLocationToServer)
            XCTAssertEqual(
                preferences.liveLocationServerUploadURLString,
                LiveLocationServerUploadConfiguration.defaultTestEndpointURLString
            )
            XCTAssertEqual(preferences.liveLocationServerUploadBearerToken, "")
            XCTAssertEqual(preferences.liveTrackRecorderConfiguration.maximumAcceptedAccuracyM, 65)
            XCTAssertEqual(preferences.liveTrackRecorderConfiguration.minimumDistanceDeltaM, 15)
        }
    }

    func testStoredValuesAreLoaded() {
        defaults.set(AppDistanceUnitPreference.imperial.rawValue, forKey: "app.preferences.distanceUnit")
        defaults.set(AppStartTabPreference.insights.rawValue, forKey: "app.preferences.startTab")
        defaults.set(AppMapStylePreference.hybrid.rawValue, forKey: "app.preferences.mapStyle")
        defaults.set(false, forKey: "app.preferences.showsTechnicalImportDetails")
        defaults.set(AppLanguagePreference.german.rawValue, forKey: "app.preferences.appLanguage")
        defaults.set(AppLiveTrackingAccuracyPreference.strict.rawValue, forKey: "app.preferences.liveTrackingAccuracy")
        defaults.set(AppLiveTrackingDetailPreference.detailed.rawValue, forKey: "app.preferences.liveTrackingDetail")
        defaults.set(true, forKey: "app.preferences.liveTrackingBackground")
        defaults.set(true, forKey: "app.preferences.liveTrackingServerUploadEnabled")
        defaults.set("https://example.invalid/live", forKey: "app.preferences.liveTrackingServerUploadURL")
        try? KeychainHelper.save(key: bearerTokenKey, value: "secret")

        MainActor.assumeIsolated {
            let preferences = AppPreferences(userDefaults: defaults)

            XCTAssertEqual(preferences.distanceUnit, .imperial)
            XCTAssertEqual(preferences.startTab, .insights)
            XCTAssertEqual(preferences.preferredMapStyle, .hybrid)
            XCTAssertFalse(preferences.showsTechnicalImportDetails)
            XCTAssertEqual(preferences.appLanguage, .german)
            XCTAssertEqual(preferences.liveTrackingAccuracy, .strict)
            XCTAssertEqual(preferences.liveTrackingDetail, .detailed)
            XCTAssertTrue(preferences.allowsBackgroundLiveTracking)
            XCTAssertTrue(preferences.sendsLiveLocationToServer)
            XCTAssertEqual(preferences.liveLocationServerUploadURLString, "https://example.invalid/live")
            XCTAssertEqual(preferences.liveLocationServerUploadBearerToken, "secret")
            XCTAssertEqual(preferences.liveTrackRecorderConfiguration.maximumAcceptedAccuracyM, 25)
            XCTAssertEqual(preferences.liveTrackRecorderConfiguration.minimumDistanceDeltaM, 8)
        }
    }

    func testResetRestoresDefaults() {
        MainActor.assumeIsolated {
            let preferences = AppPreferences(userDefaults: defaults)
            preferences.distanceUnit = .imperial
            preferences.startTab = .export
            preferences.preferredMapStyle = .hybrid
            preferences.showsTechnicalImportDetails = false
            preferences.appLanguage = .german
            preferences.liveTrackingAccuracy = .strict
            preferences.liveTrackingDetail = .batterySaver
            preferences.allowsBackgroundLiveTracking = true
            preferences.sendsLiveLocationToServer = true
            preferences.liveLocationServerUploadURLString = "https://example.invalid/custom"
            preferences.liveLocationServerUploadBearerToken = "token"

            preferences.reset()

            XCTAssertEqual(preferences.distanceUnit, .metric)
            XCTAssertEqual(preferences.startTab, .overview)
            XCTAssertEqual(preferences.preferredMapStyle, .standard)
            XCTAssertTrue(preferences.showsTechnicalImportDetails)
            XCTAssertEqual(preferences.appLanguage, .english)
            XCTAssertEqual(preferences.liveTrackingAccuracy, .balanced)
            XCTAssertEqual(preferences.liveTrackingDetail, .balanced)
            XCTAssertFalse(preferences.allowsBackgroundLiveTracking)
            XCTAssertFalse(preferences.sendsLiveLocationToServer)
            XCTAssertEqual(
                preferences.liveLocationServerUploadURLString,
                LiveLocationServerUploadConfiguration.defaultTestEndpointURLString
            )
            XCTAssertEqual(preferences.liveLocationServerUploadBearerToken, "")
        }
    }

    func testInvalidStoredValueFallsBackToDefault() {
        defaults.set("nonsense", forKey: "app.preferences.startTab")

        MainActor.assumeIsolated {
            let preferences = AppPreferences(userDefaults: defaults)

            XCTAssertEqual(preferences.startTab, .overview)
        }
    }

    func testInvalidLiveTrackingValuesFallBackToDefaults() {
        defaults.set("nonsense", forKey: "app.preferences.liveTrackingAccuracy")
        defaults.set("still-nonsense", forKey: "app.preferences.liveTrackingDetail")

        MainActor.assumeIsolated {
            let preferences = AppPreferences(userDefaults: defaults)

            XCTAssertEqual(preferences.liveTrackingAccuracy, .balanced)
            XCTAssertEqual(preferences.liveTrackingDetail, .balanced)
        }
    }

    func testGermanLocalizationTranslatesKnownStrings() {
        MainActor.assumeIsolated {
            let preferences = AppPreferences(userDefaults: defaults)
            preferences.appLanguage = .german

            XCTAssertEqual(preferences.localized("Options"), "Optionen")
            XCTAssertEqual(preferences.localized("Open location history file"), "Standortverlauf-Datei öffnen")
        }
    }
}
