import XCTest
@testable import LocationHistoryConsumerAppSupport

final class ExportSelectionSummaryPresentationTests: XCTestCase {

    private typealias Counts = ExportSelectionSummaryPresentation.Counts

    // MARK: - Empty selection

    func testEmptySelectionReturnsNil() {
        let counts = Counts(selectedDayCount: 0, selectedRecordedTrackCount: 0,
                            hasExplicitPerRouteSelection: false)
        XCTAssertNil(ExportSelectionSummaryPresentation.strings(for: counts, german: false))
        XCTAssertNil(ExportSelectionSummaryPresentation.strings(for: counts, german: true))
    }

    // MARK: - Days only

    func testSingleDaySelectionEnglish() {
        let counts = Counts(selectedDayCount: 1, selectedRecordedTrackCount: 0,
                            hasExplicitPerRouteSelection: false)
        let strings = ExportSelectionSummaryPresentation.strings(for: counts, german: false)
        XCTAssertNotNil(strings)
        XCTAssertEqual(strings?.title, "Export selection")
        XCTAssertEqual(strings?.detail, "1 day")
        XCTAssertNil(strings?.secondaryDetail)
    }

    func testPluralDaySelectionGerman() {
        let counts = Counts(selectedDayCount: 7, selectedRecordedTrackCount: 0,
                            hasExplicitPerRouteSelection: false)
        let strings = ExportSelectionSummaryPresentation.strings(for: counts, german: true)
        XCTAssertEqual(strings?.title, "Export-Auswahl")
        XCTAssertEqual(strings?.detail, "7 Tage")
        XCTAssertNil(strings?.secondaryDetail)
    }

    // MARK: - Saved tracks only

    func testSingleRecordedTrackEnglish() {
        let counts = Counts(selectedDayCount: 0, selectedRecordedTrackCount: 1,
                            hasExplicitPerRouteSelection: false)
        let strings = ExportSelectionSummaryPresentation.strings(for: counts, german: false)
        XCTAssertEqual(strings?.detail, "1 saved track")
        XCTAssertNil(strings?.secondaryDetail)
    }

    func testPluralRecordedTracksGerman() {
        let counts = Counts(selectedDayCount: 0, selectedRecordedTrackCount: 3,
                            hasExplicitPerRouteSelection: false)
        let strings = ExportSelectionSummaryPresentation.strings(for: counts, german: true)
        XCTAssertEqual(strings?.detail, "3 gespeicherte Tracks")
    }

    // MARK: - Mixed selection surfaces secondary line

    func testMixedSelectionSurfacesMultipleSourcesHintEnglish() {
        let counts = Counts(selectedDayCount: 2, selectedRecordedTrackCount: 1,
                            hasExplicitPerRouteSelection: false)
        let strings = ExportSelectionSummaryPresentation.strings(for: counts, german: false)
        XCTAssertEqual(strings?.detail, "2 days · 1 saved track")
        XCTAssertEqual(strings?.secondaryDetail, "Multiple sources selected.")
    }

    func testMixedSelectionSurfacesMultipleSourcesHintGerman() {
        let counts = Counts(selectedDayCount: 2, selectedRecordedTrackCount: 1,
                            hasExplicitPerRouteSelection: false)
        let strings = ExportSelectionSummaryPresentation.strings(for: counts, german: true)
        XCTAssertEqual(strings?.secondaryDetail, "Mehrere Quellen ausgewählt.")
    }

    // MARK: - Per-route narrowing wins over mixed-source line

    func testPerRouteNarrowingTakesPrecedence() {
        let counts = Counts(selectedDayCount: 2, selectedRecordedTrackCount: 1,
                            hasExplicitPerRouteSelection: true)
        let en = ExportSelectionSummaryPresentation.strings(for: counts, german: false)
        let de = ExportSelectionSummaryPresentation.strings(for: counts, german: true)
        XCTAssertEqual(en?.secondaryDetail, "Day selection is narrowed to individual routes.")
        XCTAssertEqual(de?.secondaryDetail, "Tagesauswahl ist auf einzelne Routen eingeschränkt.")
    }

    // MARK: - Privacy contract

    func testStringsDoNotEmbedCoordinatesOrPlaceIDs() {
        // Strings come from counts only — any leakage would be a bug.
        // Cover the whole grid: small + large counts, with and without
        // narrowing.
        let scenarios: [Counts] = [
            Counts(selectedDayCount: 0, selectedRecordedTrackCount: 1, hasExplicitPerRouteSelection: false),
            Counts(selectedDayCount: 99, selectedRecordedTrackCount: 99, hasExplicitPerRouteSelection: false),
            Counts(selectedDayCount: 5, selectedRecordedTrackCount: 5, hasExplicitPerRouteSelection: true),
        ]
        let pattern = #"\b\d{1,3}\.\d{3,}\b"#
        for counts in scenarios {
            for german in [false, true] {
                guard let s = ExportSelectionSummaryPresentation.strings(for: counts, german: german) else {
                    continue
                }
                let blob = s.title + " " + s.detail + " " + (s.secondaryDetail ?? "")
                XCTAssertNil(blob.range(of: pattern, options: .regularExpression),
                             "Strings must not embed coordinate-like decimals: '\(blob)'")
                XCTAssertFalse(blob.contains("place_id"))
            }
        }
    }

    // MARK: - Counts struct ergonomics

    func testCountsEmptyAndTotal() {
        XCTAssertTrue(Counts(selectedDayCount: 0, selectedRecordedTrackCount: 0,
                             hasExplicitPerRouteSelection: false).isEmpty)
        XCTAssertEqual(Counts(selectedDayCount: 3, selectedRecordedTrackCount: 2,
                              hasExplicitPerRouteSelection: false).totalCount, 5)
    }
}
