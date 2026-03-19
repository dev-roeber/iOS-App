#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumer

struct OverviewStatPresentation: Identifiable, Equatable {
    let id: String
    let value: String
    let label: String
    let icon: String
    let color: Color
    let note: String?
}

struct OverviewSectionPresentation: Equatable {
    let subtitle: String
    let stats: [OverviewStatPresentation]
}

enum OverviewPresentation {
    static func section(
        overview: ExportOverview,
        daySummaries: [DaySummary]
    ) -> OverviewSectionPresentation {
        let contentfulDays = daySummaries.filter(\.hasContent)
        let contentfulDayCount = contentfulDays.count
        let totalExportableRoutes = daySummaries.reduce(0) { $0 + $1.exportablePathCount }
        let totalPathPoints = daySummaries.reduce(0) { $0 + $1.totalPathPointCount }

        let subtitle: String
        if let firstDate = daySummaries.map(\.date).min(),
           let lastDate = daySummaries.map(\.date).max() {
            subtitle = "\(AppDateDisplay.mediumDate(firstDate)) - \(AppDateDisplay.mediumDate(lastDate)) · \(contentfulDayCount) contentful \(contentfulDayCount == 1 ? "day" : "days")"
        } else {
            subtitle = "Core totals from the currently loaded export."
        }

        let visitsNote = averageNote(
            total: overview.totalVisitCount,
            days: contentfulDayCount,
            suffix: "per contentful day"
        )
        let activitiesNote = averageNote(
            total: overview.totalActivityCount,
            days: contentfulDayCount,
            suffix: "per contentful day"
        )
        let routesNote: String?
        if totalExportableRoutes > 0 {
            routesNote = "\(totalExportableRoutes) exportable · \(totalPathPoints) pts"
        } else if overview.totalPathCount > 0 {
            routesNote = "\(overview.totalPathCount) recorded, none exportable"
        } else {
            routesNote = nil
        }

        return OverviewSectionPresentation(
            subtitle: subtitle,
            stats: [
                OverviewStatPresentation(
                    id: "days",
                    value: "\(overview.dayCount)",
                    label: "Days",
                    icon: "calendar",
                    color: .blue,
                    note: contentfulDayCount > 0 ? "\(contentfulDayCount) with recorded entries" : nil
                ),
                OverviewStatPresentation(
                    id: "visits",
                    value: "\(overview.totalVisitCount)",
                    label: "Visits",
                    icon: "mappin.and.ellipse",
                    color: .purple,
                    note: visitsNote
                ),
                OverviewStatPresentation(
                    id: "activities",
                    value: "\(overview.totalActivityCount)",
                    label: "Activities",
                    icon: "figure.walk",
                    color: .green,
                    note: activitiesNote
                ),
                OverviewStatPresentation(
                    id: "routes",
                    value: "\(overview.totalPathCount)",
                    label: "Routes",
                    icon: "location.north.line",
                    color: .orange,
                    note: routesNote
                ),
            ]
        )
    }

    private static func averageNote(total: Int, days: Int, suffix: String) -> String? {
        guard total > 0, days > 0 else {
            return nil
        }

        let average = Double(total) / Double(days)
        return String(format: "%.1f %@", average, suffix)
    }
}

#endif
