import XCTest
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class InsightsStreakPresentationTests: XCTestCase {

    // MARK: - Empty / no data

    func testEmptyInputProducesZeroStreak() {
        let stat = InsightsStreakPresentation.streak(from: [])
        XCTAssertEqual(stat.longestStreakDays, 0)
        XCTAssertEqual(stat.recentStreakDays, 0)
        XCTAssertNil(stat.longestStreakStart)
        XCTAssertNil(stat.recentStreakStart)
        XCTAssertEqual(stat.activeDaysCount, 0)
        XCTAssertEqual(stat.totalDaysCount, 0)
    }

    func testAllInactiveDaysProducesZeroStreak() {
        let summaries = [
            DaySummary(date: "2024-05-01", visitCount: 0, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: false),
            DaySummary(date: "2024-05-02", visitCount: 0, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: false),
        ]
        let stat = InsightsStreakPresentation.streak(from: summaries)
        XCTAssertEqual(stat.longestStreakDays, 0)
        XCTAssertEqual(stat.recentStreakDays, 0)
        XCTAssertEqual(stat.activeDaysCount, 0)
        XCTAssertEqual(stat.totalDaysCount, 2)
    }

    // MARK: - Single day

    func testSingleActiveDayProducesStreakOfOne() {
        let summaries = [
            DaySummary(date: "2024-06-15", visitCount: 1, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: true),
        ]
        let stat = InsightsStreakPresentation.streak(from: summaries)
        XCTAssertEqual(stat.longestStreakDays, 1)
        XCTAssertEqual(stat.recentStreakDays, 1)
        XCTAssertEqual(stat.longestStreakStart, "2024-06-15")
        XCTAssertEqual(stat.longestStreakEnd, "2024-06-15")
        XCTAssertEqual(stat.recentStreakStart, "2024-06-15")
        XCTAssertEqual(stat.activeDaysCount, 1)
    }

    // MARK: - Consecutive days

    func testFullyConsecutiveDaysProduceSingleStreak() {
        let summaries = (1...5).map { day in
            DaySummary(
                date: String(format: "2024-07-%02d", day),
                visitCount: 1, activityCount: 0, pathCount: 0,
                totalPathPointCount: 0, totalPathDistanceM: 0,
                hasContent: true
            )
        }
        let stat = InsightsStreakPresentation.streak(from: summaries)
        XCTAssertEqual(stat.longestStreakDays, 5)
        XCTAssertEqual(stat.recentStreakDays, 5)
        XCTAssertEqual(stat.longestStreakStart, "2024-07-01")
        XCTAssertEqual(stat.longestStreakEnd, "2024-07-05")
        XCTAssertEqual(stat.activeDaysCount, 5)
    }

    // MARK: - Gap breaks the streak

    func testGapBetweenDaysBreaksStreak() {
        let summaries = [
            DaySummary(date: "2024-08-01", visitCount: 1, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: true),
            DaySummary(date: "2024-08-02", visitCount: 1, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: true),
            // gap: 08-03 missing
            DaySummary(date: "2024-08-04", visitCount: 1, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: true),
            DaySummary(date: "2024-08-05", visitCount: 1, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: true),
            DaySummary(date: "2024-08-06", visitCount: 1, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: true),
        ]
        let stat = InsightsStreakPresentation.streak(from: summaries)
        XCTAssertEqual(stat.longestStreakDays, 3)
        XCTAssertEqual(stat.longestStreakStart, "2024-08-04")
        XCTAssertEqual(stat.longestStreakEnd, "2024-08-06")
        XCTAssertEqual(stat.recentStreakDays, 3)
        XCTAssertEqual(stat.recentStreakStart, "2024-08-04")
        XCTAssertEqual(stat.activeDaysCount, 5)
    }

    // MARK: - Inactive days within loaded range do not break streak

    func testInactiveDayWithinLoadedRangeDoesNotBreakStreak() {
        let summaries = [
            DaySummary(date: "2024-09-01", visitCount: 1, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: true),
            DaySummary(date: "2024-09-02", visitCount: 0, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: false),
            DaySummary(date: "2024-09-03", visitCount: 1, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: true),
        ]
        // 09-01 and 09-03 are both active but with a gap (09-02 is inactive = not in active dates,
        // but there's no calendar-day adjacency between 09-01 and 09-03).
        let stat = InsightsStreakPresentation.streak(from: summaries)
        XCTAssertEqual(stat.longestStreakDays, 1)
        XCTAssertEqual(stat.recentStreakDays, 1)
        XCTAssertEqual(stat.activeDaysCount, 2)
    }

    // MARK: - Recent streak points to the last run

    func testRecentStreakIsLastRunNotLongest() {
        let summaries = [
            // long early streak
            DaySummary(date: "2024-01-01", visitCount: 1, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: true),
            DaySummary(date: "2024-01-02", visitCount: 1, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: true),
            DaySummary(date: "2024-01-03", visitCount: 1, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: true),
            // gap
            DaySummary(date: "2024-03-10", visitCount: 1, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: true),
        ]
        let stat = InsightsStreakPresentation.streak(from: summaries)
        XCTAssertEqual(stat.longestStreakDays, 3)
        XCTAssertEqual(stat.longestStreakStart, "2024-01-01")
        XCTAssertEqual(stat.recentStreakDays, 1)
        XCTAssertEqual(stat.recentStreakStart, "2024-03-10")
    }

    // MARK: - activeDaysCount / totalDaysCount

    func testCountsReflectAllLoadedDays() {
        let summaries = [
            DaySummary(date: "2024-05-01", visitCount: 1, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: true),
            DaySummary(date: "2024-05-02", visitCount: 0, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: false),
            DaySummary(date: "2024-05-03", visitCount: 0, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: false),
        ]
        let stat = InsightsStreakPresentation.streak(from: summaries)
        XCTAssertEqual(stat.activeDaysCount, 1)
        XCTAssertEqual(stat.totalDaysCount, 3)
    }

    // MARK: - Section hint

    func testSectionHintRequiresAtLeastTwoDays() {
        XCTAssertNotNil(InsightsStreakPresentation.sectionHint(dayCount: 1))
        XCTAssertNil(InsightsStreakPresentation.sectionHint(dayCount: 2))
        XCTAssertNil(InsightsStreakPresentation.sectionHint(dayCount: 10))
    }

    // MARK: - Unsorted input is handled gracefully

    func testUnsortedInputIsHandledGracefully() {
        let summaries = [
            DaySummary(date: "2024-10-03", visitCount: 1, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: true),
            DaySummary(date: "2024-10-01", visitCount: 1, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: true),
            DaySummary(date: "2024-10-02", visitCount: 1, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: true),
        ]
        let stat = InsightsStreakPresentation.streak(from: summaries)
        XCTAssertEqual(stat.longestStreakDays, 3)
        XCTAssertEqual(stat.longestStreakStart, "2024-10-01")
        XCTAssertEqual(stat.longestStreakEnd, "2024-10-03")
    }

    // MARK: - Empty state message

    func testNoDataMessageIsNonEmpty() {
        XCTAssertFalse(InsightsStreakPresentation.noDataMessage().isEmpty)
    }

    func testNoDataMessageWhenZeroStreakIsActionable() {
        let stat = InsightsStreakPresentation.streak(from: [])
        XCTAssertEqual(stat.longestStreakDays, 0)
        XCTAssertEqual(stat.recentStreakDays, 0)
        let message = InsightsStreakPresentation.noDataMessage()
        XCTAssertFalse(message.isEmpty, "Empty streak state must provide a non-empty message")
        XCTAssertTrue(message.lowercased().contains("streak"), "Message should mention streak")
    }
}
