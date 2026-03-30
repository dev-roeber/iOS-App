import Foundation
import LocationHistoryConsumer

enum DaySummaryDisplayOrdering {
    static func newestFirst(_ summaries: [DaySummary]) -> [DaySummary] {
        summaries.sorted { lhs, rhs in
            if lhs.date != rhs.date {
                return lhs.date > rhs.date
            }
            if lhs.hasContent != rhs.hasContent {
                return lhs.hasContent && !rhs.hasContent
            }
            return lhs.totalPathDistanceM > rhs.totalPathDistanceM
        }
    }
}
