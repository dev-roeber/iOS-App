import Foundation
import LocationHistoryConsumer

enum DaySummaryDisplayOrdering {
    static func newestFirst(_ summaries: [DaySummary]) -> [DaySummary] {
        // Hot path: `AppExportQueries.projectedDays` already returns a list
        // sorted ascending by date, with at most one DaySummary per date in
        // practice. Reversing that asc-sorted list is O(n) and produces the
        // exact descending-date order we want — no second O(n log n) sort.
        // The full `sorted` fallback only kicks in for genuinely unsorted
        // input (test fixtures, future callers feeding manual arrays) or
        // when ties on date appear.
        if isMonotonicAscendingByUniqueDate(summaries) {
            return summaries.reversed()
        }
        return summaries.sorted { lhs, rhs in
            if lhs.date != rhs.date {
                return lhs.date > rhs.date
            }
            if lhs.hasContent != rhs.hasContent {
                return lhs.hasContent && !rhs.hasContent
            }
            return lhs.totalPathDistanceM > rhs.totalPathDistanceM
        }
    }

    private static func isMonotonicAscendingByUniqueDate(_ summaries: [DaySummary]) -> Bool {
        var previous: String?
        for summary in summaries {
            if let previous, summary.date <= previous { return false }
            previous = summary.date
        }
        return true
    }
}
