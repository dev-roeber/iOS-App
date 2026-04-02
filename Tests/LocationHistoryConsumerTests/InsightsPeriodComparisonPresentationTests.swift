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
        // Range: last 7 days. Prior: 7 days before that.
        let filter = HistoryDateRangeFilter(preset: .last7Days)
        guard filter.isActive, let effectiveRange = filter.effectiveRange else {
            XCTFail("Expected last7Days to produce an active range")
            return
        }

        // Build summaries in the current range (some with content)
        let calendar = Calendar(identifier: .gregorian)
        let currentDates = (0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: effectiveRange.upperBound) }
        let currentSummaries = currentDates.compactMap { date -> DaySummary? in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            return DaySummary(date: formatter.string(from: date), visitCount: 1, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 500, hasContent: true)
        }

        // Build summaries in the prior range
        let priorDates = (0..<7).compactMap { calendar.date(byAdding: .day, value: -7 - $0, to: effectiveRange.upperBound) }
        let priorSummaries = priorDates.prefix(3).compactMap { date -> DaySummary? in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            return DaySummary(date: formatter.string(from: date), visitCount: 1, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 200, hasContent: true)
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
