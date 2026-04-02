import Foundation

/// Metadata for sharing/exporting an Insights chart as an image.
///
/// The actual image is produced in the View layer using `ImageRenderer` (iOS 16+/macOS 13+).
/// This helper is kept UI-free so it can be tested without SwiftUI.
///
/// Note: Share-sheet interaction is NOT verifiable on Linux.
/// Verify in Xcode on an Apple host before shipping.
public struct ChartSharePayload {
    /// Localized title for the share sheet.
    public var title: String
    /// Suggested filename (without path), e.g. `"LocationHistory_Insights_topDays_2026-04-01.png"`.
    public var suggestedFilename: String

    public init(title: String, suggestedFilename: String) {
        self.title = title
        self.suggestedFilename = suggestedFilename
    }
}

/// Card type identifiers matching the sections rendered in `AppInsightsContentView`.
public enum InsightsCardType: String, CaseIterable {
    case summaryCards = "summary"
    case highlights = "highlights"
    case topDays = "topDays"
    case monthlyTrend = "monthlyTrend"
    case weekdayPattern = "weekdayPattern"
    case activityBreakdown = "activityBreakdown"
    case periodBreakdown = "periodBreakdown"
    case streak = "streak"
    case periodComparison = "periodComparison"

    public var displayTitle: String {
        switch self {
        case .summaryCards: return "Summary"
        case .highlights: return "Highlights"
        case .topDays: return "Top Days"
        case .monthlyTrend: return "Monthly Trend"
        case .weekdayPattern: return "Weekday Pattern"
        case .activityBreakdown: return "Activity Breakdown"
        case .periodBreakdown: return "Period Breakdown"
        case .streak: return "Activity Streak"
        case .periodComparison: return "Period Comparison"
        }
    }
}

/// Builds share payloads for Insights chart cards.
public enum ChartShareHelper {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Creates a `ChartSharePayload` for the given card type and optional active date range.
    public static func payload(
        for cardType: InsightsCardType,
        dateRange: HistoryDateRangeFilter? = nil
    ) -> ChartSharePayload {
        let dateSuffix = dateFormatter.string(from: Date())
        let rangeLabel = rangeString(from: dateRange)
        let filename: String
        if let rangeLabel {
            filename = "LocationHistory_Insights_\(cardType.rawValue)_\(rangeLabel)_\(dateSuffix).png"
        } else {
            filename = "LocationHistory_Insights_\(cardType.rawValue)_\(dateSuffix).png"
        }

        return ChartSharePayload(
            title: localizedTitle(for: cardType),
            suggestedFilename: filename
        )
    }

    // MARK: - Private

    private static func localizedTitle(for cardType: InsightsCardType) -> String {
        "Location History – \(cardType.displayTitle)"
    }

    private static func rangeString(from filter: HistoryDateRangeFilter?) -> String? {
        guard let filter, filter.isActive else { return nil }
        switch filter.preset {
        case .last7Days: return "last7d"
        case .last30Days: return "last30d"
        case .last90Days: return "last90d"
        case .thisYear:
            let year = Calendar.current.component(.year, from: Date())
            return "\(year)"
        case .custom:
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.locale = Locale(identifier: "en_US_POSIX")
            if let start = filter.customStart, let end = filter.customEnd {
                return "\(f.string(from: start))_to_\(f.string(from: end))"
            }
            return "custom"
        case .all:
            return nil
        }
    }
}
