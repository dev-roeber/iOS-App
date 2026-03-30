import XCTest
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class InsightsMonthlyTrendPresentationTests: XCTestCase {
    func testItemsAggregateMonthsInChronologicalOrder() {
        let summaries = [
            DaySummary(date: "2024-02-15", visitCount: 1, activityCount: 0, pathCount: 1, totalPathPointCount: 4, totalPathDistanceM: 1000, hasContent: true),
            DaySummary(date: "2024-01-03", visitCount: 2, activityCount: 1, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: true),
            DaySummary(date: "2024-02-20", visitCount: 0, activityCount: 1, pathCount: 1, totalPathPointCount: 5, totalPathDistanceM: 2400, hasContent: true),
        ]

        let items = InsightsMonthlyTrendPresentation.items(from: summaries, locale: Locale(identifier: "en"))

        XCTAssertEqual(items.map(\.monthKey), ["2024-01", "2024-02"])
        XCTAssertEqual(items[0].events, 3)
        XCTAssertEqual(items[1].events, 4)
        XCTAssertEqual(items[1].distanceM, 3400, accuracy: 0.001)
    }

    func testAvailableMetricsReflectVisibleSignals() {
        let items = [
            InsightsMonthlyTrendItem(monthKey: "2024-01", label: "January 2024", days: 2, visits: 3, activities: 1, routes: 0, distanceM: 0),
            InsightsMonthlyTrendItem(monthKey: "2024-02", label: "February 2024", days: 1, visits: 0, activities: 0, routes: 2, distanceM: 1200),
        ]

        XCTAssertEqual(
            InsightsMonthlyTrendPresentation.availableMetrics(for: items),
            [.distance, .events, .visits, .routes]
        )
        XCTAssertEqual(InsightsMonthlyTrendPresentation.value(for: items[1], metric: .routes), 2)
    }
}
