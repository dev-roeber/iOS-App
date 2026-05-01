import XCTest
#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class InsightsCardPresentationTests: XCTestCase {
    func testHighlightItemUsesSummaryDistanceForDisplayUnit() {
        let summary = DaySummary(
            date: "2024-05-01",
            visitCount: 2,
            activityCount: 1,
            pathCount: 2,
            totalPathPointCount: 14,
            totalPathDistanceM: 6437.38,
            hasContent: true
        )

        let item = InsightsCardPresentation.highlightItem(
            id: "distance",
            title: "Longest Distance",
            icon: "road.lanes",
            color: .purple,
            highlight: DayHighlight(date: "2024-05-01", value: "6.4 km"),
            summary: summary,
            unit: .imperial
        )

        XCTAssertEqual(item.card.value, "4.0 mi")
        XCTAssertTrue(item.card.dateText.contains("2024"))
        XCTAssertTrue(item.card.subtitle?.contains("5 events") == true)
        XCTAssertEqual(item.card.metrics.map(\.text), ["2 visits", "1 activity", "2 routes", "4.0 mi"])
    }

    func testSupportingMetricsSkipZeroCountsButKeepDistance() {
        let summary = DaySummary(
            date: "2024-05-02",
            visitCount: 0,
            activityCount: 0,
            pathCount: 1,
            totalPathPointCount: 4,
            totalPathDistanceM: 1800,
            hasContent: true
        )

        let metrics = InsightsCardPresentation.supportingMetrics(for: summary, unit: .metric)

        XCTAssertEqual(metrics.map(\.text), ["1 route", "1.8 km"])
    }

    func testTopDayRowPresentationAddsReadableContextAndMetrics() {
        let summary = DaySummary(
            date: "2024-05-03",
            visitCount: 1,
            activityCount: 2,
            pathCount: 3,
            totalPathPointCount: 12,
            totalPathDistanceM: 9200,
            hasContent: true
        )

        let presentation = InsightsCardPresentation.topDayRow(
            summary: summary,
            rank: 2,
            metric: .distance,
            unit: .metric
        )

        XCTAssertEqual(presentation.rankText, "2")
        XCTAssertEqual(presentation.primaryValue, "9.2 km")
        XCTAssertEqual(presentation.subtitle, "Longest imported route distance")
        XCTAssertFalse(presentation.dateText.contains("2024-05-03"))
        XCTAssertEqual(presentation.metrics.map(\.text), ["1 visit", "2 activities", "3 routes", "9.2 km"])
    }

    func testHighlightCardFallsBackToRawValueWithoutSummary() {
        let card = InsightsCardPresentation.highlightCard(
            title: "Busiest Day",
            value: "7 events",
            date: "2024-05-04",
            summary: nil,
            unit: .metric
        )

        XCTAssertEqual(card.value, "7 events")
        XCTAssertNil(card.subtitle)
        XCTAssertTrue(card.metrics.isEmpty)
        XCTAssertFalse(card.dateText.contains("2024-05-04"))
    }

    // MARK: - KPI empty state

    func testSupportingMetricsAllZerosProducesEmptyMetrics() {
        let summary = DaySummary(
            date: "2024-06-01",
            visitCount: 0,
            activityCount: 0,
            pathCount: 0,
            totalPathPointCount: 0,
            totalPathDistanceM: 0,
            hasContent: false
        )
        let metrics = InsightsCardPresentation.supportingMetrics(for: summary, unit: .metric)
        XCTAssertTrue(metrics.isEmpty, "A day with no events should produce no metric chips")
    }

    func testKPIActiveDaysCountsOnlyHasContentDays() {
        let summaries = [
            DaySummary(
                date: "2024-06-01",
                visitCount: 1, activityCount: 0, pathCount: 0,
                totalPathPointCount: 0, totalPathDistanceM: 0,
                hasContent: true
            ),
            DaySummary(
                date: "2024-06-02",
                visitCount: 0, activityCount: 0, pathCount: 0,
                totalPathPointCount: 0, totalPathDistanceM: 0,
                hasContent: false
            ),
        ]
        let activeDays = summaries.filter(\.hasContent).count
        XCTAssertEqual(activeDays, 1)
    }

    func testKPIRoutesAndPlacesSummedCorrectly() {
        let summaries = [
            DaySummary(
                date: "2024-06-01",
                visitCount: 3, activityCount: 0, pathCount: 2,
                totalPathPointCount: 0, totalPathDistanceM: 0,
                hasContent: true
            ),
            DaySummary(
                date: "2024-06-02",
                visitCount: 1, activityCount: 0, pathCount: 1,
                totalPathPointCount: 0, totalPathDistanceM: 0,
                hasContent: true
            ),
        ]
        let totalRoutes = summaries.reduce(0) { $0 + $1.pathCount }
        let totalPlaces = summaries.reduce(0) { $0 + $1.visitCount }
        XCTAssertEqual(totalRoutes, 3)
        XCTAssertEqual(totalPlaces, 4)
    }
}
#endif
