import XCTest
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class InsightsDrilldownBridgeTests: XCTestCase {
    func testFilteredSummariesApplyFavoritesDrilldown() {
        let summaries = [
            DaySummary(date: "2024-05-01", visitCount: 1, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: true),
            DaySummary(date: "2024-05-02", visitCount: 1, activityCount: 0, pathCount: 1, totalPathPointCount: 4, totalPathDistanceM: 1200, hasContent: true),
        ]

        let result = InsightsDrilldownBridge.filteredSummaries(
            summaries,
            applying: .filterDays(DayListFilter(activeChips: [.favorites])),
            favorites: ["2024-05-02"]
        )

        XCTAssertEqual(result.map(\.date), ["2024-05-02"])
    }

    func testFilteredSummariesApplyInclusiveDateRangeDrilldown() {
        let summaries = [
            DaySummary(date: "2024-05-01", visitCount: 0, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: true),
            DaySummary(date: "2024-05-15", visitCount: 0, activityCount: 0, pathCount: 1, totalPathPointCount: 5, totalPathDistanceM: 800, hasContent: true),
            DaySummary(date: "2024-06-01", visitCount: 0, activityCount: 0, pathCount: 1, totalPathPointCount: 5, totalPathDistanceM: 900, hasContent: true),
        ]

        let result = InsightsDrilldownBridge.filteredSummaries(
            summaries,
            applying: .filterDaysToDateRange(fromDate: "2024-05-01", toDate: "2024-05-31"),
            favorites: []
        )

        XCTAssertEqual(result.map(\.date), ["2024-05-01", "2024-05-15"])
    }

    func testPrefillDatesReturnsExactDayForExportDrilldown() {
        let dates = ["2024-05-01", "2024-05-02", "2024-05-03"]

        let result = InsightsDrilldownBridge.prefillDates(
            for: .prefillExportForDate("2024-05-02"),
            availableDates: dates
        )

        XCTAssertEqual(result, ["2024-05-02"])
    }

    func testPrefillDatesReturnsVisibleRangeForExportDrilldown() {
        let dates = ["2024-05-01", "2024-05-15", "2024-06-01"]

        let result = InsightsDrilldownBridge.prefillDates(
            for: .prefillExportForDateRange(fromDate: "2024-05-01", toDate: "2024-05-31"),
            availableDates: dates
        )

        XCTAssertEqual(result, ["2024-05-01", "2024-05-15"])
    }

    func testDayAndExportActionsAreSeparated() {
        XCTAssertNil(InsightsDrilldownBridge.dayListAction(from: .prefillExportForDate("2024-05-01")))
        XCTAssertNil(InsightsDrilldownBridge.exportAction(from: .filterDaysToDate("2024-05-01")))
        XCTAssertEqual(
            InsightsDrilldownBridge.dayListAction(from: .filterDaysToDate("2024-05-01")),
            .filterDaysToDate("2024-05-01")
        )
    }

    func testMonthDateRangeBuildsInclusiveBounds() {
        let range = InsightsDrilldownBridge.monthDateRange(for: "2024-02")

        XCTAssertEqual(range?.fromDate, "2024-02-01")
        XCTAssertEqual(range?.toDate, "2024-02-29")
    }

    func testPeriodDateRangeBuildsYearBounds() {
        let item = PeriodBreakdownItem(
            label: "2024",
            year: 2024,
            month: nil,
            days: 12,
            visits: 10,
            activities: 4,
            paths: 3,
            distanceM: 2500
        )

        let range = InsightsDrilldownBridge.dateRange(for: item)

        XCTAssertEqual(range?.fromDate, "2024-01-01")
        XCTAssertEqual(range?.toDate, "2024-12-31")
    }

    func testDescriptionLocalizesExactDayDrilldown() {
        let englishDate = localizedMediumDate("2024-05-02", locale: .init(identifier: "en"))
        let germanDate = localizedMediumDate("2024-05-02", locale: .init(identifier: "de"))
        let english = InsightsDrilldownBridge.description(
            for: .filterDaysToDate("2024-05-02"),
            language: .english
        )
        let german = InsightsDrilldownBridge.description(
            for: .prefillExportForDate("2024-05-02"),
            language: .german
        )

        XCTAssertEqual(english, "Insights drilldown: \(englishDate) in Days")
        XCTAssertEqual(german, "Insights-Drilldown: Export für \(germanDate)")
    }

    func testDescriptionLocalizesShowDayOnMapDrilldown() {
        let englishDate = localizedMediumDate("2024-07-04", locale: .init(identifier: "en"))
        let germanDate = localizedMediumDate("2024-07-04", locale: .init(identifier: "de"))

        let english = InsightsDrilldownBridge.description(
            for: .showDayOnMap("2024-07-04"),
            language: .english
        )
        let german = InsightsDrilldownBridge.description(
            for: .showDayOnMap("2024-07-04"),
            language: .german
        )

        XCTAssertEqual(english, "Insights drilldown: \(englishDate) on map")
        XCTAssertEqual(german, "Insights-Drilldown: \(germanDate) auf Karte")
    }

    func testShowDayOnMapBridgeFiltersToSingleDay() {
        let summaries = [
            DaySummary(date: "2024-05-01", visitCount: 1, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: true),
            DaySummary(date: "2024-07-04", visitCount: 2, activityCount: 1, pathCount: 1, totalPathPointCount: 10, totalPathDistanceM: 1500, hasContent: true),
            DaySummary(date: "2024-08-10", visitCount: 1, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: true),
        ]

        let result = InsightsDrilldownBridge.filteredSummaries(
            summaries,
            applying: .showDayOnMap("2024-07-04"),
            favorites: []
        )

        XCTAssertEqual(result.map(\.date), ["2024-07-04"])
    }

    private func localizedMediumDate(_ isoDate: String, locale: Locale) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(secondsFromGMT: 0)
        parser.dateFormat = "yyyy-MM-dd"

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        return formatter.string(from: parser.date(from: isoDate)!)
    }
}
