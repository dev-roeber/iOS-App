import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class ImportValidationSummaryPresentationTests: XCTestCase {

    // MARK: - Empty

    func testEmptySummaryRendersEmptyImportWarningInEnglish() {
        let strings = ImportValidationSummaryPresentation.strings(for: .empty, german: false)
        XCTAssertEqual(strings.title, "Import summary")
        XCTAssertNil(strings.rangeSubtitle)
        XCTAssertEqual(strings.countsLine, "0 days")
        XCTAssertEqual(strings.warningLines.count, 1)
        XCTAssertTrue(strings.warningLines.first?.contains("No data") == true)
    }

    func testEmptySummaryRendersEmptyImportWarningInGerman() {
        let strings = ImportValidationSummaryPresentation.strings(for: .empty, german: true)
        XCTAssertEqual(strings.title, "Importübersicht")
        XCTAssertNil(strings.rangeSubtitle)
        XCTAssertEqual(strings.countsLine, "0 Tage")
        XCTAssertEqual(strings.warningLines.count, 1)
        XCTAssertTrue(strings.warningLines.first?.contains("Keine Daten") == true)
    }

    // MARK: - Counts pluralisation

    func testSingleDayPluralisationEnglish() {
        let summary = ImportValidationSummary(
            dayCount: 1, visitCount: 1, activityCount: 1,
            pathCount: 1, totalPathPointCount: 5,
            firstDate: "2024-06-01", lastDate: "2024-06-01",
            warnings: [.singleDayOnly]
        )
        let strings = ImportValidationSummaryPresentation.strings(for: summary, german: false)
        XCTAssertTrue(strings.countsLine.contains("1 day"))
        XCTAssertTrue(strings.countsLine.contains("1 route"))
        XCTAssertTrue(strings.countsLine.contains("1 activity"))
        XCTAssertTrue(strings.countsLine.contains("1 visit"))
    }

    func testPluralCountsGerman() {
        let summary = ImportValidationSummary(
            dayCount: 12, visitCount: 7, activityCount: 4,
            pathCount: 30, totalPathPointCount: 1_200,
            firstDate: "2024-06-01", lastDate: "2024-06-30",
            warnings: []
        )
        let strings = ImportValidationSummaryPresentation.strings(for: summary, german: true)
        XCTAssertTrue(strings.countsLine.contains("12 Tage"))
        XCTAssertTrue(strings.countsLine.contains("30 Routen"))
        XCTAssertTrue(strings.countsLine.contains("4 Aktivitäten"))
        XCTAssertTrue(strings.countsLine.contains("7 Besuche"))
        XCTAssertTrue(strings.countsLine.contains("·"),
                      "Components must be joined with the middle-dot separator.")
    }

    // MARK: - Zero counts are dropped from the line

    func testZeroPathCountIsOmittedFromCountsLine() {
        let summary = ImportValidationSummary(
            dayCount: 3, visitCount: 2, activityCount: 0,
            pathCount: 0, totalPathPointCount: 0,
            firstDate: "2024-06-01", lastDate: "2024-06-03",
            warnings: []
        )
        let strings = ImportValidationSummaryPresentation.strings(for: summary, german: false)
        XCTAssertFalse(strings.countsLine.contains("route"))
        XCTAssertFalse(strings.countsLine.contains("activity"))
        XCTAssertTrue(strings.countsLine.contains("3 days"))
        XCTAssertTrue(strings.countsLine.contains("2 visits"))
    }

    // MARK: - Date-range subtitle

    func testSingleDayRangeRendersOneDate() {
        let summary = ImportValidationSummary(
            dayCount: 1, visitCount: 0, activityCount: 0,
            pathCount: 0, totalPathPointCount: 0,
            firstDate: "2024-06-15", lastDate: "2024-06-15",
            warnings: [.singleDayOnly]
        )
        let strings = ImportValidationSummaryPresentation.strings(for: summary, german: false)
        XCTAssertNotNil(strings.rangeSubtitle)
        XCTAssertFalse(strings.rangeSubtitle?.contains("–") == true,
                       "Identical first/last dates must not render a range separator.")
    }

    func testMultiDayRangeUsesEnDashSeparator() {
        let summary = ImportValidationSummary(
            dayCount: 30, visitCount: 0, activityCount: 0,
            pathCount: 0, totalPathPointCount: 0,
            firstDate: "2024-06-01", lastDate: "2024-06-30",
            warnings: []
        )
        let strings = ImportValidationSummaryPresentation.strings(for: summary, german: false)
        XCTAssertNotNil(strings.rangeSubtitle)
        XCTAssertTrue(strings.rangeSubtitle!.contains("–"),
                      "Multi-day range must use en-dash separator.")
    }

    func testRangeSubtitleNilWhenDatesMissing() {
        let summary = ImportValidationSummary(
            dayCount: 0, visitCount: 0, activityCount: 0,
            pathCount: 0, totalPathPointCount: 0,
            firstDate: nil, lastDate: nil,
            warnings: [.emptyImport]
        )
        let strings = ImportValidationSummaryPresentation.strings(for: summary, german: false)
        XCTAssertNil(strings.rangeSubtitle)
    }

    // MARK: - Warning copy

    func testAllWarningsHaveDistinctEnglishAndGermanCopy() {
        for warning in ImportValidationSummary.Warning.allCases {
            let en = ImportValidationSummaryPresentation.warningLine(for: warning, german: false)
            let de = ImportValidationSummaryPresentation.warningLine(for: warning, german: true)
            XCTAssertFalse(en.isEmpty, "\(warning) EN copy must not be empty.")
            XCTAssertFalse(de.isEmpty, "\(warning) DE copy must not be empty.")
            XCTAssertNotEqual(en, de, "\(warning) must differ between languages.")
        }
    }

    // MARK: - Privacy contract

    func testStringsDoNotLeakCoordinatesOrPlaceIDs() {
        // Construct a summary directly: presentation strings depend only
        // on counts + ISO dates, so any leakage would be a bug.
        let summary = ImportValidationSummary(
            dayCount: 1, visitCount: 1, activityCount: 1,
            pathCount: 1, totalPathPointCount: 100,
            firstDate: "2024-06-01", lastDate: "2024-06-01",
            warnings: [.singleDayOnly]
        )
        let strings = ImportValidationSummaryPresentation.strings(for: summary, german: false)
        let dumped = [strings.title, strings.rangeSubtitle ?? "", strings.countsLine] + strings.warningLines
        let joined = dumped.joined(separator: " ")
        // No decimal coordinate-like fragments (e.g. 50.123 or 10.456789).
        let coordinatePattern = #"\b\d{1,3}\.\d{3,}\b"#
        XCTAssertNil(joined.range(of: coordinatePattern, options: .regularExpression),
                     "Strings must not embed coordinate-like decimal fragments.")
        XCTAssertFalse(joined.contains("place_id"))
    }
}
