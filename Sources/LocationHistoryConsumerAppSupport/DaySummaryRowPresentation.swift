import Foundation
import LocationHistoryConsumer
#if canImport(SwiftUI)
import SwiftUI
#endif

struct DaySummaryMetricPresentation: Identifiable, Equatable {
    let id: String
    let icon: String
    let text: String
    let accessibilityLabel: String
    let tint: String?
}

struct DaySummaryStatusPresentation: Identifiable, Equatable {
    let id: String
    let text: String
    let accessibilityLabel: String
    let tint: String
}

struct DaySummaryRowPresentation: Equatable {
    let dayNumberText: String
    let weekdayText: String
    let dateText: String
    let timeRangeText: String?
    let placeText: String
    let routeText: String
    let distanceText: String?
    let metrics: [DaySummaryMetricPresentation]
    let statuses: [DaySummaryStatusPresentation]
    let accessibilityLabel: String
}

enum DaySummaryRowPresentationBuilder {
    enum Context {
        case list
        case export
    }

    static func presentation(
        for summary: DaySummary,
        unit: AppDistanceUnitPreference,
        context: Context,
        isFavorited: Bool = false,
        isExported: Bool = false,
        localize: (String) -> String = { $0 }
    ) -> DaySummaryRowPresentation {
        let dayNumberText = dayNumber(summary.date)
        let weekdayText = AppDateDisplay.weekday(summary.date)
        let dateText = AppDateDisplay.mediumDate(summary.date)
        let timeRangeText = AppTimeDisplay.timeRange(
            start: summary.firstEntryStartTime,
            end: summary.lastEntryEndTime
        )

        var metrics: [DaySummaryMetricPresentation] = []
        let visitText = "\(summary.visitCount) \(localize(summary.visitCount == 1 ? "visit" : "visits"))"
        metrics.append(
            .init(
                id: "visits",
                icon: "mappin.and.ellipse",
                text: visitText,
                accessibilityLabel: visitText,
                tint: "mint"
            )
        )
        let routeTextForMetrics = "\(summary.pathCount) \(localize(summary.pathCount == 1 ? "route" : "routes"))"
        metrics.append(
            .init(
                id: "routes",
                icon: "location.north.line",
                text: routeTextForMetrics,
                accessibilityLabel: routeTextForMetrics,
                tint: "orange"
            )
        )
        if summary.activityCount > 0 {
            let activityText = "\(summary.activityCount) \(localize(summary.activityCount == 1 ? "activity" : "activities"))"
            metrics.append(
                .init(
                    id: "activities",
                    icon: "figure.walk",
                    text: activityText,
                    accessibilityLabel: activityText,
                    tint: "blue"
                )
            )
        }

        let distanceText: String?
        if summary.totalPathDistanceM > 0 {
            let formatted = formatDistance(summary.totalPathDistanceM, unit: unit)
            distanceText = formatted
            metrics.append(
                .init(
                    id: "distance",
                    icon: "ruler",
                    text: formatted,
                    accessibilityLabel: "\(formatted) \(localize("route distance"))",
                    tint: "purple"
                )
            )
        } else {
            distanceText = nil
        }

        var statuses: [DaySummaryStatusPresentation] = []
        if isFavorited {
            let label = localize("Favorite")
            statuses.append(.init(id: "favorite", text: label, accessibilityLabel: label, tint: "yellow"))
        }
        if isExported {
            let label = localize("Exported")
            statuses.append(.init(id: "exported", text: label, accessibilityLabel: label, tint: "green"))
        }

        let routeText: String
        switch context {
        case .list:
            routeText = "\(summary.pathCount) \(localize(summary.pathCount == 1 ? "route" : "routes"))"
        case .export:
            routeText = summary.exportablePathCount > 0
                ? "\(summary.exportablePathCount) \(localize("exportable")) \(localize(summary.exportablePathCount == 1 ? "route" : "routes"))"
                : localize("No exportable routes")
        }

        let placeText = visitText
        let accessibilityParts = [dateText, weekdayText, timeRangeText, placeText, routeText, distanceText]
            .compactMap { $0 }
            + statuses.map(\.accessibilityLabel)
            + metrics.map(\.accessibilityLabel)

        return DaySummaryRowPresentation(
            dayNumberText: dayNumberText,
            weekdayText: weekdayText,
            dateText: dateText,
            timeRangeText: timeRangeText,
            placeText: placeText,
            routeText: routeText,
            distanceText: distanceText,
            metrics: metrics,
            statuses: statuses,
            accessibilityLabel: accessibilityParts.joined(separator: ", ")
        )
    }

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let gregorianCalendar: Calendar = Calendar(identifier: .gregorian)

    private static func dayNumber(_ isoDate: String) -> String {
        guard let date = dayKeyFormatter.date(from: isoDate) else {
            return String(isoDate.suffix(2))
        }
        return "\(gregorianCalendar.component(.day, from: date))"
    }
}

#if canImport(SwiftUI)
struct DaySummaryMetricChipsView: View {
    let metrics: [DaySummaryMetricPresentation]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
            ForEach(metrics) { metric in
                HStack(spacing: 6) {
                    Image(systemName: metric.icon)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(metric.text)
                        .font(.caption.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.secondary.opacity(0.08))
                .clipShape(Capsule())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(metric.accessibilityLabel)
            }
        }
    }
}

#endif
