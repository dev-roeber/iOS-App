import Foundation
import LocationHistoryConsumer

/// A single period's aggregated stats for side-by-side comparison.
public struct InsightsPeriodComparisonItem: Equatable {
    public let label: String
    public let activeDays: Int
    public let events: Int
    public let distanceM: Double

    public init(label: String, activeDays: Int, events: Int, distanceM: Double) {
        self.label = label
        self.activeDays = activeDays
        self.events = events
        self.distanceM = distanceM
    }
}

/// Comparison of the active date range against the equal-length prior period.
public struct InsightsPeriodComparisonStat: Equatable {
    public let current: InsightsPeriodComparisonItem
    public let prior: InsightsPeriodComparisonItem

    public init(current: InsightsPeriodComparisonItem, prior: InsightsPeriodComparisonItem) {
        self.current = current
        self.prior = prior
    }
}

enum InsightsPeriodComparisonPresentation {
    private static var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    /// Returns a comparison only when `rangeFilter` is active and has a computable date range.
    /// `allSummaries` must include data outside the current range so the prior period can be populated.
    /// Returns `nil` when no range is active or the prior period cannot be derived.
    static func comparison(
        currentSummaries: [DaySummary],
        allSummaries: [DaySummary],
        rangeFilter: HistoryDateRangeFilter
    ) -> InsightsPeriodComparisonStat? {
        guard rangeFilter.isActive,
              let effectiveRange = rangeFilter.effectiveRange,
              let priorRange = priorDateRange(for: effectiveRange) else { return nil }

        guard let priorFromDate = isoFormatter.date(from: priorRange.fromDate),
              let priorToDate = isoFormatter.date(from: priorRange.toDate) else { return nil }

        let priorSummaries = allSummaries.filter {
            $0.date >= priorRange.fromDate && $0.date <= priorRange.toDate
        }

        let currentLabel = dateRangeLabel(from: effectiveRange.lowerBound, to: effectiveRange.upperBound)
        let priorLabel = dateRangeLabel(from: priorFromDate, to: priorToDate)

        return InsightsPeriodComparisonStat(
            current: aggregated(from: currentSummaries, label: currentLabel),
            prior: aggregated(from: priorSummaries, label: priorLabel)
        )
    }

    /// Returns a "+N%" / "-N%" delta string, or "–" when there is no prior data.
    static func deltaText(current: Double, prior: Double) -> String {
        guard prior > 0 else {
            return current > 0 ? "+∞" : "–"
        }
        let pct = ((current - prior) / prior) * 100
        let sign = pct >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.0f", pct))%"
    }

    /// `true` = current ≥ prior, `false` = current < prior, `nil` = no meaningful comparison.
    static func isPositiveDelta(current: Double, prior: Double) -> Bool? {
        guard prior > 0 || current > 0 else { return nil }
        return current >= prior
    }

    static func sectionHint() -> String {
        "Comparing the active date range to the equal-length period immediately before it."
    }

    static func noRangeMessage() -> String {
        "Activate a date range filter to compare the current period against the one before it."
    }

    // MARK: - Private

    private static func priorDateRange(for effectiveRange: ClosedRange<Date>) -> (fromDate: String, toDate: String)? {
        let rangeStart = calendar.startOfDay(for: effectiveRange.lowerBound)
        let rangeEnd = calendar.startOfDay(for: effectiveRange.upperBound)
        let dayCount = max(1, (calendar.dateComponents([.day], from: rangeStart, to: rangeEnd).day ?? 0) + 1)

        guard let priorEnd = calendar.date(byAdding: .day, value: -1, to: rangeStart),
              let priorStart = calendar.date(byAdding: .day, value: -(dayCount - 1), to: priorEnd) else {
            return nil
        }

        return (isoFormatter.string(from: priorStart), isoFormatter.string(from: priorEnd))
    }

    private static func aggregated(from summaries: [DaySummary], label: String) -> InsightsPeriodComparisonItem {
        InsightsPeriodComparisonItem(
            label: label,
            activeDays: summaries.filter(\.hasContent).count,
            events: summaries.reduce(0) { $0 + $1.visitCount + $1.activityCount + $1.pathCount },
            distanceM: summaries.reduce(0.0) { $0 + $1.totalPathDistanceM }
        )
    }

    private static func dateRangeLabel(from start: Date, to end: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        f.locale = Locale(identifier: "en_US_POSIX")
        return "\(f.string(from: start)) – \(f.string(from: end))"
    }
}
