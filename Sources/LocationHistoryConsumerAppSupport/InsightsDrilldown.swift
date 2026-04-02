import Foundation

/// Actions that can be triggered from a tap on an Insights chart or card.
///
/// Only actions with a clean, concrete data anchor are modeled here.
/// Purely aggregated values (e.g. raw averages without a date) do not get
/// a drilldown action to avoid misleading cross-filtering.
public enum InsightsDrilldownAction: Equatable {
    /// Filter the day list to show only days that match the given DayListFilter.
    case filterDays(DayListFilter)
    /// Filter the day list to show only the single specific date.
    case filterDaysToDate(String)
    /// Filter the day list to show days within the given ISO-8601 date string range.
    case filterDaysToDateRange(fromDate: String, toDate: String)
    /// Pre-fill the Export tab to include the given date.
    case prefillExportForDate(String)
    /// Pre-fill the Export tab to include the given ISO-8601 date string range.
    case prefillExportForDateRange(fromDate: String, toDate: String)
    /// Navigate to the day detail and focus on the map for the given date.
    /// The day-detail view renders the inline map whenever map data is available.
    case showDayOnMap(String)
}

/// A tappable drilldown target displayed in Insights cards.
public struct InsightsDrilldownTarget: Identifiable {
    public var id: UUID
    public var label: String
    public var systemImage: String
    public var action: InsightsDrilldownAction

    public init(id: UUID = UUID(), label: String, systemImage: String = "arrow.right.circle", action: InsightsDrilldownAction) {
        self.id = id
        self.label = label
        self.systemImage = systemImage
        self.action = action
    }

    // MARK: - Factory helpers

    /// Drilldown that navigates to a specific day in the day list.
    public static func showDay(_ date: String) -> InsightsDrilldownTarget {
        InsightsDrilldownTarget(
            label: "Show in Days",
            systemImage: "calendar",
            action: .filterDaysToDate(date)
        )
    }

    /// Drilldown that pre-fills the export for a specific day.
    public static func exportDay(_ date: String) -> InsightsDrilldownTarget {
        InsightsDrilldownTarget(
            label: "Export This Day",
            systemImage: "square.and.arrow.up",
            action: .prefillExportForDate(date)
        )
    }

    /// Drilldown that filters the day list to favorite days.
    public static var showFavorites: InsightsDrilldownTarget {
        InsightsDrilldownTarget(
            label: "Show Favorites",
            systemImage: "star.fill",
            action: .filterDays(DayListFilter(activeChips: [.favorites]))
        )
    }

    /// Drilldown that filters the day list to days with routes.
    public static var showDaysWithRoutes: InsightsDrilldownTarget {
        InsightsDrilldownTarget(
            label: "Days with Routes",
            systemImage: "location.north.line",
            action: .filterDays(DayListFilter(activeChips: [.hasRoutes]))
        )
    }

    /// Drilldown that navigates to a specific day's inline map view.
    ///
    /// Only meaningful when the day has spatial data (visits or routes). The day-detail
    /// view already renders an inline `AppDayMapView` when map data is present, so
    /// this reuses the existing map infrastructure without adding new map rendering.
    public static func showDayOnMap(_ date: String) -> InsightsDrilldownTarget {
        InsightsDrilldownTarget(
            label: "Show on Map",
            systemImage: "map",
            action: .showDayOnMap(date)
        )
    }

    /// Convenience triple: navigate to a date in the day list, show it on the map, or pre-fill export.
    public static func drilldownTargets(for date: String) -> [InsightsDrilldownTarget] {
        [showDay(date), showDayOnMap(date), exportDay(date)]
    }
}
