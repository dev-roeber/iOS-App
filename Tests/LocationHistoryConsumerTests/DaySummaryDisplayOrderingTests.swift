import XCTest
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class DaySummaryDisplayOrderingTests: XCTestCase {
    func testNewestFirstSortsByDateDescending() {
        let ordered = DaySummaryDisplayOrdering.newestFirst([
            DaySummary(date: "2024-05-01", visitCount: 1, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: true),
            DaySummary(date: "2024-05-03", visitCount: 0, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: false),
            DaySummary(date: "2024-05-02", visitCount: 0, activityCount: 1, pathCount: 1, totalPathPointCount: 4, totalPathDistanceM: 1200, hasContent: true),
        ])

        XCTAssertEqual(ordered.map(\.date), ["2024-05-03", "2024-05-02", "2024-05-01"])
    }

    func testNewestFirstPrefersContentWhenDatesMatch() {
        let ordered = DaySummaryDisplayOrdering.newestFirst([
            DaySummary(date: "2024-05-03", visitCount: 0, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: false),
            DaySummary(date: "2024-05-03", visitCount: 1, activityCount: 0, pathCount: 0, totalPathPointCount: 0, totalPathDistanceM: 0, hasContent: true),
        ])

        XCTAssertTrue(ordered.first?.hasContent == true)
    }
}
