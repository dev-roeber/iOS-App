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

    static func availableFilterChips(
        summaries: [DaySummary],
        favorites: Set<String>
    ) -> [DayListFilterChip] {
        DayListFilterChip.allCases.filter { chip in
            switch chip {
            case .favorites:
                return summaries.contains { favorites.contains($0.date) }
            case .hasVisits:
                return summaries.contains { $0.visitCount > 0 }
            case .hasRoutes:
                return summaries.contains { $0.pathCount > 0 }
            case .hasDistance:
                return summaries.contains { $0.totalPathDistanceM > 0 }
            case .exportable:
                return summaries.contains { $0.exportablePathCount > 0 || $0.visitCount > 0 }
            }
        }
    }

    static func filteredSummaries(
        _ summaries: [DaySummary],
        query: String,
        filter: DayListFilter = .empty,
        favorites: Set<String> = []
    ) -> [DaySummary] {
        DaySummaryDisplayOrdering.newestFirst(
            AppDaySearch.filter(summaries, query: query)
                .filter { filter.passes(summary: $0, isFavorited: favorites.contains($0.date)) }
        )
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
