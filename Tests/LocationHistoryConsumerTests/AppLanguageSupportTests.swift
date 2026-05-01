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

    // MARK: - Live Tracking Redesign Strings

    func testGermanLiveTrackingRedesignStrings() {
        XCTAssertEqual(de.localized("GPS Good"),                          "GPS gut")
        XCTAssertEqual(de.localized("GPS Weak"),                          "GPS schwach")
        XCTAssertEqual(de.localized("Upload Active"),                     "Upload aktiv")
        XCTAssertEqual(de.localized("Upload Off"),                        "Upload aus")
        XCTAssertEqual(de.localized("Upload Waiting"),                    "Upload wartet")
        XCTAssertEqual(de.localized("View All Live Tracks"),              "Alle Live-Tracks anzeigen")
        XCTAssertEqual(de.localized("New Track"),                         "Neuer Track")
        XCTAssertEqual(de.localized("Stored Locally"),                    "Lokal gespeichert")
        XCTAssertEqual(de.localized("Separate from imported history"),    "Getrennt von importierter Historie")
        XCTAssertEqual(de.localized("Follow On"),                         "Folgen aktiv")
        XCTAssertEqual(de.localized("Follow Off"),                        "Folgen aus")
        XCTAssertEqual(de.localized("Recording Active"),                  "Aufzeichnung läuft")
    }

    func testEnglishLiveTrackingRedesignIdentity() {
        XCTAssertEqual(en.localized("GPS Good"),               "GPS Good")
        XCTAssertEqual(en.localized("GPS Weak"),               "GPS Weak")
        XCTAssertEqual(en.localized("View All Live Tracks"),   "View All Live Tracks")
        XCTAssertEqual(en.localized("New Track"),              "New Track")
        XCTAssertEqual(en.localized("Stored Locally"),         "Stored Locally")
        XCTAssertEqual(en.localized("Live Tracks"),            "Live Tracks")
    }

    // MARK: - Options + Widget/Live Activity Redesign Strings

    func testGermanOptionsRedesignStrings() {
        XCTAssertEqual(de.localized("General"),                    "Allgemein")
        XCTAssertEqual(de.localized("Live Recording"),             "Live-Aufzeichnung")
        XCTAssertEqual(de.localized("Battery"),                    "Akku sparen")
        XCTAssertEqual(de.localized("Precise"),                    "Präzise")
        XCTAssertEqual(de.localized("Custom"),                     "Benutzerdefiniert")
        XCTAssertEqual(de.localized("High-Accuracy Location"),     "Hochpräzise Standortdaten")
        XCTAssertEqual(de.localized("Motion Filter"),              "Bewegungsfilter")
        XCTAssertEqual(de.localized("Update Interval"),            "Aktualisierungsintervall")
        XCTAssertEqual(de.localized("Minimum Distance Filter"),    "Minimum-Distanzfilter")
        XCTAssertEqual(de.localized("Recording Preset"),           "Aufnahme-Voreinstellung")
        XCTAssertEqual(de.localized("Settings"),                   "Einstellungen")
        XCTAssertEqual(de.localized("Upload URL"),                 "Upload-URL")
        XCTAssertEqual(de.localized("Bearer Token"),               "Bearer-Token")
        XCTAssertEqual(de.localized("Token saved"),                "Token gespeichert")
        XCTAssertEqual(de.localized("Token not set"),              "Token nicht gesetzt")
        XCTAssertEqual(de.localized("Points per Batch"),           "Punkte pro Batch")
    }

    func testGermanWidgetAndLiveActivityStrings() {
        XCTAssertEqual(de.localized("Dynamic Island Primary Value"),    "Dynamic-Island-Primärwert")
        XCTAssertEqual(de.localized("Home Widget"),                     "Home Widget")
        XCTAssertEqual(de.localized("Active only during recording"),    "Nur während laufender Aufnahme")
        XCTAssertEqual(de.localized("Fallback active"),                 "Fallback aktiv")
        XCTAssertEqual(de.localized("Dynamic Island"),                  "Dynamic Island")
        XCTAssertEqual(
            de.localized("The widget updates automatically after each recording."),
            "Das Widget aktualisiert sich nach jeder Aufzeichnung automatisch."
        )
    }

    func testGermanOptionsSectionDescriptionStrings() {
        XCTAssertEqual(de.localized("Display, language and import options"),             "Anzeige, Sprache und Importoptionen")
        XCTAssertEqual(de.localized("Accuracy, interval and background recording"),      "Genauigkeit, Intervall und Hintergrundaufzeichnung")
        XCTAssertEqual(de.localized("Server URL, token and batch settings"),             "Server-URL, Token und Batch-Einstellungen")
        XCTAssertEqual(de.localized("Dynamic Island value and home widget"),             "Dynamic-Island-Wert und Home Widget")
        XCTAssertEqual(de.localized("Reset all options to defaults"),                   "Alle Optionen zurücksetzen")
    }

    func testEnglishOptionsRedesignIdentity() {
        XCTAssertEqual(en.localized("General"),             "General")
        XCTAssertEqual(en.localized("Live Recording"),      "Live Recording")
        XCTAssertEqual(en.localized("Battery"),             "Battery")
        XCTAssertEqual(en.localized("Precise"),             "Precise")
        XCTAssertEqual(en.localized("Custom"),              "Custom")
        XCTAssertEqual(en.localized("Upload URL"),          "Upload URL")
        XCTAssertEqual(en.localized("Bearer Token"),        "Bearer Token")
        XCTAssertEqual(en.localized("Dynamic Island"),      "Dynamic Island")
        XCTAssertEqual(en.localized("Points per Batch"),    "Points per Batch")
    }

    // MARK: - Truth-sync strings (2026-05-01)

    func testGermanOptionsTruthSyncStrings() {
        XCTAssertEqual(de.localized("Invalid URL"),                 "Ungültige URL")
        XCTAssertEqual(de.localized("Automatic Widget Update"),     "Automatisches Widget-Update")
        XCTAssertEqual(de.localized("Widget & Live Activity"),      "Widget & Live-Activity")
        XCTAssertEqual(de.localized("Live Activity"),               "Live-Activity")
        XCTAssertEqual(de.localized("Reachable"),                   "Erreichbar")
        XCTAssertEqual(de.localized("Unreachable"),                 "Nicht erreichbar")
        XCTAssertEqual(de.localized("Test Connection"),             "Verbindung testen")
        XCTAssertEqual(de.localized("Testing…"),                    "Testen…")
        XCTAssertEqual(de.localized("Last tour + weekly status"),   "Letzte Tour + Wochenstatus")
    }

    func testEnglishOptionsTruthSyncIdentity() {
        XCTAssertEqual(en.localized("Invalid URL"),              "Invalid URL")
        XCTAssertEqual(en.localized("Automatic Widget Update"),  "Automatic Widget Update")
        XCTAssertEqual(en.localized("Widget & Live Activity"),   "Widget & Live Activity")
        XCTAssertEqual(en.localized("Reachable"),                "Reachable")
        XCTAssertEqual(en.localized("Unreachable"),              "Unreachable")
        XCTAssertEqual(en.localized("Test Connection"),          "Test Connection")
    }
}
