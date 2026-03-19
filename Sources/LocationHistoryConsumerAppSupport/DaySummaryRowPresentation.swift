#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumer

struct DaySummaryMetricPresentation: Identifiable, Equatable {
    let id: String
    let icon: String
    let text: String
    let accessibilityLabel: String
}

struct DaySummaryRowPresentation: Equatable {
    let weekdayText: String
    let dateText: String
    let subtitle: String
    let metrics: [DaySummaryMetricPresentation]
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
        context: Context
    ) -> DaySummaryRowPresentation {
        let weekdayText = AppDateDisplay.weekday(summary.date)
        let dateText = AppDateDisplay.mediumDate(summary.date)
        let eventCount = summary.visitCount + summary.activityCount + summary.pathCount

        var metrics: [DaySummaryMetricPresentation] = []
        let visitText = "\(summary.visitCount) \(summary.visitCount == 1 ? "visit" : "visits")"
        metrics.append(
            .init(
                id: "visits",
                icon: "mappin.and.ellipse",
                text: visitText,
                accessibilityLabel: visitText
            )
        )
        let activityText = "\(summary.activityCount) \(summary.activityCount == 1 ? "activity" : "activities")"
        metrics.append(
            .init(
                id: "activities",
                icon: "figure.walk",
                text: activityText,
                accessibilityLabel: activityText
            )
        )

        switch context {
        case .list:
            metrics.append(
                .init(
                    id: "routes",
                    icon: "location.north.line",
                    text: "\(summary.pathCount) \(summary.pathCount == 1 ? "route" : "routes")",
                    accessibilityLabel: "\(summary.pathCount) \(summary.pathCount == 1 ? "route" : "routes")"
                )
            )
        case .export:
            let routeText: String
            if summary.exportablePathCount > 0 {
                routeText = "\(summary.exportablePathCount) exportable"
            } else {
                routeText = "No exportable routes"
            }
            metrics.append(
                .init(
                    id: "routes",
                    icon: "location.north.line",
                    text: routeText,
                    accessibilityLabel: routeText
                )
            )
        }

        if summary.totalPathDistanceM > 0 {
            let distanceText = formatDistance(summary.totalPathDistanceM, unit: unit)
            metrics.append(
                .init(
                    id: "distance",
                    icon: "ruler",
                    text: distanceText,
                    accessibilityLabel: "\(distanceText) route distance"
                )
            )
        }

        let subtitle: String
        switch context {
        case .list:
            if !summary.hasContent {
                subtitle = "No recorded entries"
            } else if summary.pathCount > summary.exportablePathCount {
                let skipped = summary.pathCount - summary.exportablePathCount
                subtitle = "\(eventCount) \(eventCount == 1 ? "event" : "events") recorded. \(skipped) \(skipped == 1 ? "route drops" : "routes drop") during export cleanup."
            } else if summary.totalPathDistanceM > 0 {
                subtitle = "\(eventCount) \(eventCount == 1 ? "event" : "events") across visits, activities and routes."
            } else {
                subtitle = "\(eventCount) \(eventCount == 1 ? "event" : "events") recorded."
            }

        case .export:
            if summary.exportablePathCount > 0, summary.totalPathDistanceM > 0 {
                subtitle = "\(formatDistance(summary.totalPathDistanceM, unit: unit)) ready across \(summary.exportablePathCount) exportable \(summary.exportablePathCount == 1 ? "route" : "routes")."
            } else if summary.exportablePathCount > 0 {
                subtitle = "\(summary.exportablePathCount) \(summary.exportablePathCount == 1 ? "route is" : "routes are") ready to export."
            } else if summary.hasContent {
                subtitle = "This day has imported history, but no route geometry can be exported."
            } else {
                subtitle = "This day has no recorded content."
            }
        }

        let accessibilityParts = [dateText, subtitle] + metrics.map(\.accessibilityLabel)

        return DaySummaryRowPresentation(
            weekdayText: weekdayText,
            dateText: dateText,
            subtitle: subtitle,
            metrics: metrics,
            accessibilityLabel: accessibilityParts.joined(separator: ", ")
        )
    }
}

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
