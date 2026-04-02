import Foundation
import LocationHistoryConsumer

enum InsightsDrilldownBridge {
    private static let isoFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func dayListAction(from action: InsightsDrilldownAction?) -> InsightsDrilldownAction? {
        guard let action else { return nil }
        switch action {
        case .filterDays, .filterDaysToDate, .filterDaysToDateRange, .showDayOnMap:
            return action
        case .prefillExportForDate, .prefillExportForDateRange:
            return nil
        }
    }

    static func exportAction(from action: InsightsDrilldownAction?) -> InsightsDrilldownAction? {
        guard let action else { return nil }
        switch action {
        case .prefillExportForDate, .prefillExportForDateRange:
            return action
        case .filterDays, .filterDaysToDate, .filterDaysToDateRange, .showDayOnMap:
            return nil
        }
    }

    static func filteredSummaries(
        _ summaries: [DaySummary],
        applying action: InsightsDrilldownAction?,
        favorites: Set<String>
    ) -> [DaySummary] {
        guard let action = dayListAction(from: action) else {
            return summaries
        }

        switch action {
        case let .filterDays(filter):
            return DayListPresentation.filteredSummaries(
                summaries,
                query: "",
                filter: filter,
                favorites: favorites
            )
        case let .filterDaysToDate(date):
            return summaries.filter { $0.date == date }
        case let .showDayOnMap(date):
            return summaries.filter { $0.date == date }
        case let .filterDaysToDateRange(fromDate, toDate):
            return summaries.filter { summary in
                summary.date >= fromDate && summary.date <= toDate
            }
        case .prefillExportForDate, .prefillExportForDateRange:
            return summaries
        }
    }

    static func prefillDates(
        for action: InsightsDrilldownAction?,
        availableDates: [String]
    ) -> Set<String> {
        guard let action = exportAction(from: action) else {
            return []
        }

        let validDates = Set(availableDates)

        switch action {
        case let .prefillExportForDate(date):
            return validDates.contains(date) ? [date] : []
        case let .prefillExportForDateRange(fromDate, toDate):
            return Set(availableDates.filter { $0 >= fromDate && $0 <= toDate })
        case .filterDays, .filterDaysToDate, .filterDaysToDateRange, .showDayOnMap:
            return []
        }
    }

    static func monthDateRange(for monthKey: String) -> (fromDate: String, toDate: String)? {
        let components = monthKey.split(separator: "-", maxSplits: 1)
        guard components.count == 2,
              let year = Int(components[0]),
              let month = Int(components[1]),
              let start = date(year: year, month: month, day: 1) else {
            return nil
        }

        var endComponents = DateComponents()
        endComponents.month = 1
        endComponents.day = -1

        let calendar = Calendar(identifier: .gregorian)
        guard let end = calendar.date(byAdding: endComponents, to: start) else {
            return nil
        }

        return (isoFormatter.string(from: start), isoFormatter.string(from: end))
    }

    static func dateRange(for item: PeriodBreakdownItem) -> (fromDate: String, toDate: String)? {
        if let month = item.month {
            return monthDateRange(for: String(format: "%04d-%02d", item.year, month))
        }

        guard let start = date(year: item.year, month: 1, day: 1),
              let end = date(year: item.year, month: 12, day: 31) else {
            return nil
        }

        return (isoFormatter.string(from: start), isoFormatter.string(from: end))
    }

    static func description(
        for action: InsightsDrilldownAction?,
        language: AppLanguagePreference
    ) -> String? {
        guard let action else { return nil }

        switch action {
        case let .filterDays(filter):
            let chips = filter.activeChips
            if chips == [.favorites] {
                return language.isGerman ? "Insights-Drilldown: Favoriten in Tage" : "Insights drilldown: favorites in Days"
            }
            if chips == [.hasRoutes] {
                return language.isGerman ? "Insights-Drilldown: Tage mit Routen" : "Insights drilldown: days with routes"
            }
            return language.isGerman ? "Insights-Drilldown in Tage aktiv" : "Insights drilldown active in Days"
        case let .filterDaysToDate(date):
            let visibleDate = localizedMediumDate(date, language: language)
            return language.isGerman
                ? "Insights-Drilldown: \(visibleDate) in Tage"
                : "Insights drilldown: \(visibleDate) in Days"
        case let .showDayOnMap(date):
            let visibleDate = localizedMediumDate(date, language: language)
            return language.isGerman
                ? "Insights-Drilldown: \(visibleDate) auf Karte"
                : "Insights drilldown: \(visibleDate) on map"
        case let .filterDaysToDateRange(fromDate, toDate):
            let label = "\(localizedMediumDate(fromDate, language: language)) – \(localizedMediumDate(toDate, language: language))"
            return language.isGerman
                ? "Insights-Drilldown: Zeitraum \(label)"
                : "Insights drilldown: range \(label)"
        case let .prefillExportForDate(date):
            let visibleDate = localizedMediumDate(date, language: language)
            return language.isGerman
                ? "Insights-Drilldown: Export für \(visibleDate)"
                : "Insights drilldown: export for \(visibleDate)"
        case let .prefillExportForDateRange(fromDate, toDate):
            let label = "\(localizedMediumDate(fromDate, language: language)) – \(localizedMediumDate(toDate, language: language))"
            return language.isGerman
                ? "Insights-Drilldown: Export für Zeitraum \(label)"
                : "Insights drilldown: export for range \(label)"
        }
    }

    private static func date(year: Int, month: Int, day: Int) -> Date? {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        return components.date
    }

    private static func localizedMediumDate(_ isoDate: String, language: AppLanguagePreference) -> String {
        guard let date = isoFormatter.date(from: isoDate) else {
            return isoDate
        }
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
