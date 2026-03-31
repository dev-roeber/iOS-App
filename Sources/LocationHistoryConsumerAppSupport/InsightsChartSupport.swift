import Foundation
import LocationHistoryConsumer

enum ActivityMetric: String, CaseIterable {
    case count = "Count"
    case distance = "Distance"
}

enum InsightsWeekdayMetric: String, CaseIterable {
    case events = "Events"
    case routes = "Routes"
    case distance = "Distance"
}

enum InsightsPeriodMetric: String, CaseIterable {
    case days = "Days"
    case events = "Events"
    case distance = "Distance"
}

struct InsightsWeekdayMetricStat: Identifiable, Equatable {
    let weekday: Int
    let label: String
    let averageValue: Double
    let sampleCount: Int

    var id: Int { weekday }
}

enum InsightsOverviewState: Equatable {
    case noDays
    case sparseHistory(dayCount: Int)
    case ready

    var title: String {
        switch self {
        case .noDays:
            return "No Day Data Available"
        case let .sparseHistory(dayCount):
            return dayCount == 1 ? "Only 1 Day Loaded" : "Very Little Insight Data"
        case .ready:
            return ""
        }
    }

    var message: String {
        switch self {
        case .noDays:
            return "This export does not contain any day summaries yet, so the Insights tab has nothing meaningful to compare."
        case .sparseHistory:
            return "Comparative charts will become more useful once more days or richer exported stats are available."
        case .ready:
            return ""
        }
    }

    var systemImage: String {
        switch self {
        case .noDays:
            return "tray"
        case .sparseHistory:
            return "chart.line.text.clipboard"
        case .ready:
            return "chart.xyaxis.line"
        }
    }
}

enum InsightsChartSupport {
    static let minimumDaysForWeekdayChart = 3

    static func hasDistanceData(in daySummaries: [DaySummary]) -> Bool {
        daySummaries.contains(where: { $0.totalPathDistanceM > 0 })
    }

    static func availableActivityMetrics(for items: [ActivityBreakdownItem]) -> [ActivityMetric] {
        items.contains(where: { $0.totalDistanceKM > 0 }) ? [.count, .distance] : [.count]
    }

    static func availableWeekdayMetrics(for daySummaries: [DaySummary]) -> [InsightsWeekdayMetric] {
        var metrics: [InsightsWeekdayMetric] = []
        if daySummaries.contains(where: { ($0.visitCount + $0.activityCount + $0.pathCount) > 0 }) {
            metrics.append(.events)
        }
        if daySummaries.contains(where: { $0.pathCount > 0 }) {
            metrics.append(.routes)
        }
        if hasDistanceData(in: daySummaries) {
            metrics.append(.distance)
        }
        return metrics
    }

    static func weekdayStats(
        from daySummaries: [DaySummary],
        metric: InsightsWeekdayMetric,
        locale: Locale
    ) -> [InsightsWeekdayMetricStat] {
        guard daySummaries.count >= minimumDaysForWeekdayChart else { return [] }

        var buckets: [Int: (total: Double, count: Int)] = [:]
        for summary in daySummaries {
            guard let date = isoDateFormatter.date(from: summary.date) else { continue }
            let weekday = weekdayFor(date: date)
            let existing = buckets[weekday] ?? (total: 0, count: 0)
            buckets[weekday] = (
                total: existing.total + weekdayMetricValue(for: summary, metric: metric),
                count: existing.count + 1
            )
        }

        let order = [2, 3, 4, 5, 6, 7, 1]
        let names = weekdayNames(locale: locale)
        return order.compactMap { weekday in
            guard let bucket = buckets[weekday], bucket.count > 0 else { return nil }
            return InsightsWeekdayMetricStat(
                weekday: weekday,
                label: names[weekday] ?? "\(weekday)",
                averageValue: bucket.total / Double(bucket.count),
                sampleCount: bucket.count
            )
        }
    }

    static func weekdaySectionHint(for metric: InsightsWeekdayMetric) -> String {
        switch metric {
        case .events:
            return "Average visit and activity events per weekday across the imported days."
        case .routes:
            return "Average recorded routes per weekday across the imported days."
        case .distance:
            return "Average visible route distance per weekday, using recorded trace geometry when imported route totals are missing."
        }
    }

    static func availablePeriodMetrics(for items: [PeriodBreakdownItem]) -> [InsightsPeriodMetric] {
        var metrics: [InsightsPeriodMetric] = []
        if items.contains(where: { $0.days > 0 }) {
            metrics.append(.days)
        }
        if items.contains(where: { ($0.visits + $0.activities + $0.paths) > 0 }) {
            metrics.append(.events)
        }
        if items.contains(where: { $0.distanceM > 0 }) {
            metrics.append(.distance)
        }
        return metrics
    }

    static func periodMetricValue(for item: PeriodBreakdownItem, metric: InsightsPeriodMetric) -> Double {
        switch metric {
        case .days:
            return Double(item.days)
        case .events:
            return Double(item.visits + item.activities + item.paths)
        case .distance:
            return item.distanceM
        }
    }

    static func periodSectionHint(for metric: InsightsPeriodMetric) -> String {
        switch metric {
        case .days:
            return "Compare how many imported days contribute to each visible period."
        case .events:
            return "Compare the combined visit, activity and route volume across visible periods."
        case .distance:
            return "Compare visible route distance by period, using recorded trace geometry when imported route totals are missing."
        }
    }

    static func overviewState(
        dayCount: Int,
        hasDistanceData: Bool,
        hasActivityData: Bool,
        hasVisitData: Bool,
        hasPeriodData: Bool
    ) -> InsightsOverviewState {
        guard dayCount > 0 else {
            return .noDays
        }

        let hasMeaningfulInsightSurface = dayCount >= 2 || hasDistanceData || hasActivityData || hasVisitData || hasPeriodData
        return hasMeaningfulInsightSurface ? .ready : .sparseHistory(dayCount: dayCount)
    }

    static func distanceSectionMessage(hasDays: Bool, canNavigateToDay: Bool) -> String {
        if !hasDays {
            return "No day summaries are available for this chart."
        }
        if canNavigateToDay {
            return "Route distance with recorded-trace fallback. Tap a bar to open that day."
        }
        return "Route distance with recorded-trace fallback."
    }

    static func distanceEmptyMessage() -> String {
        "No route distance or recorded trace data is available for these days."
    }

    static func weekdaySectionMessage(dayCount: Int, bucketCount: Int) -> String? {
        guard dayCount < minimumDaysForWeekdayChart || bucketCount < 2 else {
            return nil
        }
        if dayCount < minimumDaysForWeekdayChart {
            return "Need at least 3 days before a weekday pattern is meaningful."
        }
        return "Need data across multiple weekdays before this chart becomes useful."
    }

    static func dailyAveragesSectionMessage(dayCount: Int) -> String? {
        dayCount < 2 ? "Need at least 2 days before per-day averages become useful." : nil
    }

    static func activitySectionEmptyMessage() -> String {
        "No activity totals are available for these days."
    }

    static func visitSectionEmptyMessage() -> String {
        "No semantic visit categories are available for these days."
    }

    static func periodSectionEmptyMessage() -> String {
        "This export does not include any period breakdown stats."
    }

    static func nearestDayISODate(to tappedDate: Date, in isoDates: [String]) -> String? {
        let candidates = isoDates.compactMap { iso -> (iso: String, date: Date)? in
            guard let date = isoDateFormatter.date(from: iso) else { return nil }
            return (iso, date)
        }

        return candidates.min {
            abs($0.date.timeIntervalSince(tappedDate)) < abs($1.date.timeIntervalSince(tappedDate))
        }?.iso
    }

    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static func weekdayMetricValue(for summary: DaySummary, metric: InsightsWeekdayMetric) -> Double {
        switch metric {
        case .events:
            return Double(summary.visitCount + summary.activityCount + summary.pathCount)
        case .routes:
            return Double(summary.pathCount)
        case .distance:
            return summary.totalPathDistanceM
        }
    }

    private static func weekdayFor(date: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.component(.weekday, from: date)
    }

    private static func weekdayNames(locale: Locale) -> [Int: String] {
        if locale.identifier.lowercased().hasPrefix("de") {
            return [1: "So", 2: "Mo", 3: "Di", 4: "Mi", 5: "Do", 6: "Fr", 7: "Sa"]
        }
        return [1: "Sun", 2: "Mon", 3: "Tue", 4: "Wed", 5: "Thu", 6: "Fri", 7: "Sat"]
    }
}
