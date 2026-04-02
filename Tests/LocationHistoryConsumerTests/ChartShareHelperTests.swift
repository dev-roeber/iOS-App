import XCTest
@testable import LocationHistoryConsumerAppSupport

final class ChartShareHelperTests: XCTestCase {

    // MARK: - Filename format

    func testFilenameContainsCardType() {
        let payload = ChartShareHelper.payload(for: .topDays)
        XCTAssertTrue(payload.suggestedFilename.contains("topDays"))
    }

    func testFilenameContainsDateSuffix() {
        let payload = ChartShareHelper.payload(for: .monthlyTrend)
        // Should contain a date in yyyy-MM-dd format
        let datePattern = #"\d{4}-\d{2}-\d{2}"#
        let range = payload.suggestedFilename.range(of: datePattern, options: .regularExpression)
        XCTAssertNotNil(range, "Filename should contain a date: \(payload.suggestedFilename)")
    }

    func testFilenameEndsWithPng() {
        let payload = ChartShareHelper.payload(for: .highlights)
        XCTAssertTrue(payload.suggestedFilename.hasSuffix(".png"))
    }

    func testFilenameStartsWithLocationHistory() {
        let payload = ChartShareHelper.payload(for: .summaryCards)
        XCTAssertTrue(payload.suggestedFilename.hasPrefix("LocationHistory_Insights_"))
    }

    // MARK: - Title localization

    func testTitleContainsCardDisplayTitle() {
        for cardType in InsightsCardType.allCases {
            let payload = ChartShareHelper.payload(for: cardType)
            XCTAssertFalse(payload.title.isEmpty, "Title for \(cardType.rawValue) is empty")
            XCTAssertTrue(payload.title.contains(cardType.displayTitle),
                          "Title '\(payload.title)' does not contain '\(cardType.displayTitle)'")
        }
    }

    // MARK: - Range label in filename

    func testActiveLast7DaysFilterAddsRangeLabel() {
        let filter = HistoryDateRangeFilter(preset: .last7Days)
        let payload = ChartShareHelper.payload(for: .topDays, dateRange: filter)
        XCTAssertTrue(payload.suggestedFilename.contains("last7d"), payload.suggestedFilename)
    }

    func testActiveLast30DaysFilterAddsRangeLabel() {
        let filter = HistoryDateRangeFilter(preset: .last30Days)
        let payload = ChartShareHelper.payload(for: .topDays, dateRange: filter)
        XCTAssertTrue(payload.suggestedFilename.contains("last30d"), payload.suggestedFilename)
    }

    func testAllPresetDoesNotAddRangeLabel() {
        let filter = HistoryDateRangeFilter(preset: .all)
        let payload = ChartShareHelper.payload(for: .topDays, dateRange: filter)
        // "all" filter should not add a range suffix
        XCTAssertFalse(payload.suggestedFilename.contains("all"), payload.suggestedFilename)
    }

    func testNilRangeProducesNoRangeLabel() {
        let payload = ChartShareHelper.payload(for: .weekdayPattern, dateRange: nil)
        // Should just have type + date, no range label
        let expectedPattern = "LocationHistory_Insights_weekdayPattern_"
        XCTAssertTrue(payload.suggestedFilename.hasPrefix(expectedPattern), payload.suggestedFilename)
    }

    func testCustomRangeAddsDateRange() {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let end = calendar.date(from: DateComponents(year: 2024, month: 3, day: 31))!
        let filter = HistoryDateRangeFilter(preset: .custom, customStart: start, customEnd: end)
        let payload = ChartShareHelper.payload(for: .topDays, dateRange: filter)
        XCTAssertTrue(payload.suggestedFilename.contains("2024-01-01"), payload.suggestedFilename)
    }

    // MARK: - All card types produce valid payloads

    func testAllCardTypesProduceNonEmptyPayloads() {
        for cardType in InsightsCardType.allCases {
            let payload = ChartShareHelper.payload(for: cardType)
            XCTAssertFalse(payload.title.isEmpty)
            XCTAssertFalse(payload.suggestedFilename.isEmpty)
        }
    }

    // MARK: - New card types: streak and periodComparison

    func testStreakCardTypeFilenameContainsStreak() {
        let payload = ChartShareHelper.payload(for: .streak)
        XCTAssertTrue(payload.suggestedFilename.contains("streak"), payload.suggestedFilename)
    }

    func testPeriodComparisonCardTypeFilenameContainsKey() {
        let payload = ChartShareHelper.payload(for: .periodComparison)
        XCTAssertTrue(payload.suggestedFilename.contains("periodComparison"), payload.suggestedFilename)
    }

    func testStreakAndPeriodComparisonTitlesContainDisplayTitle() {
        for cardType in [InsightsCardType.streak, .periodComparison] {
            let payload = ChartShareHelper.payload(for: cardType)
            XCTAssertTrue(
                payload.title.contains(cardType.displayTitle),
                "Title '\(payload.title)' does not contain '\(cardType.displayTitle)'"
            )
        }
    }
}
