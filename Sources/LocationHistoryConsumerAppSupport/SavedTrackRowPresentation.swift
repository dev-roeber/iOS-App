import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

struct SavedTrackMetricPresentation: Identifiable, Equatable {
    let id: String
    let icon: String
    let text: String
    let accessibilityLabel: String
}

struct SavedTrackRowPresentation: Equatable {
    let title: String
    let timeRangeText: String?
    let metrics: [SavedTrackMetricPresentation]
    let accessibilityLabel: String
}

enum SavedTrackPresentation {
    static func row(
        for track: RecordedTrack,
        unit: AppDistanceUnitPreference,
        language: AppLanguagePreference = .english
    ) -> SavedTrackRowPresentation {
        let title = AppDateDisplay.abbreviatedDate(track.startedAt)
        let timeRange = AppTimeDisplay.timeRange(start: track.startedAt, end: track.endedAt)
        let duration = AppTimeDisplay.duration(start: track.startedAt, end: track.endedAt)

        var metrics: [SavedTrackMetricPresentation] = []
        if track.distanceM.isFinite, track.distanceM > 0 {
            let distanceText = formatDistance(track.distanceM, unit: unit)
            metrics.append(
                SavedTrackMetricPresentation(
                    id: "distance",
                    icon: "ruler",
                    text: distanceText,
                    accessibilityLabel: language.isGerman ? "\(distanceText) Strecke" : "\(distanceText) distance"
                )
            )
        }
        if let duration, !duration.isEmpty {
            metrics.append(
                SavedTrackMetricPresentation(
                    id: "duration",
                    icon: "hourglass",
                    text: duration,
                    accessibilityLabel: "\(duration) duration"
                )
            )
        }
        if track.pointCount > 0 {
            let pointText: String
            if language.isGerman {
                pointText = "\(track.pointCount) \(track.pointCount == 1 ? "Punkt" : "Punkte")"
            } else {
                pointText = "\(track.pointCount) \(track.pointCount == 1 ? "point" : "points")"
            }
            metrics.append(
                SavedTrackMetricPresentation(
                    id: "points",
                    icon: SavedTracksPresentation.libraryIcon,
                    text: pointText,
                    accessibilityLabel: pointText
                )
            )
        }

        var accessibilityParts = [title]
        if let timeRange, !timeRange.isEmpty {
            accessibilityParts.append(timeRange)
        }
        accessibilityParts.append(contentsOf: metrics.map(\.accessibilityLabel))

        return SavedTrackRowPresentation(
            title: title,
            timeRangeText: timeRange,
            metrics: metrics,
            accessibilityLabel: accessibilityParts.joined(separator: ", ")
        )
    }
}

#if canImport(SwiftUI)
struct SavedTrackSummaryContentView: View {
    let presentation: SavedTrackRowPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(presentation.title)
                .font(.subheadline.weight(.semibold))

            if let timeRangeText = presentation.timeRangeText {
                Label(timeRangeText, systemImage: "clock")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if !presentation.metrics.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                    ForEach(presentation.metrics) { metric in
                        SavedTrackMetricChipView(metric: metric)
                    }
                }
            }
        }
    }
}

private struct SavedTrackMetricChipView: View {
    let metric: SavedTrackMetricPresentation

    var body: some View {
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

#endif
