import Foundation
import LocationHistoryConsumer

/// Streak statistics computed purely from day-level content flags.
///
/// "Recent streak" is the consecutive run of content-days ending at the last
/// active day in the visible range. "Best streak" is the longest such run.
/// Neither metric is pinned to today's date, so both remain meaningful for
/// historical exports as well as live imports.
public struct InsightsStreakStat: Equatable {
    public let longestStreakDays: Int
    public let longestStreakStart: String?  // ISO date
    public let longestStreakEnd: String?    // ISO date
    public let recentStreakDays: Int
    public let recentStreakStart: String?   // ISO date
    public let activeDaysCount: Int
    public let totalDaysCount: Int

    public init(
        longestStreakDays: Int,
        longestStreakStart: String?,
        longestStreakEnd: String?,
        recentStreakDays: Int,
        recentStreakStart: String?,
        activeDaysCount: Int,
        totalDaysCount: Int
    ) {
        self.longestStreakDays = longestStreakDays
        self.longestStreakStart = longestStreakStart
        self.longestStreakEnd = longestStreakEnd
        self.recentStreakDays = recentStreakDays
        self.recentStreakStart = recentStreakStart
        self.activeDaysCount = activeDaysCount
        self.totalDaysCount = totalDaysCount
    }
}

enum InsightsStreakPresentation {
    private static let isoDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private static var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    static func streak(from summaries: [DaySummary]) -> InsightsStreakStat {
        let activeDates = summaries
            .filter(\.hasContent)
            .compactMap { isoDateFormatter.date(from: $0.date) }
            .sorted()

        guard !activeDates.isEmpty else {
            return InsightsStreakStat(
                longestStreakDays: 0,
                longestStreakStart: nil,
                longestStreakEnd: nil,
                recentStreakDays: 0,
                recentStreakStart: nil,
                activeDaysCount: 0,
                totalDaysCount: summaries.count
            )
        }

        struct Segment { var start: Date; var end: Date; var count: Int }
        var segments: [Segment] = []
        var current = Segment(start: activeDates[0], end: activeDates[0], count: 1)

        for i in 1..<activeDates.count {
            let daysBetween = calendar.dateComponents([.day], from: activeDates[i - 1], to: activeDates[i]).day ?? 0
            if daysBetween == 1 {
                current.end = activeDates[i]
                current.count += 1
            } else {
                segments.append(current)
                current = Segment(start: activeDates[i], end: activeDates[i], count: 1)
            }
        }
        segments.append(current)

        let longest = segments.max(by: { $0.count < $1.count })!
        let last = segments.last!

        return InsightsStreakStat(
            longestStreakDays: longest.count,
            longestStreakStart: isoDateFormatter.string(from: longest.start),
            longestStreakEnd: isoDateFormatter.string(from: longest.end),
            recentStreakDays: last.count,
            recentStreakStart: isoDateFormatter.string(from: last.start),
            activeDaysCount: activeDates.count,
            totalDaysCount: summaries.count
        )
    }

    static func sectionHint(dayCount: Int) -> String? {
        dayCount < 2 ? "Need at least 2 days to compute a meaningful streak." : nil
    }

    static func noDataMessage() -> String {
        "No days with tracked activity found in the visible range."
    }
}
