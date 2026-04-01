import Foundation
import LocationHistoryConsumer

public enum AppDaySearch {
    public static func filter(_ summaries: [DaySummary], query: String) -> [DaySummary] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return summaries
        }

        return summaries.filter { matches($0, query: trimmedQuery) }
    }

    public static func matches(_ summary: DaySummary, query: String) -> Bool {
        let normalizedQuery = normalize(query)
        return searchableTerms(for: summary).contains { normalize($0).contains(normalizedQuery) }
    }

    private static func searchableTerms(for summary: DaySummary) -> [String] {
        [
            summary.date,
            AppDateDisplay.mediumDate(summary.date),
            AppDateDisplay.longDate(summary.date),
            AppDateDisplay.weekday(summary.date),
            AppDateDisplay.monthYear(summary.date)
        ]
    }

    private static func normalize(_ string: String) -> String {
        string
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
