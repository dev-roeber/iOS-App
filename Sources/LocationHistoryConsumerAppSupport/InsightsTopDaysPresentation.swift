import Foundation
import LocationHistoryConsumer

enum InsightsTopDayMetric: String, CaseIterable {
    case events = "Events"
    case visits = "Visits"
    case routes = "Routes"
    case distance = "Distance"
}

enum InsightsTopDaysPresentation {
    static func availableMetrics(for summaries: [DaySummary]) -> [InsightsTopDayMetric] {
        var metrics: [InsightsTopDayMetric] = []
        if summaries.contains(where: { eventScore(for: $0) > 0 }) {
            metrics.append(.events)
        }
        if summaries.contains(where: { $0.visitCount > 0 }) {
            metrics.append(.visits)
        }
        if summaries.contains(where: { $0.pathCount > 0 }) {
            metrics.append(.routes)
        }
        if summaries.contains(where: { $0.totalPathDistanceM > 0 }) {
            metrics.append(.distance)
        }
        return metrics
    }

    static func topDays(
        from summaries: [DaySummary],
        by metric: InsightsTopDayMetric,
        limit: Int = 3
    ) -> [DaySummary] {
        summaries
            .filter(\.hasContent)
            .filter { score(for: $0, metric: metric) > 0 }
            .sorted { lhs, rhs in
                let lhsScore = score(for: lhs, metric: metric)
                let rhsScore = score(for: rhs, metric: metric)
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }

                let lhsEvents = eventScore(for: lhs)
                let rhsEvents = eventScore(for: rhs)
                if lhsEvents != rhsEvents {
                    return lhsEvents > rhsEvents
                }

                if lhs.totalPathDistanceM != rhs.totalPathDistanceM {
                    return lhs.totalPathDistanceM > rhs.totalPathDistanceM
                }

                return lhs.date > rhs.date
            }
            .prefix(limit)
            .map { $0 }
    }

    static func sectionMessage(
        metric: InsightsTopDayMetric,
        canNavigateToDay: Bool
    ) -> String {
        let basis = switch metric {
        case .events:
            "Ranked by total visits, activities and routes."
        case .visits:
            "Ranked by semantic visit count."
        case .routes:
            "Ranked by recorded route count."
        case .distance:
            "Ranked by total route distance."
        }

        if canNavigateToDay {
            return "\(basis) Tap a row to open drilldown actions for that day."
        }
        return basis
    }

    static func score(for summary: DaySummary, metric: InsightsTopDayMetric) -> Double {
        switch metric {
        case .events:
            return Double(eventScore(for: summary))
        case .visits:
            return Double(summary.visitCount)
        case .routes:
            return Double(summary.pathCount)
        case .distance:
            return summary.totalPathDistanceM
        }
    }

    private static func eventScore(for summary: DaySummary) -> Int {
        summary.visitCount + summary.activityCount + summary.pathCount
    }
}
