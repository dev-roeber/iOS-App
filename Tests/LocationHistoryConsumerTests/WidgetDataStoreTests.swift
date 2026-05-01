import XCTest
@testable import LocationHistoryConsumerAppSupport

final class WidgetDataStoreTests: XCTestCase {
    override func tearDown() {
        UserDefaults(suiteName: WidgetDataStore.suiteName)?
            .removeObject(forKey: "app.preferences.dynamicIslandCompactDisplay")
        super.tearDown()
    }

    func testLastRecordingFormattedDistance() {
        let rec = WidgetDataStore.LastRecording(date: Date(), distanceMeters: 5230, durationSeconds: 1800, trackName: "Test")
        XCTAssertEqual(rec.formattedDistance, "5.2 km")
    }

    func testLastRecordingFormattedDistanceMeters() {
        let rec = WidgetDataStore.LastRecording(date: Date(), distanceMeters: 450, durationSeconds: 600, trackName: "Test")
        XCTAssertEqual(rec.formattedDistance, "450 m")
    }

    func testLastRecordingFormattedDuration() {
        let rec = WidgetDataStore.LastRecording(date: Date(), distanceMeters: 1000, durationSeconds: 3660, trackName: "Test")
        XCTAssertEqual(rec.formattedDuration, "1h 1m")
    }

    func testLastRecordingCodable() throws {
        let rec = WidgetDataStore.LastRecording(date: Date(timeIntervalSince1970: 1000000), distanceMeters: 3000, durationSeconds: 900, trackName: "Runde")
        let data = try JSONEncoder().encode(rec)
        let decoded = try JSONDecoder().decode(WidgetDataStore.LastRecording.self, from: data)
        XCTAssertEqual(decoded.distanceMeters, 3000)
        XCTAssertEqual(decoded.trackName, "Runde")
    }

    func testDynamicIslandDisplayDefaultsToDistance() {
        XCTAssertEqual(WidgetDataStore.loadDynamicIslandCompactDisplay(), .distance)
    }

    func testDynamicIslandDisplayRoundTripsThroughAppGroupDefaults() {
        WidgetDataStore.saveDynamicIslandCompactDisplay(.uploadStatus)
        XCTAssertEqual(WidgetDataStore.loadDynamicIslandCompactDisplay(), .uploadStatus)
    }

    func testDynamicIslandAllCasesRoundTrip() {
        for display in DynamicIslandCompactDisplay.allCases {
            WidgetDataStore.saveDynamicIslandCompactDisplay(display)
            XCTAssertEqual(WidgetDataStore.loadDynamicIslandCompactDisplay(), display,
                           "\(display) must survive a save/load round-trip")
        }
    }

    func testWidgetAppGroupSuiteNameIsNonEmpty() {
        XCTAssertFalse(WidgetDataStore.suiteName.isEmpty)
    }

    func testAppLanguageMirroringKeyMatchesPreferences() {
        let suiteName = "WidgetDataStoreTests-mirror-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        MainActor.assumeIsolated {
            let prefs = AppPreferences(userDefaults: defaults)
            prefs.appLanguage = .german
            let widgetDefaults = UserDefaults(suiteName: WidgetDataStore.suiteName)
            XCTAssertEqual(
                widgetDefaults?.string(forKey: "app.preferences.appLanguage"),
                AppLanguagePreference.german.rawValue
            )
        }
        defaults.removePersistentDomain(forName: suiteName)
        UserDefaults(suiteName: WidgetDataStore.suiteName)?
            .removeObject(forKey: "app.preferences.appLanguage")
    }
}
