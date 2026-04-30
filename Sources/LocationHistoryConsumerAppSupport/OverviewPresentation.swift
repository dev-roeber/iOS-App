import LocationHistoryConsumer
#if canImport(SwiftUI)
import SwiftUI
#endif

enum OverviewStatAccent: Equatable {
    case blue
    case purple
    case green
    case orange
}

struct OverviewStatPresentation: Identifiable, Equatable {
    let id: String
    let value: String
    let label: String
    let icon: String
    let color: OverviewStatAccent
    let note: String?
}

struct OverviewSectionPresentation: Equatable {
    let subtitle: String
    let stats: [OverviewStatPresentation]
}

enum OverviewPresentation {
    static func section(
        overview: ExportOverview,
        daySummaries: [DaySummary],
        language: AppLanguagePreference = .english
    ) -> OverviewSectionPresentation {
        let contentfulDays = daySummaries.filter(\.hasContent)
        let contentfulDayCount = contentfulDays.count
        let totalExportableRoutes = daySummaries.reduce(0) { $0 + $1.exportablePathCount }
        let totalPathPoints = daySummaries.reduce(0) { $0 + $1.totalPathPointCount }

        let subtitle: String
        if let firstDate = daySummaries.map(\.date).min(),
           let lastDate = daySummaries.map(\.date).max() {
            if language.isGerman {
                subtitle = "\(AppDateDisplay.mediumDate(firstDate)) - \(AppDateDisplay.mediumDate(lastDate)) · \(contentfulDayCount) \(contentfulDayCount == 1 ? "aktiver Tag" : "aktive Tage")"
            } else {
                subtitle = "\(AppDateDisplay.mediumDate(firstDate)) - \(AppDateDisplay.mediumDate(lastDate)) · \(contentfulDayCount) active \(contentfulDayCount == 1 ? "day" : "days")"
            }
        } else {
            subtitle = language.isGerman
                ? "Kernsummen des aktuell geladenen Exports."
                : "Core totals from the currently loaded export."
        }

        let visitsNote = averageNote(
            total: overview.totalVisitCount,
            days: contentfulDayCount,
            suffix: language.isGerman ? "pro aktivem Tag" : "per active day"
        )
        let activitiesNote = averageNote(
            total: overview.totalActivityCount,
            days: contentfulDayCount,
            suffix: language.isGerman ? "pro aktivem Tag" : "per active day"
        )
        let routesNote: String?
        if totalExportableRoutes > 0 {
            routesNote = language.isGerman
                ? "\(totalExportableRoutes) exportierbar · \(totalPathPoints) Pkt."
                : "\(totalExportableRoutes) exportable · \(totalPathPoints) pts"
        } else if overview.totalPathCount > 0 {
            routesNote = language.isGerman
                ? "\(overview.totalPathCount) erfasst, nichts exportierbar"
                : "\(overview.totalPathCount) recorded, none exportable"
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
                    note: contentfulDayCount > 0
                        ? (language.isGerman
                            ? "\(contentfulDayCount) mit erfassten Einträgen"
                            : "\(contentfulDayCount) with recorded entries")
                        : nil
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

#if canImport(SwiftUI)
extension OverviewStatAccent {
    var swiftUIColor: Color {
        switch self {
        case .blue:   return LH2GPXTheme.primaryBlue
        case .purple: return LH2GPXTheme.insightPurple
        case .green:  return LH2GPXTheme.successGreen
        case .orange: return LH2GPXTheme.warningOrange
        }
    }
}
#endif
