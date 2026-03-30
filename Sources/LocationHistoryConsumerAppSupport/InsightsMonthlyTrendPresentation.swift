import Foundation
import LocationHistoryConsumer

enum InsightsTrendMetric: String, CaseIterable {
    case distance = "Distance"
    case events = "Events"
    case visits = "Visits"
    case routes = "Routes"
}

struct InsightsMonthlyTrendItem: Identifiable, Equatable {
    let monthKey: String
    let label: String
    let days: Int
    let visits: Int
    let activities: Int
    let routes: Int
    let distanceM: Double

    var id: String { monthKey }
    var events: Int { visits + activities + routes }
}

enum InsightsMonthlyTrendPresentation {
    static func items(
        from summaries: [DaySummary],
        locale: Locale = Locale(identifier: "en")
    ) -> [InsightsMonthlyTrendItem] {
        var grouped: [String: InsightsMonthlyTrendItem] = [:]

        for summary in summaries {
            let monthKey = String(summary.date.prefix(7))
            let existing = grouped[monthKey]
            grouped[monthKey] = InsightsMonthlyTrendItem(
                monthKey: monthKey,
                label: monthLabel(for: summary.date, locale: locale),
                days: (existing?.days ?? 0) + 1,
                visits: (existing?.visits ?? 0) + summary.visitCount,
                activities: (existing?.activities ?? 0) + summary.activityCount,
                routes: (existing?.routes ?? 0) + summary.pathCount,
                distanceM: (existing?.distanceM ?? 0) + summary.totalPathDistanceM
            )
        }

        return grouped.values.sorted { $0.monthKey < $1.monthKey }
    }

    static func availableMetrics(for items: [InsightsMonthlyTrendItem]) -> [InsightsTrendMetric] {
        var metrics: [InsightsTrendMetric] = []
        if items.contains(where: { $0.distanceM > 0 }) {
            metrics.append(.distance)
        }
        if items.contains(where: { $0.events > 0 }) {
            metrics.append(.events)
        }
        if items.contains(where: { $0.visits > 0 }) {
            metrics.append(.visits)
        }
        if items.contains(where: { $0.routes > 0 }) {
            metrics.append(.routes)
        }
        return metrics
    }

    static func value(for item: InsightsMonthlyTrendItem, metric: InsightsTrendMetric) -> Double {
        switch metric {
        case .distance:
            return item.distanceM
        case .events:
            return Double(item.events)
        case .visits:
            return Double(item.visits)
        case .routes:
            return Double(item.routes)
        }
    }

    static func summary(for item: InsightsMonthlyTrendItem, metric: InsightsTrendMetric) -> String {
        switch metric {
        case .distance:
            return "\(item.days) days · \(item.events) events"
        case .events:
            return "\(item.visits) visits · \(item.routes) routes"
        case .visits:
            return "\(item.days) days · \(item.events) events"
        case .routes:
            return "\(item.days) days · \(item.distanceM > 0 ? "distance recorded" : "no route distance")"
        }
    }

    private static func monthLabel(for isoDate: String, locale: Locale) -> String {
        AppDateDisplay.monthYear(isoDate, locale: locale)
    }
}
