import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class RouteQualitySummaryPresentationTests: XCTestCase {

    // MARK: - Title

    func testTitleLocalisation() {
        XCTAssertEqual(RouteQualitySummaryPresentation.title(german: false), "Route quality")
        XCTAssertEqual(RouteQualitySummaryPresentation.title(german: true), "Routenqualität")
    }

    // MARK: - Level labels and hints

    func testEveryLevelHasDistinctEnglishAndGermanLabel() {
        for level in RouteQualitySummary.Level.allCases {
            let en = RouteQualitySummaryPresentation.levelLabel(for: level, german: false)
            let de = RouteQualitySummaryPresentation.levelLabel(for: level, german: true)
            XCTAssertFalse(en.isEmpty)
            XCTAssertFalse(de.isEmpty)
            XCTAssertNotEqual(en, de, "\(level) label must differ between languages.")
        }
    }

    func testEveryLevelHasDistinctEnglishAndGermanHint() {
        for level in RouteQualitySummary.Level.allCases {
            let en = RouteQualitySummaryPresentation.levelHint(for: level, german: false)
            let de = RouteQualitySummaryPresentation.levelHint(for: level, german: true)
            XCTAssertFalse(en.isEmpty)
            XCTAssertFalse(de.isEmpty)
            XCTAssertNotEqual(en, de, "\(level) hint must differ between languages.")
        }
    }

    func testEmptyLevelLabelIsConservative() {
        XCTAssertEqual(RouteQualitySummaryPresentation.levelLabel(for: .empty, german: false), "No data")
        XCTAssertEqual(RouteQualitySummaryPresentation.levelLabel(for: .empty, german: true),  "Keine Daten")
    }

    // MARK: - Rounding behaviour

    func testRoundingBucketsBelow100MAreOneMeter() {
        XCTAssertEqual(RouteQualitySummaryPresentation.roundedMetres(12.3), 12)
        XCTAssertEqual(RouteQualitySummaryPresentation.roundedMetres(0.4), 0)
        XCTAssertEqual(RouteQualitySummaryPresentation.roundedMetres(99.7), 100)
    }

    func testRoundingBucketsUnder1KmAre5Meters() {
        XCTAssertEqual(RouteQualitySummaryPresentation.roundedMetres(412.0), 410)
        XCTAssertEqual(RouteQualitySummaryPresentation.roundedMetres(414.9), 415)
    }

    func testRoundingBucketsAbove1KmAre50Meters() {
        XCTAssertEqual(RouteQualitySummaryPresentation.roundedMetres(1230.0), 1250)
        XCTAssertEqual(RouteQualitySummaryPresentation.roundedMetres(2475.0), 2500)
    }

    func testRoundingHandlesNonFinite() {
        XCTAssertEqual(RouteQualitySummaryPresentation.roundedMetres(.infinity), 0)
        XCTAssertEqual(RouteQualitySummaryPresentation.roundedMetres(.nan), 0)
        XCTAssertEqual(RouteQualitySummaryPresentation.roundedMetres(-5), 0)
    }

    // MARK: - Spacing / gap surfacing rules

    func testSpacingLineNilForEmptySummary() {
        let strings = RouteQualitySummaryPresentation.strings(for: .empty, german: false)
        XCTAssertNil(strings.spacingLine)
        XCTAssertNil(strings.largestGapLine)
    }

    func testLargestGapSurfacedOnContainsGapsLevelOnly() {
        let gapSummary = RouteQualitySummary(
            pointCount: 100, averageSpacingM: 12, largestGapM: 1500, level: .containsGaps
        )
        let goodSummary = RouteQualitySummary(
            pointCount: 100, averageSpacingM: 12, largestGapM: 13, level: .good
        )
        XCTAssertNotNil(RouteQualitySummaryPresentation.strings(for: gapSummary, german: false).largestGapLine)
        XCTAssertNil(RouteQualitySummaryPresentation.strings(for: goodSummary, german: false).largestGapLine)
    }

    func testSpacingLineContainsRoundedMetresAndLocalePrefix() {
        let summary = RouteQualitySummary(
            pointCount: 50, averageSpacingM: 12.7, largestGapM: 14.0, level: .good
        )
        let en = RouteQualitySummaryPresentation.strings(for: summary, german: false)
        let de = RouteQualitySummaryPresentation.strings(for: summary, german: true)
        XCTAssertEqual(en.spacingLine, "Average spacing: ~13 m")
        XCTAssertEqual(de.spacingLine, "Punktabstand: ~13 m")
    }

    // MARK: - Privacy contract

    func testStringsDoNotEmbedCoordinateLikeDecimals() {
        let summary = RouteQualitySummary(
            pointCount: 50, averageSpacingM: 50.123456, largestGapM: 200.789, level: .sparse
        )
        let strings = RouteQualitySummaryPresentation.strings(for: summary, german: false)
        let blob = [strings.title, strings.levelLabel, strings.levelHint,
                    strings.spacingLine ?? "", strings.largestGapLine ?? ""].joined(separator: " ")
        // The integers from rounded metres are fine; only forbid decimal
        // fragments like "50.123" that could look like coordinates.
        let pattern = #"\b\d{1,3}\.\d{3,}\b"#
        XCTAssertNil(blob.range(of: pattern, options: .regularExpression),
                     "Strings must not embed coordinate-like decimals.")
    }
}
