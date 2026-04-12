import XCTest
@testable import LocationHistoryConsumerAppSupport
@testable import LocationHistoryConsumer

final class GoogleMapsExportHelpTests: XCTestCase {

    // Test 1: Alle deutschen Übersetzungen für die Hilfe-Strings sind vorhanden
    func testGermanTranslationsExistForHelpStrings() {
        let requiredKeys = [
            "Google Maps Export on iPhone",
            "Open Google Maps on your iPhone.",
            "Tap your profile picture and open Settings.",
            "If the direct export is unavailable, a Google Takeout export may be required depending on your account.",
            "Dismiss help",
            "Step",
            "Google Maps export help"
        ]
        for key in requiredKeys {
            let german = AppLanguagePreference.german.localized(key)
            XCTAssertNotEqual(german, key, "Missing German translation for: \(key)")
        }
    }

    // Test 2: Englische Sprache gibt unveränderte Strings zurück
    func testEnglishReturnsOriginalStrings() {
        let key = "Google Maps Export on iPhone"
        let result = AppLanguagePreference.english.localized(key)
        XCTAssertEqual(result, key)
    }

    // Test 3: Hilfetitel ist nicht leer
    func testHelpTitleIsNonEmpty() {
        let title = AppLanguagePreference.german.localized("Google Maps Export on iPhone")
        XCTAssertFalse(title.isEmpty)
    }

    // Test 4: Fallback-Hinweistext vorhanden
    func testFallbackHintTranslated() {
        let en = "If the direct export is unavailable, a Google Takeout export may be required depending on your account."
        let de = AppLanguagePreference.german.localized(en)
        XCTAssertTrue(de.contains("Takeout"), "German fallback hint should mention Takeout")
    }
}
