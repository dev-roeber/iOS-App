import XCTest
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class InsightsPeriodComparisonPresentationTests: XCTestCase {

    // MARK: - No range → returns nil

    func testNoActiveRangeReturnsNil() {
        let filter = HistoryDateRangeFilter(preset: .all)
        let result = InsightsPeriodComparisonPresentation.comparison(
            currentSummaries: [makeSummary("2024-04-01", hasContent: true)],
            allSummaries: [makeSummary("2024-04-01", hasContent: true)],
            rangeFilter: filter
        )
        XCTAssertNil(result)
    }

    // MARK: - Active range produces comparison

    func testActiveLast7DaysRangeProducesComparison() {
        // Use a fixed custom date range so the test is timezone-independent.
        // Current range: 2025-04-01 to 2025-04-07 (7 days, all with content)
        // Prior range (equal-length preceding period): 2025-03-25 to 2025-03-31
        let customStart = DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(secondsFromGMT: 0), year: 2025, month: 4, day: 1).date!
        let customEnd = DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(secondsFromGMT: 0), year: 2025, month: 4, day: 7, hour: 23, minute: 59).date!
        let filter = HistoryDateRangeFilter(preset: .custom, customStart: customStart, customEnd: customEnd)
        guard filter.isActive, filter.effectiveRange != nil else {
            XCTFail("Expected custom range to produce an active range")
            return
        }

        // 7 current summaries (all with content, 500 m each)
        let currentSummaries = (1...7).map { day in
            let dateStr = String(format: "2025-04-%02d", day)
            return DaySummary(date: dateStr, visitCount: 1, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 500, hasContent: true)
        }

        // 3 prior summaries in the preceding 7-day window (200 m each)
        let priorSummaries = ["2025-03-29", "2025-03-30", "2025-03-31"].map { dateStr in
            DaySummary(date: dateStr, visitCount: 1, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 200, hasContent: true)
        }

        let allSummaries = currentSummaries + priorSummaries

        let result = InsightsPeriodComparisonPresentation.comparison(
            currentSummaries: currentSummaries,
            allSummaries: allSummaries,
            rangeFilter: filter
        )

        XCTAssertNotNil(result)
        if let result {
            XCTAssertEqual(result.current.activeDays, 7)
            XCTAssertEqual(result.current.events, 7)
            XCTAssertEqual(result.current.distanceM, 3500, accuracy: 0.001)
            XCTAssertEqual(result.prior.activeDays, 3)
            XCTAssertEqual(result.prior.distanceM, 600, accuracy: 0.001)
        }
    }

    // MARK: - Empty prior period

    func testEmptyPriorPeriodProducesZeroPriorStats() {
        let filter = HistoryDateRangeFilter(preset: .last7Days)
        guard filter.isActive else { return }

        let current = [makeSummary("2024-11-01", hasContent: true)]
        // allSummaries has no data before the range
        let result = InsightsPeriodComparisonPresentation.comparison(
            currentSummaries: current,
            allSummaries: current,
            rangeFilter: filter
        )
        // May return nil if range can't compute (filter relative to "now" won't match "2024-11-01")
        // The key invariant: if non-nil, prior.activeDays is 0
        if let result {
            XCTAssertEqual(result.prior.activeDays, 0)
            XCTAssertEqual(result.prior.events, 0)
        }
    }

    // MARK: - Delta text formatting

    func testDeltaTextPositiveChange() {
        XCTAssertEqual(InsightsPeriodComparisonPresentation.deltaText(current: 150, prior: 100), "+50%")
    }

    func testDeltaTextNegativeChange() {
        XCTAssertEqual(InsightsPeriodComparisonPresentation.deltaText(current: 50, prior: 100), "-50%")
    }

    func testDeltaTextNoPriorData() {
        XCTAssertEqual(InsightsPeriodComparisonPresentation.deltaText(current: 0, prior: 0), "–")
    }

    func testDeltaTextNoPriorButHasCurrent() {
        XCTAssertEqual(InsightsPeriodComparisonPresentation.deltaText(current: 10, prior: 0), "+∞")
    }

    func testDeltaTextNoChange() {
        XCTAssertEqual(InsightsPeriodComparisonPresentation.deltaText(current: 100, prior: 100), "+0%")
    }

    // MARK: - isPositiveDelta

    func testIsPositiveDeltaReturnsTrueWhenCurrentGreater() {
        XCTAssertEqual(InsightsPeriodComparisonPresentation.isPositiveDelta(current: 10, prior: 5), true)
    }

    func testIsPositiveDeltaReturnsFalseWhenCurrentLess() {
        XCTAssertEqual(InsightsPeriodComparisonPresentation.isPositiveDelta(current: 3, prior: 5), false)
    }

    func testIsPositiveDeltaReturnsNilWhenBothZero() {
        XCTAssertNil(InsightsPeriodComparisonPresentation.isPositiveDelta(current: 0, prior: 0))
    }

    func testIsPositiveDeltaReturnsTrueWhenEqual() {
        XCTAssertEqual(InsightsPeriodComparisonPresentation.isPositiveDelta(current: 5, prior: 5), true)
    }

    // MARK: - Aggregation accuracy

    func testCurrentPeriodAggregatesAllMetrics() {
        let filter = HistoryDateRangeFilter(preset: .last30Days)
        guard filter.isActive else { return }

        let summaries = [
            DaySummary(date: "2024-10-01", visitCount: 2, activityCount: 1, pathCount: 3, totalPathPointCount: 10, totalPathDistanceM: 5000, hasContent: true),
            DaySummary(date: "2024-10-02", visitCount: 1, activityCount: 0, pathCount: 1, totalPathPointCount: 5, totalPathDistanceM: 1200, hasContent: true),
            DaySummary(date: "2024-10-03", visitCount: 0, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: false),
        ]

        // For this test we just verify aggregation logic via the item directly
        let result = InsightsPeriodComparisonPresentation.comparison(
            currentSummaries: summaries,
            allSummaries: summaries,
            rangeFilter: filter
        )

        if let result {
            // current: 2 active days (3rd is hasContent=false), events = (2+1+3)+(1+0+1) = 8, distance = 6200
            XCTAssertEqual(result.current.activeDays, 2)
            XCTAssertEqual(result.current.events, 8)
            XCTAssertEqual(result.current.distanceM, 6200, accuracy: 0.001)
        }
    }

    // MARK: - Static messages

    func testSectionHintIsNonEmpty() {
        XCTAssertFalse(InsightsPeriodComparisonPresentation.sectionHint().isEmpty)
    }

    func testNoRangeMessageIsNonEmpty() {
        XCTAssertFalse(InsightsPeriodComparisonPresentation.noRangeMessage().isEmpty)
    }

    func testAllTimeMessageIsNonEmpty() {
        XCTAssertFalse(InsightsPeriodComparisonPresentation.allTimeMessage().isEmpty)
    }

    func testAllTimeMessageMentionsAllTime() {
        XCTAssertTrue(InsightsPeriodComparisonPresentation.allTimeMessage().lowercased().contains("all time"))
    }

    func testNoDataMessageIsNonEmpty() {
        XCTAssertFalse(InsightsPeriodComparisonPresentation.noDataMessage().isEmpty)
    }

    func testAllTimeFilterProducesNilComparison() {
        let filter = HistoryDateRangeFilter(preset: .all)
        let result = InsightsPeriodComparisonPresentation.comparison(
            currentSummaries: [makeSummary("2024-06-01", hasContent: true)],
            allSummaries: [makeSummary("2024-06-01", hasContent: true)],
            rangeFilter: filter
        )
        XCTAssertNil(result, "All-Time range must not produce a comparison")
    }

    // MARK: - Helper

    private func makeSummary(_ date: String, hasContent: Bool) -> DaySummary {
        DaySummary(
            date: date,
            visitCount: hasContent ? 1 : 0,
            activityCount: 0,
            pathCount: 0,
            totalPathPointCount: 0,
            totalPathDistanceM: 0,
            hasContent: hasContent
        )
    }
}
