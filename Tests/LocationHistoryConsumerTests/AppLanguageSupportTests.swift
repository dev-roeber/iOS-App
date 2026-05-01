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

    func testGermanDaysRedesignStrings() {
        XCTAssertEqual(de.localized("All"), "Alle")
        XCTAssertEqual(de.localized("With Routes"), "Mit Routen")
        XCTAssertEqual(de.localized("Days Search"), "Tagessuche")
        XCTAssertEqual(
            de.localized("No days fall within the selected date range. Change the range to see more days."),
            "Keine Tage liegen im ausgewählten Datumsbereich. Ändere den Zeitraum, um mehr Tage zu sehen."
        )
        XCTAssertEqual(
            de.localized("No days fall within the selected date range. Change the range above to see more days."),
            "Keine Tage liegen im ausgewählten Datumsbereich. Ändere den Zeitraum oben, um mehr Tage zu sehen."
        )
    }

    func testGermanDayDetailRedesignStrings() {
        XCTAssertEqual(de.localized("Activities"), "Aktivitäten")
        XCTAssertEqual(de.localized("Route"), "Route")
    }

    func testGermanInsightsDashboardStrings() {
        XCTAssertEqual(de.localized("Open in Days"), "In Tage öffnen")
        XCTAssertEqual(de.localized("Select for Export"), "Für Export auswählen")
        XCTAssertEqual(de.localized("Show on Map"), "Auf Karte zeigen")
        XCTAssertEqual(de.localized("Activity Overview"), "Aktivitätsübersicht")
        XCTAssertEqual(de.localized("Activity Streak"), "Aktivitätsserie")
        XCTAssertEqual(de.localized("Period Comparison"), "Periodenvergleich")
        XCTAssertEqual(de.localized("Import More Data"), "Mehr Daten importieren")
    }

    func testEnglishInsightsDashboardIdentity() {
        XCTAssertEqual(en.localized("Open in Days"), "Open in Days")
        XCTAssertEqual(en.localized("Select for Export"), "Select for Export")
        XCTAssertEqual(en.localized("Show on Map"), "Show on Map")
        XCTAssertEqual(en.localized("Activity Streak"), "Activity Streak")
        XCTAssertEqual(en.localized("Period Comparison"), "Period Comparison")
    }

    func testGermanExportCheckoutStrings() {
        XCTAssertEqual(de.localized("Selection"),             "Auswahl")
        XCTAssertEqual(de.localized("Content"),               "Inhalt")
        XCTAssertEqual(de.localized("Edit Selection"),        "Auswahl bearbeiten")
        XCTAssertEqual(de.localized("Export Format"),         "Exportformat")
        XCTAssertEqual(de.localized("Advanced Filters"),      "Erweiterte Filter")
        XCTAssertEqual(de.localized("Reset Drilldown"),       "Drilldown zurücksetzen")
        XCTAssertEqual(de.localized("Adopted from Insights"), "Aus Insights übernommen")
        XCTAssertEqual(de.localized("Tracks + Waypoints"),    "Tracks + Wegpunkte")
    }

    func testEnglishExportCheckoutIdentity() {
        XCTAssertEqual(en.localized("Selection"),        "Selection")
        XCTAssertEqual(en.localized("Content"),          "Content")
        XCTAssertEqual(en.localized("Edit Selection"),   "Edit Selection")
        XCTAssertEqual(en.localized("Advanced Filters"), "Advanced Filters")
        XCTAssertEqual(en.localized("Export"),           "Export")
    }
}
