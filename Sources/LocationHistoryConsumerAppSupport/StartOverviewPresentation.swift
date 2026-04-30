import Foundation
import LocationHistoryConsumer

enum HomeStartAction: Equatable {
    case importFile
    case showGoogleHelp
    case loadDemo
}

enum OverviewContinueAction: Equatable {
    case days
    case insights
    case export
    case importFile
}

struct OverviewContinueRoute: Equatable {
    let selectedTab: Int?
    let presentsExportSheet: Bool
    let callsOnOpen: Bool
}

enum StartOverviewPresentation {
    static func route(for action: OverviewContinueAction, isCompact: Bool) -> OverviewContinueRoute {
        switch action {
        case .days:
            return OverviewContinueRoute(selectedTab: isCompact ? 1 : nil, presentsExportSheet: false, callsOnOpen: false)
        case .insights:
            return OverviewContinueRoute(selectedTab: isCompact ? 2 : nil, presentsExportSheet: false, callsOnOpen: false)
        case .export:
            return OverviewContinueRoute(selectedTab: isCompact ? 3 : nil, presentsExportSheet: !isCompact, callsOnOpen: false)
        case .importFile:
            return OverviewContinueRoute(selectedTab: nil, presentsExportSheet: false, callsOnOpen: true)
        }
    }

    static func activeDayCount(in summaries: [DaySummary]) -> Int {
        summaries.filter(\.hasContent).count
    }

    static func mostActivitiesHighlight(in summaries: [DaySummary]) -> DaySummary? {
        summaries.max {
            if $0.activityCount == $1.activityCount {
                return $0.date > $1.date
            }
            return $0.activityCount < $1.activityCount
        }
    }

    static func rangeSummary(
        for filter: HistoryDateRangeFilter,
        language: AppLanguagePreference,
        locale: Locale
    ) -> String {
        if filter.preset == .all {
            return language.localized("All Time")
        }

        if filter.preset == .custom,
           let range = filter.effectiveRange {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.timeZone = .autoupdatingCurrent
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return "\(formatter.string(from: range.lowerBound)) – \(formatter.string(from: range.upperBound))"
        }

        return language.localized(filter.preset.title)
    }
}
