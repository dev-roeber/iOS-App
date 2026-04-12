import XCTest
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

// MARK: - Tests for tasks 1-3, 6, 7, 9

final class OverviewFavoritesAndInsightsTests: XCTestCase {

    // MARK: - Task 2: Favorites-filter state

    func testOverviewFilteredSummaries_showsAllWhenNoFavoritesFilter() {
        let summaries = makeSummaries(dates: ["2024-01-01", "2024-01-02", "2024-01-03"])
        let favorites: Set<String> = ["2024-01-02"]
        let filtered = DayListPresentation.filteredSummaries(
            summaries,
            query: "",
            filter: .empty,
            favorites: favorites
        )
        XCTAssertEqual(filtered.count, 3)
    }

    func testOverviewFilteredSummaries_showsOnlyFavoritesWhenFilterActive() {
        let summaries = makeSummaries(dates: ["2024-01-01", "2024-01-02", "2024-01-03"])
        let favorites: Set<String> = ["2024-01-02"]
        var filter = DayListFilter.empty
        filter.toggle(.favorites)

        let filtered = DayListPresentation.filteredSummaries(
            summaries,
            query: "",
            filter: filter,
            favorites: favorites
        )
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.date, "2024-01-02")
    }

    func testOverviewFilteredSummaries_emptyWhenNoFavoritesExist() {
        let summaries = makeSummaries(dates: ["2024-01-01", "2024-01-02"])
        let favorites: Set<String> = []
        var filter = DayListFilter.empty
        filter.toggle(.favorites)

        let filtered = DayListPresentation.filteredSummaries(
            summaries,
            query: "",
            filter: filter,
            favorites: favorites
        )
        XCTAssertTrue(filtered.isEmpty)
    }

    // MARK: - Task 7: HistoryDateRangeFilter timezone fix

    func testFromDateStringUsesLocalTimezone() {
        // The fromDateString must produce a date string that matches the calendar
        // day in the device's local timezone, not UTC.
        let calendar = Calendar.current
        // Use a specific date to avoid ambiguity: start of today in local timezone.
        let todayStart = calendar.startOfDay(for: Date())

        var filter = HistoryDateRangeFilter(preset: .custom)
        filter.customStart = todayStart
        filter.customEnd = todayStart

        guard let fromStr = filter.fromDateString else {
            return XCTFail("fromDateString must not be nil for custom filter with valid dates")
        }

        // Verify the produced date string matches today in local calendar terms.
        let expectedComponents = calendar.dateComponents([.year, .month, .day], from: todayStart)
        let expectedStr = String(
            format: "%04d-%02d-%02d",
            expectedComponents.year!,
            expectedComponents.month!,
            expectedComponents.day!
        )
        XCTAssertEqual(fromStr, expectedStr,
            "fromDateString should match the local calendar day, not the UTC day")
    }

    func testToDateStringUsesLocalTimezone() {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        var filter = HistoryDateRangeFilter(preset: .custom)
        filter.customStart = todayStart
        filter.customEnd = todayStart

        guard let toStr = filter.toDateString else {
            return XCTFail("toDateString must not be nil for custom filter with valid dates")
        }

        let expectedComponents = calendar.dateComponents([.year, .month, .day], from: todayStart)
        let expectedStr = String(
            format: "%04d-%02d-%02d",
            expectedComponents.year!,
            expectedComponents.month!,
            expectedComponents.day!
        )
        XCTAssertEqual(toStr, expectedStr,
            "toDateString should match the local calendar day, not the UTC day")
    }

    // MARK: - Task 6: Top-Tage limit = 20

    func testTopDaysReturnsUpTo20Entries() {
        // Build 25 summaries, each with distinct distance so all are rankable.
        var summaries: [DaySummary] = []
        for i in 1...25 {
            summaries.append(DaySummary(
                date: String(format: "2024-%02d-01", i > 12 ? i - 12 : i),
                visitCount: i,
                activityCount: 1,
                pathCount: 1,
                totalPathPointCount: 4,
                totalPathDistanceM: Double(i * 1000),
                hasContent: true
            ))
        }
        let result = InsightsTopDaysPresentation.topDays(from: summaries, by: .distance, limit: 20)
        XCTAssertEqual(result.count, 20, "Top days should return up to 20 entries with limit: 20")
    }

    func testTopDaysReturnsAllWhenFewerThan20Available() {
        let summaries = (1...5).map { i -> DaySummary in
            DaySummary(
                date: "2024-01-\(String(format: "%02d", i))",
                visitCount: i,
                activityCount: 0,
                pathCount: 1,
                totalPathPointCount: 4,
                totalPathDistanceM: Double(i * 500),
                hasContent: true
            )
        }
        let result = InsightsTopDaysPresentation.topDays(from: summaries, by: .distance, limit: 20)
        XCTAssertEqual(result.count, 5, "Should return all 5 when fewer than 20 available")
    }

    // MARK: - Task 9: Localization — DE strings present for new keys

    func testGermanTranslationForFavoritesOnly() {
        let lang = AppLanguagePreference.german
        let result = lang.localized("Favorites Only")
        XCTAssertNotEqual(result, "Favorites Only",
            "German translation for 'Favorites Only' must be present")
        XCTAssertFalse(result.isEmpty)
    }

    func testGermanTranslationForNoTracksInRange() {
        let lang = AppLanguagePreference.german
        let result = lang.localized("No tracks in selected range")
        XCTAssertNotEqual(result, "No tracks in selected range",
            "German translation for 'No tracks in selected range' must be present")
    }

    func testGermanTranslationForComputingHeatmap() {
        let lang = AppLanguagePreference.german
        let result = lang.localized("Computing heatmap…")
        XCTAssertNotEqual(result, "Computing heatmap…",
            "German translation for 'Computing heatmap…' must be present")
    }

    func testGermanTranslationForAllDaysPresent() {
        // "All Days" was already present; verify it remains correct.
        let lang = AppLanguagePreference.german
        let result = lang.localized("All Days")
        XCTAssertFalse(result.isEmpty)
    }

    func testEnglishTranslationIdentity() {
        // English localization must always return the key unchanged.
        let lang = AppLanguagePreference.english
        for key in ["Favorites Only", "No tracks in selected range", "Computing heatmap…"] {
            XCTAssertEqual(lang.localized(key), key,
                "English localization must return the key for '\(key)'")
        }
    }

    // MARK: - Task 7: Insights period comparison strings localized

    func testInsightsPeriodComparisonStringsHaveGermanTranslations() {
        let lang = AppLanguagePreference.german
        let keys = [
            InsightsPeriodComparisonPresentation.allTimeMessage(),
            InsightsPeriodComparisonPresentation.noRangeMessage(),
            InsightsPeriodComparisonPresentation.sectionHint()
        ]
        for key in keys {
            let result = lang.localized(key)
            XCTAssertNotEqual(result, key,
                "Missing German translation for: '\(key)'")
        }
    }

    func testInsightsStreakNoDataMessageHasGermanTranslation() {
        let lang = AppLanguagePreference.german
        let key = InsightsStreakPresentation.noDataMessage()
        let result = lang.localized(key)
        XCTAssertNotEqual(result, key,
            "Missing German translation for streak no-data message")
    }

    // MARK: - Helpers

    private func makeSummaries(dates: [String]) -> [DaySummary] {
        dates.map { date in
            DaySummary(
                date: date,
                visitCount: 1,
                activityCount: 0,
                pathCount: 1,
                totalPathPointCount: 4,
                totalPathDistanceM: 1000,
                hasContent: true
            )
        }
    }
}
