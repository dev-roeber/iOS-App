import Foundation
import LocationHistoryConsumer
#if canImport(SwiftUI)
import SwiftUI
#endif

struct RecordedTrackEditorMetricPresentation: Identifiable, Equatable {
    let id: String
    let icon: String
    let text: String
    let accessibilityLabel: String
}

struct RecordedTrackEditorSummaryPresentation: Equatable {
    let title: String
    let timeRangeText: String?
    let metrics: [RecordedTrackEditorMetricPresentation]
    let note: String
    let validationMessage: String?
}

struct RecordedTrackPointPresentation: Equatable {
    let title: String
    let roleLabel: String?
    let timeText: String
    let coordinateText: String
    let metrics: [RecordedTrackEditorMetricPresentation]
}

enum RecordedTrackEditorPresentation {
    static func summary(
        draft: RecordedTrackEditorDraft,
        unit: AppDistanceUnitPreference
    ) -> RecordedTrackEditorSummaryPresentation {
        var metrics: [RecordedTrackEditorMetricPresentation] = []
        let pointText = "\(draft.pointCount) \(draft.pointCount == 1 ? "point" : "points")"
        metrics.append(
            .init(
                id: "points",
                icon: SavedTracksPresentation.libraryIcon,
                text: pointText,
                accessibilityLabel: pointText
            )
        )

        let distanceText = formatDistance(draft.distanceM, unit: unit)
        metrics.append(
            .init(
                id: "distance",
                icon: "ruler",
                text: distanceText,
                accessibilityLabel: "\(distanceText) distance"
            )
        )

        if let duration = AppTimeDisplay.duration(start: draft.startedAt, end: draft.endedAt) {
            metrics.append(
                .init(
                    id: "duration",
                    icon: "hourglass",
                    text: duration,
                    accessibilityLabel: "\(duration) duration"
                )
            )
        }

        return RecordedTrackEditorSummaryPresentation(
            title: AppDateDisplay.longDate(draft.dayKey),
            timeRangeText: AppTimeDisplay.timeRange(start: draft.startedAt, end: draft.endedAt),
            metrics: metrics,
            note: "This saved track is local-only and remains separate from imported history.",
            validationMessage: draft.validationMessage
        )
    }

    static func point(
        at index: Int,
        in draft: RecordedTrackEditorDraft,
        unit: AppDistanceUnitPreference
    ) -> RecordedTrackPointPresentation {
        let point = draft.points[index]
        let title: String
        let roleLabel: String?

        if draft.points.count == 1 {
            title = "Only Point"
            roleLabel = "Single-point track"
        } else if index == 0 {
            title = "Start Point"
            roleLabel = "Track begins here"
        } else if index == draft.points.count - 1 {
            title = "End Point"
            roleLabel = "Track ends here"
        } else {
            title = "Point \(index + 1)"
            roleLabel = nil
        }

        var metrics: [RecordedTrackEditorMetricPresentation] = []
        let accuracyText = "\(Int(point.horizontalAccuracyM.rounded())) m accuracy"
        metrics.append(
            .init(
                id: "accuracy",
                icon: "scope",
                text: accuracyText,
                accessibilityLabel: accuracyText
            )
        )

        if let segmentDistance = segmentDistanceText(at: index, in: draft, unit: unit) {
            metrics.append(
                .init(
                    id: index == 0 ? "next-segment" : "prev-segment",
                    icon: "arrow.left.and.right",
                    text: segmentDistance,
                    accessibilityLabel: segmentDistance
                )
            )
        }

        return RecordedTrackPointPresentation(
            title: title,
            roleLabel: roleLabel,
            timeText: AppTimeDisplay.time(point.timestamp),
            coordinateText: coordinateText(for: point),
            metrics: metrics
        )
    }

    private static func coordinateText(for point: RecordedTrackPoint) -> String {
        "\(String(format: "%.5f", point.latitude)), \(String(format: "%.5f", point.longitude))"
    }

    private static func segmentDistanceText(
        at index: Int,
        in draft: RecordedTrackEditorDraft,
        unit: AppDistanceUnitPreference
    ) -> String? {
        if index > 0 {
            let previous = draft.points[index - 1]
            let current = draft.points[index]
            let a = LocationCoordinate2D(latitude: previous.latitude, longitude: previous.longitude)
            let b = LocationCoordinate2D(latitude: current.latitude, longitude: current.longitude)
            let meters = a.distance(to: b)
            return "\(formatDistance(meters, unit: unit)) from previous"
        }

        guard draft.points.count > 1 else {
            return nil
        }

        let current = draft.points[index]
        let next = draft.points[index + 1]
        let a = LocationCoordinate2D(latitude: current.latitude, longitude: current.longitude)
        let b = LocationCoordinate2D(latitude: next.latitude, longitude: next.longitude)
        let meters = a.distance(to: b)
        return "\(formatDistance(meters, unit: unit)) to next"
    }
}

#if canImport(SwiftUI)
struct RecordedTrackEditorMetricChipsView: View {
    let metrics: [RecordedTrackEditorMetricPresentation]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
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
