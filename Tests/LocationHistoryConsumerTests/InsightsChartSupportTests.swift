import XCTest
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class InsightsChartSupportTests: XCTestCase {
    func testAvailableActivityMetricsOnlyShowsDistanceWhenPresent() {
        let withoutDistance = [
            ActivityBreakdownItem(activityType: "WALKING", count: 2, totalDistanceKM: 0, totalDurationH: 0.5, avgSpeedKMH: 0),
        ]
        let withDistance = [
            ActivityBreakdownItem(activityType: "WALKING", count: 2, totalDistanceKM: 1.2, totalDurationH: 0.5, avgSpeedKMH: 4.2),
        ]

        XCTAssertEqual(InsightsChartSupport.availableActivityMetrics(for: withoutDistance), [.count])
        XCTAssertEqual(InsightsChartSupport.availableActivityMetrics(for: withDistance), [.count, .distance])
    }

    func testDistanceMessagesDifferentiateNavigationAndMissingData() {
        XCTAssertEqual(
            InsightsChartSupport.distanceSectionMessage(hasDays: true, canNavigateToDay: true),
            "Route distance with recorded-trace fallback. Tap a bar to open that day."
        )
        XCTAssertEqual(
            InsightsChartSupport.distanceSectionMessage(hasDays: true, canNavigateToDay: false),
            "Route distance with recorded-trace fallback."
        )
        XCTAssertEqual(
            InsightsChartSupport.distanceEmptyMessage(),
            "No route distance or recorded trace data is available for these days."
        )
    }

    func testWeekdayMessageExplainsLowDataThresholds() {
        XCTAssertEqual(
            InsightsChartSupport.weekdaySectionMessage(dayCount: 2, bucketCount: 2),
            "Need at least 3 days before a weekday pattern is meaningful."
        )
        XCTAssertEqual(
            InsightsChartSupport.weekdaySectionMessage(dayCount: 5, bucketCount: 1),
            "Need data across multiple weekdays before this chart becomes useful."
        )
        XCTAssertNil(InsightsChartSupport.weekdaySectionMessage(dayCount: 5, bucketCount: 3))
    }

    func testOverviewStateDistinguishesNoDaysAndSparseExports() {
        XCTAssertEqual(
            InsightsChartSupport.overviewState(
                dayCount: 0,
                hasDistanceData: false,
                hasActivityData: false,
                hasVisitData: false,
                hasPeriodData: false
            ),
            .noDays
        )
        XCTAssertEqual(
            InsightsChartSupport.overviewState(
                dayCount: 1,
                hasDistanceData: false,
                hasActivityData: false,
                hasVisitData: false,
                hasPeriodData: false
            ),
            .sparseHistory(dayCount: 1)
        )
        XCTAssertEqual(
            InsightsChartSupport.overviewState(
                dayCount: 2,
                hasDistanceData: false,
                hasActivityData: false,
                hasVisitData: false,
                hasPeriodData: false
            ),
            .ready
        )
    }

    func testSectionMessagesCoverMissingAggregates() {
        XCTAssertEqual(
            InsightsChartSupport.dailyAveragesSectionMessage(dayCount: 1),
            "Need at least 2 days before per-day averages become useful."
        )
        XCTAssertNil(InsightsChartSupport.dailyAveragesSectionMessage(dayCount: 2))
        XCTAssertEqual(
            InsightsChartSupport.activitySectionEmptyMessage(),
            "No activity totals are available for these days."
        )
        XCTAssertEqual(
            InsightsChartSupport.visitSectionEmptyMessage(),
            "No semantic visit categories are available for these days."
        )
        XCTAssertEqual(
            InsightsChartSupport.periodSectionEmptyMessage(),
            "This export does not include any period breakdown stats."
        )
    }

    func testNearestDayChoosesClosestISODate() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let tapped = formatter.date(from: "2024-05-02 18:00")!

        let result = InsightsChartSupport.nearestDayISODate(
            to: tapped,
            in: ["2024-05-01", "2024-05-03", "2024-05-10"]
        )

        XCTAssertEqual(result, "2024-05-03")
    }

    func testWeekdayMetricsAndStatsReflectDistanceAndRoutes() {
        let summaries = [
            DaySummary(date: "2024-05-06", visitCount: 1, activityCount: 1, pathCount: 2, totalPathPointCount: 6, totalPathDistanceM: 2400, hasContent: true),
            DaySummary(date: "2024-05-13", visitCount: 0, activityCount: 1, pathCount: 1, totalPathPointCount: 3, totalPathDistanceM: 1200, hasContent: true),
            DaySummary(date: "2024-05-07", visitCount: 2, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: true),
        ]

        XCTAssertEqual(
            InsightsChartSupport.availableWeekdayMetrics(for: summaries),
            [.events, .routes, .distance]
        )

        let weekdayDistance = InsightsChartSupport.weekdayStats(
            from: summaries,
            metric: .distance,
            locale: Locale(identifier: "en")
        )
        let weekdayRoutes = InsightsChartSupport.weekdayStats(
            from: summaries,
            metric: .routes,
            locale: Locale(identifier: "en")
        )

        guard let firstWeekdayDistance = weekdayDistance.first,
              let firstWeekdayRoutes = weekdayRoutes.first else {
            XCTFail("Expected weekday stats for Monday")
            return
        }

        XCTAssertEqual(firstWeekdayDistance.label, "Mon")
        XCTAssertEqual(firstWeekdayDistance.sampleCount, 2)
        XCTAssertEqual(firstWeekdayDistance.averageValue, 1800, accuracy: 0.001)
        XCTAssertEqual(firstWeekdayRoutes.averageValue, 1.5, accuracy: 0.001)
    }

    func testPeriodMetricsExposeDaysEventsAndDistance() {
        let items = [
            PeriodBreakdownItem(label: "2024-01", year: 2024, month: 1, days: 2, visits: 3, activities: 1, paths: 2, distanceM: 1800),
            PeriodBreakdownItem(label: "2024-02", year: 2024, month: 2, days: 1, visits: 0, activities: 1, paths: 0, distanceM: 0),
        ]

        XCTAssertEqual(
            InsightsChartSupport.availablePeriodMetrics(for: items),
            [.days, .events, .distance]
        )
        XCTAssertEqual(InsightsChartSupport.periodMetricValue(for: items[0], metric: .days), 2)
        XCTAssertEqual(InsightsChartSupport.periodMetricValue(for: items[0], metric: .events), 6)
        XCTAssertEqual(InsightsChartSupport.periodMetricValue(for: items[0], metric: .distance), 1800, accuracy: 0.001)
    }
}
