import XCTest
@testable import LocationHistoryConsumerAppSupport

final class AppLanguageSupportMapHeaderStringsTests: XCTestCase {

    private let de = AppLanguagePreference.german
    private let en = AppLanguagePreference.english

    // MARK: English identity

    func testEnglishShowMap() {
        XCTAssertEqual(en.localized("Show Map"), "Show Map")
    }

    func testEnglishCollapseMap() {
        XCTAssertEqual(en.localized("Collapse Map"), "Collapse Map")
    }

    func testEnglishExpandMap() {
        XCTAssertEqual(en.localized("Expand Map"), "Expand Map")
    }

    func testEnglishFullscreen() {
        XCTAssertEqual(en.localized("Fullscreen"), "Fullscreen")
    }

    func testEnglishMapPreview() {
        XCTAssertEqual(en.localized("Map Preview"), "Map Preview")
    }

    func testEnglishCloseMap() {
        XCTAssertEqual(en.localized("Close Map"), "Close Map")
    }

    func testEnglishDismiss() {
        XCTAssertEqual(en.localized("Dismiss"), "Dismiss")
    }

    // MARK: German translations

    func testGermanShowMap() {
        XCTAssertEqual(de.localized("Show Map"), "Karte anzeigen")
    }

    func testGermanCollapseMap() {
        XCTAssertEqual(de.localized("Collapse Map"), "Karte einklappen")
    }

    func testGermanExpandMap() {
        XCTAssertEqual(de.localized("Expand Map"), "Karte erweitern")
    }

    func testGermanFullscreen() {
        XCTAssertEqual(de.localized("Fullscreen"), "Vollbild")
    }

    func testGermanMapPreview() {
        XCTAssertEqual(de.localized("Map Preview"), "Kartenvorschau")
    }

    func testGermanCloseMap() {
        XCTAssertEqual(de.localized("Close Map"), "Karte schließen")
    }

    func testGermanDismiss() {
        XCTAssertEqual(de.localized("Dismiss"), "Schließen")
    }

    func testGermanSimplifiedPreviewCopy() {
        XCTAssertEqual(
            de.localized("Simplified preview · export complete"),
            "Vereinfachte Vorschau · Export vollständig"
        )
    }

    func testGermanHomeAndOverviewStrings() {
        XCTAssertEqual(de.localized("Private location history → GPX, KML, CSV, KMZ"), "Privater Standortverlauf → GPX, KML, CSV, KMZ")
        XCTAssertEqual(de.localized("Prepare Export"), "Export vorbereiten")
        XCTAssertEqual(de.localized("Import New File"), "Neue Datei importieren")
    }
}
