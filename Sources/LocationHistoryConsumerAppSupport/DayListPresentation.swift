import Foundation
import LocationHistoryConsumer

enum DayListPresentation {
    private static let isoFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    static func filteredSummaries(_ summaries: [DaySummary], query: String) -> [DaySummary] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return summaries
        }
        return summaries.filter { $0.date.localizedCaseInsensitiveContains(trimmed) }
    }

    static func reselectTargetDate(_ summaries: [DaySummary], relativeTo referenceDate: Date) -> String? {
        let contentfulSummaries = summaries.filter(\.hasContent)
        guard !contentfulSummaries.isEmpty else {
            return nil
        }

        let referenceISODate = isoFormatter.string(from: referenceDate)
        if let exactMatch = contentfulSummaries.first(where: { $0.date == referenceISODate }) {
            return exactMatch.date
        }

        if let mostRecentPastOrToday = contentfulSummaries.last(where: { $0.date < referenceISODate }) {
            return mostRecentPastOrToday.date
        }

        return contentfulSummaries.first?.date
    }

    static func exportSelectionTitle(count: Int) -> String {
        guard count > 0 else {
            return "No export days selected"
        }
        return "\(count) \(count == 1 ? "day" : "days") selected for export"
    }

    static func exportSelectionMessage(count: Int) -> String {
        guard count > 0 else {
            return "Mark days in Export and they will stay highlighted here."
        }
        return "The day list mirrors the current GPX selection so marked days stay easy to spot."
    }

    static func searchEmptyMessage(query: String, exportSelectionCount: Int) -> String {
        let base = "No days match \"\(query)\"."
        guard exportSelectionCount > 0 else {
            return "\(base) Try a broader date fragment."
        }
        return "\(base) \(exportSelectionCount) selected export \(exportSelectionCount == 1 ? "day remains" : "days remain") marked when you clear the search."
    }

    static let exportBadgeTitle = "Export"
    static let exportButtonTitle = "Open Export"
}
