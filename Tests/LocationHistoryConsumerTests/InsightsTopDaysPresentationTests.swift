import XCTest
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class InsightsTopDaysPresentationTests: XCTestCase {
    func testAvailableMetricsOnlyIncludesSupportedData() {
        let summaries = [
            DaySummary(
                date: "2024-05-01",
                visitCount: 2,
                activityCount: 1,
                pathCount: 0,
                totalPathPointCount: 0,
                totalPathDistanceM: 0,
                hasContent: true
            ),
            DaySummary(
                date: "2024-05-02",
                visitCount: 0,
                activityCount: 0,
                pathCount: 2,
                totalPathPointCount: 8,
                totalPathDistanceM: 2400,
                hasContent: true
            ),
        ]

        XCTAssertEqual(
            InsightsTopDaysPresentation.availableMetrics(for: summaries),
            [.events, .visits, .routes, .distance]
        )
    }

    func testTopDaysRankByMetricAndPreferStrongerTieBreakers() {
        let summaries = [
            DaySummary(
                date: "2024-05-01",
                visitCount: 2,
                activityCount: 1,
                pathCount: 1,
                totalPathPointCount: 4,
                totalPathDistanceM: 1600,
                hasContent: true
            ),
            DaySummary(
                date: "2024-05-02",
                visitCount: 2,
                activityCount: 1,
                pathCount: 1,
                totalPathPointCount: 5,
                totalPathDistanceM: 2400,
                hasContent: true
            ),
            DaySummary(
                date: "2024-05-03",
                visitCount: 1,
                activityCount: 0,
                pathCount: 3,
                totalPathPointCount: 6,
                totalPathDistanceM: 1200,
                hasContent: true
            ),
        ]

        XCTAssertEqual(
            InsightsTopDaysPresentation.topDays(from: summaries, by: .events).map(\.date),
            ["2024-05-02", "2024-05-01", "2024-05-03"]
        )
        XCTAssertEqual(
            InsightsTopDaysPresentation.topDays(from: summaries, by: .routes).map(\.date),
            ["2024-05-03", "2024-05-02", "2024-05-01"]
        )
        XCTAssertEqual(
            InsightsTopDaysPresentation.topDays(from: summaries, by: .distance).map(\.date),
            ["2024-05-02", "2024-05-01", "2024-05-03"]
        )
    }

    func testSectionMessageIncludesNavigationHintWhenAvailable() {
        XCTAssertEqual(
            InsightsTopDaysPresentation.sectionMessage(metric: .distance, canNavigateToDay: false),
            "Ranked by total route distance."
        )
        XCTAssertEqual(
            InsightsTopDaysPresentation.sectionMessage(metric: .events, canNavigateToDay: true),
            "Ranked by total visits, activities and routes. Tap a row to open drilldown actions for that day."
        )
    }

    // MARK: - Empty range message

    func testEmptyRangeMessageIsNonEmpty() {
        XCTAssertFalse(InsightsTopDaysPresentation.emptyRangeMessage().isEmpty)
    }

    func testTopDaysReturnsEmptyForSummariesWithNoContent() {
        let summaries = [
            DaySummary(
                date: "2024-05-01",
                visitCount: 0,
                activityCount: 0,
                pathCount: 0,
                totalPathPointCount: 0,
                totalPathDistanceM: 0,
                hasContent: false
            ),
        ]
        let result = InsightsTopDaysPresentation.topDays(from: summaries, by: .events)
        XCTAssertTrue(result.isEmpty, "topDays must be empty when no summaries have content")
        XCTAssertFalse(InsightsTopDaysPresentation.emptyRangeMessage().isEmpty)
    }
}
