import XCTest
@testable import LocationHistoryConsumerAppSupport

final class AppPreferencesTests: XCTestCase {
    private let bearerTokenKey = "app.preferences.liveTrackingServerUploadBearerToken"
    private let appLanguageKey = "app.preferences.appLanguage"
    private let dynamicIslandDisplayKey = "app.preferences.dynamicIslandCompactDisplay"
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var widgetDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "AppPreferencesTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        widgetDefaults = UserDefaults(suiteName: WidgetDataStore.suiteName)
        widgetDefaults?.removeObject(forKey: appLanguageKey)
        KeychainHelper.delete(key: bearerTokenKey)
    }

    override func tearDown() {
        KeychainHelper.delete(key: bearerTokenKey)
        defaults.removePersistentDomain(forName: suiteName)
        widgetDefaults?.removeObject(forKey: appLanguageKey)
        defaults = nil
        suiteName = nil
        widgetDefaults = nil
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
            XCTAssertFalse(preferences.autoRestoreLastImport)
            XCTAssertFalse(preferences.allowsBackgroundLiveTracking)
            XCTAssertFalse(preferences.sendsLiveLocationToServer)
            XCTAssertEqual(
                preferences.liveLocationServerUploadURLString,
                LiveLocationServerUploadConfiguration.defaultTestEndpointURLString
            )
            XCTAssertEqual(preferences.liveLocationServerUploadBearerToken, "")
            XCTAssertEqual(preferences.liveTrackRecorderConfiguration.maximumAcceptedAccuracyM, 65)
            XCTAssertEqual(preferences.liveTrackRecorderConfiguration.minimumDistanceDeltaM, 15)
            // recordingInterval default
            XCTAssertEqual(preferences.recordingInterval, .default)
            XCTAssertEqual(preferences.recordingInterval.value, 5)
            XCTAssertEqual(preferences.recordingInterval.unit, .seconds)
            XCTAssertEqual(preferences.liveTrackRecorderConfiguration.minimumRecordingIntervalS, 5.0)
            XCTAssertEqual(preferences.dynamicIslandCompactDisplay, .distance)
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
        defaults.set(true, forKey: "app.preferences.autoRestoreLastImport")
        defaults.set(true, forKey: "app.preferences.liveTrackingBackground")
        defaults.set(true, forKey: "app.preferences.liveTrackingServerUploadEnabled")
        defaults.set(DynamicIslandCompactDisplay.uploadStatus.rawValue, forKey: dynamicIslandDisplayKey)
        defaults.set("https://example.invalid/live", forKey: "app.preferences.liveTrackingServerUploadURL")
        try? KeychainHelper.save(key: bearerTokenKey, value: "secret")
        // Store a custom recording interval (2 minutes)
        if let data = try? JSONEncoder().encode(RecordingIntervalPreference(value: 2, unit: .minutes)) {
            defaults.set(data, forKey: "app.preferences.recordingInterval")
        }

        MainActor.assumeIsolated {
            let preferences = AppPreferences(userDefaults: defaults)

            XCTAssertEqual(preferences.distanceUnit, .imperial)
            XCTAssertEqual(preferences.startTab, .insights)
            XCTAssertEqual(preferences.preferredMapStyle, .hybrid)
            XCTAssertFalse(preferences.showsTechnicalImportDetails)
            XCTAssertEqual(preferences.appLanguage, .german)
            XCTAssertEqual(preferences.liveTrackingAccuracy, .strict)
            XCTAssertEqual(preferences.liveTrackingDetail, .detailed)
            XCTAssertTrue(preferences.autoRestoreLastImport)
            XCTAssertTrue(preferences.allowsBackgroundLiveTracking)
            XCTAssertTrue(preferences.sendsLiveLocationToServer)
            XCTAssertEqual(preferences.dynamicIslandCompactDisplay, .uploadStatus)
            XCTAssertEqual(preferences.liveLocationServerUploadURLString, "https://example.invalid/live")
            XCTAssertEqual(preferences.liveLocationServerUploadBearerToken, "secret")
            XCTAssertEqual(preferences.liveTrackRecorderConfiguration.maximumAcceptedAccuracyM, 25)
            XCTAssertEqual(preferences.liveTrackRecorderConfiguration.minimumDistanceDeltaM, 8)
            // loaded recording interval
            XCTAssertEqual(preferences.recordingInterval, RecordingIntervalPreference(value: 2, unit: .minutes))
            XCTAssertEqual(preferences.liveTrackRecorderConfiguration.minimumRecordingIntervalS, 120.0)
        }
    }

    func testStoredZeroRecordingIntervalDisablesMinimumGap() {
        if let data = try? JSONEncoder().encode(RecordingIntervalPreference(value: 0, unit: .hours)) {
            defaults.set(data, forKey: "app.preferences.recordingInterval")
        }

        MainActor.assumeIsolated {
            let preferences = AppPreferences(userDefaults: defaults)

            XCTAssertEqual(preferences.recordingInterval, RecordingIntervalPreference(value: 0, unit: .hours))
            XCTAssertEqual(preferences.liveTrackRecorderConfiguration.minimumRecordingIntervalS, 0)
        }
    }

    func testStoredLargeRecordingIntervalKeepsUnlimitedUpperBound() {
        if let data = try? JSONEncoder().encode(RecordingIntervalPreference(value: 999, unit: .hours)) {
            defaults.set(data, forKey: "app.preferences.recordingInterval")
        }

        MainActor.assumeIsolated {
            let preferences = AppPreferences(userDefaults: defaults)

            XCTAssertEqual(preferences.recordingInterval, RecordingIntervalPreference(value: 999, unit: .hours))
            XCTAssertEqual(preferences.liveTrackRecorderConfiguration.minimumRecordingIntervalS, 999 * 3600)
        }
    }

    func testStoredNegativeRecordingIntervalIsValidatedToZero() {
        if let data = try? JSONEncoder().encode(RecordingIntervalPreference(value: -5, unit: .minutes)) {
            defaults.set(data, forKey: "app.preferences.recordingInterval")
        }

        MainActor.assumeIsolated {
            let preferences = AppPreferences(userDefaults: defaults)

            XCTAssertEqual(preferences.recordingInterval, RecordingIntervalPreference(value: 0, unit: .minutes))
            XCTAssertEqual(preferences.liveTrackRecorderConfiguration.minimumRecordingIntervalS, 0)
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
            preferences.autoRestoreLastImport = true
            preferences.allowsBackgroundLiveTracking = true
            preferences.sendsLiveLocationToServer = true
            preferences.liveLocationServerUploadURLString = "https://example.invalid/custom"
            preferences.liveLocationServerUploadBearerToken = "token"
            preferences.recordingInterval = RecordingIntervalPreference(value: 10, unit: .minutes)
            preferences.dynamicIslandCompactDisplay = .uploadStatus

            preferences.reset()

            XCTAssertEqual(preferences.distanceUnit, .metric)
            XCTAssertEqual(preferences.startTab, .overview)
            XCTAssertEqual(preferences.preferredMapStyle, .standard)
            XCTAssertTrue(preferences.showsTechnicalImportDetails)
            XCTAssertEqual(preferences.appLanguage, .english)
            XCTAssertEqual(preferences.liveTrackingAccuracy, .balanced)
            XCTAssertEqual(preferences.liveTrackingDetail, .balanced)
            XCTAssertFalse(preferences.autoRestoreLastImport)
            XCTAssertFalse(preferences.allowsBackgroundLiveTracking)
            XCTAssertFalse(preferences.sendsLiveLocationToServer)
            XCTAssertEqual(
                preferences.liveLocationServerUploadURLString,
                LiveLocationServerUploadConfiguration.defaultTestEndpointURLString
            )
            XCTAssertEqual(preferences.liveLocationServerUploadBearerToken, "")
            // reset restores default recording interval
            XCTAssertEqual(preferences.recordingInterval, .default)
            XCTAssertEqual(preferences.dynamicIslandCompactDisplay, .distance)
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
            XCTAssertEqual(preferences.localized("Import File"), "Datei importieren")
            XCTAssertEqual(preferences.localized("Google Maps Export Guide"), "Google Maps Export-Anleitung")
        }
    }

    func testGermanLocalizationTranslatesGapStateStrings() {
        MainActor.assumeIsolated {
            let preferences = AppPreferences(userDefaults: defaults)
            preferences.appLanguage = .german

            XCTAssertEqual(preferences.localized("No minimum"), "Kein Minimum")
            XCTAssertEqual(preferences.localized("Unlimited"), "Unbegrenzt")
        }
    }

    func testAppLanguageMirrorsToWidgetAppGroupDefaults() {
        MainActor.assumeIsolated {
            let preferences = AppPreferences(userDefaults: defaults)
            preferences.appLanguage = .german

            XCTAssertEqual(
                widgetDefaults?.string(forKey: appLanguageKey),
                AppLanguagePreference.german.rawValue
            )
        }
    }

    // MARK: - RecordingPreset mapping

    func testPresetBatteryMapsToRelaxedBatterySaver() {
        MainActor.assumeIsolated {
            let preferences = AppPreferences(userDefaults: defaults)
            preferences.recordingPreset = .battery
            XCTAssertEqual(preferences.liveTrackingAccuracy, .relaxed)
            XCTAssertEqual(preferences.liveTrackingDetail, .batterySaver)
            XCTAssertEqual(preferences.recordingPreset, .battery)
        }
    }

    func testPresetBalancedMapsToBalancedBalanced() {
        MainActor.assumeIsolated {
            let preferences = AppPreferences(userDefaults: defaults)
            preferences.recordingPreset = .balanced
            XCTAssertEqual(preferences.liveTrackingAccuracy, .balanced)
            XCTAssertEqual(preferences.liveTrackingDetail, .balanced)
            XCTAssertEqual(preferences.recordingPreset, .balanced)
        }
    }

    func testPresetPreciseMapsToStrictDetailed() {
        MainActor.assumeIsolated {
            let preferences = AppPreferences(userDefaults: defaults)
            preferences.recordingPreset = .precise
            XCTAssertEqual(preferences.liveTrackingAccuracy, .strict)
            XCTAssertEqual(preferences.liveTrackingDetail, .detailed)
            XCTAssertEqual(preferences.recordingPreset, .precise)
        }
    }

    func testPresetCustomPreservesExistingValues() {
        MainActor.assumeIsolated {
            let preferences = AppPreferences(userDefaults: defaults)
            // Start from a non-matching combination (custom territory)
            preferences.liveTrackingAccuracy = .strict
            preferences.liveTrackingDetail = .batterySaver
            XCTAssertEqual(preferences.recordingPreset, .custom)
            // Setting custom must not change accuracy or detail
            preferences.recordingPreset = .custom
            XCTAssertEqual(preferences.liveTrackingAccuracy, .strict)
            XCTAssertEqual(preferences.liveTrackingDetail, .batterySaver)
        }
    }

    func testPresetChangeIsDeterministicAndTestable() {
        MainActor.assumeIsolated {
            let preferences = AppPreferences(userDefaults: defaults)
            // Switch from battery to precise — values must match the spec exactly
            preferences.recordingPreset = .battery
            preferences.recordingPreset = .precise
            XCTAssertEqual(preferences.liveTrackingAccuracy, .strict)
            XCTAssertEqual(preferences.liveTrackingDetail, .detailed)
            // Switch back to balanced
            preferences.recordingPreset = .balanced
            XCTAssertEqual(preferences.liveTrackingAccuracy, .balanced)
            XCTAssertEqual(preferences.liveTrackingDetail, .balanced)
        }
    }

    func testDynamicIslandCompactDisplayPersists() {
        MainActor.assumeIsolated {
            let preferences = AppPreferences(userDefaults: defaults)
            preferences.dynamicIslandCompactDisplay = .elapsed
            // Create a second instance from the same defaults to verify persistence
            let preferences2 = AppPreferences(userDefaults: defaults)
            XCTAssertEqual(preferences2.dynamicIslandCompactDisplay, .elapsed)
        }
    }

    func testUploadSettingsPersist() {
        MainActor.assumeIsolated {
            let preferences = AppPreferences(userDefaults: defaults)
            preferences.sendsLiveLocationToServer = true
            preferences.liveLocationServerUploadURLString = "https://example.invalid/live"
            preferences.liveTrackingUploadBatch = .large
            let preferences2 = AppPreferences(userDefaults: defaults)
            XCTAssertTrue(preferences2.sendsLiveLocationToServer)
            XCTAssertEqual(preferences2.liveLocationServerUploadURLString, "https://example.invalid/live")
            XCTAssertEqual(preferences2.liveTrackingUploadBatch, .large)
        }
    }
}

// MARK: - KeychainHelper tests (P1 fix verification)

final class KeychainHelperTests: XCTestCase {
    private let testKey = "KeychainHelperTests.testKey.\(UUID())"

    override func tearDown() {
        KeychainHelper.delete(key: testKey)
        super.tearDown()
    }

    func testSaveAndRetrieveRoundTrip() throws {
        // Verifies save/get/delete works end-to-end on the current platform
        try KeychainHelper.save(key: testKey, value: "hello-world")
        XCTAssertEqual(KeychainHelper.get(key: testKey), "hello-world")
        KeychainHelper.delete(key: testKey)
        XCTAssertNil(KeychainHelper.get(key: testKey))
    }

    func testSaveEmptyStringRoundTrip() throws {
        // Empty string must not trigger encodingFailed (empty string is valid UTF-8)
        try KeychainHelper.save(key: testKey, value: "")
        // On Apple: empty string stored and retrieved; on Linux fallback stores via UserDefaults
        let retrieved = KeychainHelper.get(key: testKey)
        XCTAssertEqual(retrieved, "")
    }

    func testEncodingFailedErrorCaseExists() {
        // Confirms the encodingFailed case compiles and is a distinct error value
        let error: KeychainHelper.KeychainError = .encodingFailed
        XCTAssertNotNil(error)
    }
}
