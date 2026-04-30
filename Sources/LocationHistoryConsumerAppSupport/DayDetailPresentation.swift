import Foundation
import LocationHistoryConsumer

struct DayDetailMetricChipPresentation: Equatable, Identifiable {
    let icon: String
    let text: String
    let accessibilityLabel: String

    var id: String {
        "\(icon)|\(text)|\(accessibilityLabel)"
    }
}

struct DayDetailCardPresentation: Equatable {
    let title: String
    let timeRangeText: String?
    let durationText: String?
    let chips: [DayDetailMetricChipPresentation]
    let note: String?
    let intensity: Double?
}

struct DayDetailSummaryPresentation: Equatable {
    struct Item: Equatable, Identifiable {
        let icon: String
        let value: String
        let label: String

        var id: String {
            "\(icon)|\(label)|\(value)"
        }
    }

    let items: [Item]
    let footnote: String?
}

enum DayDetailSegment: String, CaseIterable, Equatable, Identifiable {
    case overview
    case timeline
    case routes
    case places

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .timeline: return "Timeline"
        case .routes: return "Routes"
        case .places: return "Places"
        }
    }
}

struct DayDetailKPIItemPresentation: Equatable, Identifiable {
    let id: String
    let icon: String
    let label: String
    let value: String
}

struct DayDetailTimelineEntryPresentation: Equatable, Identifiable {
    enum Kind: String, Equatable {
        case start
        case drive
        case visit
        case end
    }

    let id: String
    let kind: Kind
    let title: String
    let subtitle: String?
    let timeText: String?
}

enum DayDetailPresentation {
    static func kpis(detail: DayDetailViewState, unit: AppDistanceUnitPreference) -> [DayDetailKPIItemPresentation] {
        [
            .init(
                id: "distance",
                icon: "ruler",
                label: "Distance",
                value: detail.paths.reduce(0) { $0 + ($1.distanceM ?? 0) } > 0
                    ? formatDistance(detail.paths.reduce(0) { $0 + ($1.distanceM ?? 0) }, unit: unit)
                    : "0"
            ),
            .init(id: "routes", icon: "location.north.line", label: "Routes", value: "\(detail.paths.count)"),
            .init(id: "activities", icon: "figure.walk", label: "Activities", value: "\(detail.activities.count)"),
            .init(id: "places", icon: "mappin.and.ellipse", label: "Places", value: "\(detail.visits.count)")
        ]
    }

    static func segments(detail: DayDetailViewState) -> [DayDetailSegment] {
        var result: [DayDetailSegment] = [.overview, .timeline]
        if !detail.paths.isEmpty {
            result.append(.routes)
        }
        if !detail.visits.isEmpty {
            result.append(.places)
        }
        return result
    }

    static func timeline(detail: DayDetailViewState) -> [DayDetailTimelineEntryPresentation] {
        struct Event {
            let date: Date
            let kind: DayDetailTimelineEntryPresentation.Kind
            let title: String
            let subtitle: String?
            let timeText: String?
        }

        var events: [Event] = []

        let visitEvents: [Event] = detail.visits.compactMap { visit in
            guard let start = visit.startTime.flatMap(AppTimeDisplay.date(_:)) else { return nil }
            return Event(
                date: start,
                kind: .visit,
                title: "Visit",
                subtitle: displayNameForVisitType(visit.semanticType),
                timeText: AppTimeDisplay.timeRange(start: visit.startTime, end: visit.endTime)
            )
        }

        let routeEvents: [Event] = detail.paths.compactMap { path in
            guard let start = path.startTime.flatMap(AppTimeDisplay.date(_:)) else { return nil }
            return Event(
                date: start,
                kind: .drive,
                title: "Drive",
                subtitle: path.distanceM.map { formatDistance($0, unit: .metric) },
                timeText: AppTimeDisplay.timeRange(start: path.startTime, end: path.endTime)
            )
        }

        events.append(contentsOf: visitEvents)
        events.append(contentsOf: routeEvents)
        events.sort { $0.date < $1.date }

        let allStarts = (detail.visits.compactMap(\.startTime) + detail.activities.compactMap(\.startTime) + detail.paths.compactMap(\.startTime))
            .compactMap(AppTimeDisplay.date(_:))
        let allEnds = (detail.visits.compactMap(\.endTime) + detail.activities.compactMap(\.endTime) + detail.paths.compactMap(\.endTime))
            .compactMap(AppTimeDisplay.date(_:))

        var result: [DayDetailTimelineEntryPresentation] = []
        if let earliest = allStarts.min() {
            result.append(
                .init(
                    id: "start",
                    kind: .start,
                    title: "Start",
                    subtitle: nil,
                    timeText: AppTimeDisplay.time(ISO8601DateFormatter().string(from: earliest))
                )
            )
        }

        result.append(
            contentsOf: events.enumerated().map { index, event in
                .init(
                    id: "\(event.kind.rawValue)-\(index)",
                    kind: event.kind,
                    title: event.title,
                    subtitle: event.subtitle,
                    timeText: event.timeText
                )
            }
        )

        if let latest = allEnds.max() {
            result.append(
                .init(
                    id: "end",
                    kind: .end,
                    title: "End",
                    subtitle: nil,
                    timeText: AppTimeDisplay.time(ISO8601DateFormatter().string(from: latest))
                )
            )
        }

        return result
    }

    static func summary(detail: DayDetailViewState, unit: AppDistanceUnitPreference) -> DayDetailSummaryPresentation {
        var items: [DayDetailSummaryPresentation.Item] = [
            .init(icon: "mappin.and.ellipse", value: "\(detail.visits.count)", label: "Visits"),
            .init(icon: "figure.walk", value: "\(detail.activities.count)", label: "Activities"),
            .init(icon: "location.north.line", value: "\(detail.paths.count)", label: "Routes"),
        ]

        let totalDistanceM = detail.paths.reduce(0) { $0 + ($1.distanceM ?? 0) }
        if totalDistanceM > 0 {
            items.append(.init(icon: "road.lanes", value: formatDistance(totalDistanceM, unit: unit), label: "Distance"))
        }

        if let travelDuration = travelDurationText(detail: detail) {
            items.append(.init(icon: "clock", value: travelDuration, label: "Travel Time"))
        }

        let footnoteParts = [dominantModeText(detail: detail), visitContextText(detail.visits)].compactMap { $0 }
        return DayDetailSummaryPresentation(
            items: items,
            footnote: footnoteParts.isEmpty ? nil : footnoteParts.joined(separator: "  •  ")
        )
    }

    static func visitCard(for visit: DayDetailViewState.VisitItem) -> DayDetailCardPresentation {
        let isUnknownPlace = visit.semanticType?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false ||
            visit.semanticType?.uppercased() == "UNKNOWN"
        var chips: [DayDetailMetricChipPresentation] = []

        if let durationText = AppTimeDisplay.duration(start: visit.startTime, end: visit.endTime) {
            chips.append(.init(icon: "hourglass", text: durationText, accessibilityLabel: "Duration \(durationText)"))
        }
        if let accuracyM = visit.accuracyM, accuracyM.isFinite, accuracyM >= 0 {
            let accuracyText = "\(Int(accuracyM.rounded())) m accuracy"
            chips.append(.init(icon: "scope", text: accuracyText, accessibilityLabel: accuracyText))
        }

        let note: String?
        if isUnknownPlace {
            note = "No semantic place label in the export."
        } else if visit.placeID?.isEmpty == false {
            note = "Matched against an exported place record."
        } else {
            note = nil
        }

        return DayDetailCardPresentation(
            title: displayNameForVisitType(visit.semanticType),
            timeRangeText: AppTimeDisplay.timeRange(start: visit.startTime, end: visit.endTime),
            durationText: AppTimeDisplay.duration(start: visit.startTime, end: visit.endTime),
            chips: chips,
            note: note,
            intensity: visitIntensity(visit)
        )
    }

    static func activityCard(
        for activity: DayDetailViewState.ActivityItem,
        unit: AppDistanceUnitPreference
    ) -> DayDetailCardPresentation {
        var chips: [DayDetailMetricChipPresentation] = []

        if let distanceM = activity.distanceM, distanceM > 0 {
            let distanceText = formatDistance(distanceM, unit: unit)
            chips.append(.init(icon: "ruler", text: distanceText, accessibilityLabel: "Distance \(distanceText)"))
        }
        if let durationText = AppTimeDisplay.duration(start: activity.startTime, end: activity.endTime) {
            chips.append(.init(icon: "clock", text: durationText, accessibilityLabel: "Duration \(durationText)"))
        }
        if let speedText = averageSpeedText(distanceM: activity.distanceM, start: activity.startTime, end: activity.endTime, unit: unit) {
            chips.append(.init(icon: "speedometer", text: speedText, accessibilityLabel: "Average speed \(speedText)"))
        }

        let note: String?
        if activity.splitFromMidnight == true {
            note = "This activity was split at midnight in the export."
        } else {
            note = nil
        }

        return DayDetailCardPresentation(
            title: displayNameForActivityType(activity.activityType),
            timeRangeText: AppTimeDisplay.timeRange(start: activity.startTime, end: activity.endTime),
            durationText: AppTimeDisplay.duration(start: activity.startTime, end: activity.endTime),
            chips: chips,
            note: note,
            intensity: activityIntensity(activity)
        )
    }

    static func routeCard(
        for path: DayDetailViewState.PathItem,
        unit: AppDistanceUnitPreference
    ) -> DayDetailCardPresentation {
        var chips: [DayDetailMetricChipPresentation] = [
            .init(
                icon: "point.topleft.down.curvedto.point.bottomright.up",
                text: "\(path.pointCount) point\(path.pointCount == 1 ? "" : "s")",
                accessibilityLabel: "\(path.pointCount) point\(path.pointCount == 1 ? "" : "s")"
            )
        ]

        if let distanceM = path.distanceM, distanceM > 0 {
            let distanceText = formatDistance(distanceM, unit: unit)
            chips.append(.init(icon: "ruler", text: distanceText, accessibilityLabel: "Distance \(distanceText)"))
        }
        if let durationText = AppTimeDisplay.duration(start: path.startTime, end: path.endTime) {
            chips.append(.init(icon: "clock", text: durationText, accessibilityLabel: "Duration \(durationText)"))
        }

        let note: String?
        if path.distanceM == nil && AppTimeDisplay.duration(start: path.startTime, end: path.endTime) == nil {
            note = "This route only carries sampled track points."
        } else {
            note = nil
        }

        let title: String
        if let activityType = path.activityType, !activityType.isEmpty, activityType.uppercased() != "UNKNOWN" {
            title = "\(displayNameForActivityType(activityType)) Route"
        } else {
            title = "Route"
        }

        return DayDetailCardPresentation(
            title: title,
            timeRangeText: AppTimeDisplay.timeRange(start: path.startTime, end: path.endTime),
            durationText: AppTimeDisplay.duration(start: path.startTime, end: path.endTime),
            chips: chips,
            note: note,
            intensity: routeIntensity(path)
        )
    }

    static func visitsSectionSubtitle(_ visits: [DayDetailViewState.VisitItem]) -> String? {
        let durations = visits.compactMap { durationInterval(start: $0.startTime, end: $0.endTime) }
        guard !durations.isEmpty else {
            return nil
        }

        let average = durations.reduce(0, +) / Double(durations.count)
        guard let averageText = AppTimeDisplay.duration(average),
              let longestText = AppTimeDisplay.duration(durations.max() ?? 0) else {
            return nil
        }

        return "Avg stay \(averageText)  •  Longest \(longestText)"
    }

    static func activitiesSectionSubtitle(
        _ activities: [DayDetailViewState.ActivityItem],
        unit: AppDistanceUnitPreference
    ) -> String? {
        let totalDistanceM = activities.reduce(0) { $0 + ($1.distanceM ?? 0) }
        let mainMode = dominantActivityType(
            activities.map { ($0.activityType, $0.distanceM ?? 0, durationInterval(start: $0.startTime, end: $0.endTime) ?? 0) }
        )

        var parts: [String] = []
        if totalDistanceM > 0 {
            parts.append("\(formatDistance(totalDistanceM, unit: unit)) total")
        }
        if let mainMode {
            parts.append("Main mode \(displayNameForActivityType(mainMode))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: "  •  ")
    }

    static func routesSectionSubtitle(
        _ paths: [DayDetailViewState.PathItem],
        unit: AppDistanceUnitPreference
    ) -> String? {
        let totalPoints = paths.reduce(0) { $0 + $1.pointCount }
        let totalDistanceM = paths.reduce(0) { $0 + ($1.distanceM ?? 0) }
        var parts: [String] = ["\(totalPoints) point\(totalPoints == 1 ? "" : "s")"]
        if totalDistanceM > 0 {
            parts.append(formatDistance(totalDistanceM, unit: unit))
        }
        return parts.joined(separator: "  •  ")
    }

    private static func travelDurationText(detail: DayDetailViewState) -> String? {
        let activityDurations = detail.activities.compactMap { durationInterval(start: $0.startTime, end: $0.endTime) }
        if !activityDurations.isEmpty {
            return AppTimeDisplay.duration(activityDurations.reduce(0, +))
        }

        let pathDurations = detail.paths.compactMap { durationInterval(start: $0.startTime, end: $0.endTime) }
        guard !pathDurations.isEmpty else {
            return nil
        }
        return AppTimeDisplay.duration(pathDurations.reduce(0, +))
    }

    private static func dominantModeText(detail: DayDetailViewState) -> String? {
        let activityMode = dominantActivityType(
            detail.activities.map { ($0.activityType, $0.distanceM ?? 0, durationInterval(start: $0.startTime, end: $0.endTime) ?? 0) }
        )
        if let activityMode {
            return "Main mode \(displayNameForActivityType(activityMode))"
        }

        let pathMode = dominantActivityType(
            detail.paths.map { ($0.activityType, $0.distanceM ?? 0, durationInterval(start: $0.startTime, end: $0.endTime) ?? 0) }
        )
        if let pathMode {
            return "Main route \(displayNameForActivityType(pathMode))"
        }

        return nil
    }

    private static func visitContextText(_ visits: [DayDetailViewState.VisitItem]) -> String? {
        let labeledCount = visits.filter {
            let name = displayNameForVisitType($0.semanticType)
            return name != "Unknown Place"
        }.count

        guard labeledCount > 0 else {
            return nil
        }

        return "\(labeledCount) labeled place\(labeledCount == 1 ? "" : "s")"
    }

    private static func averageSpeedText(
        distanceM: Double?,
        start: String?,
        end: String?,
        unit: AppDistanceUnitPreference
    ) -> String? {
        guard let distanceM, distanceM > 0,
              let duration = durationInterval(start: start, end: end),
              duration > 0 else {
            return nil
        }

        let kmh = (distanceM / 1000) / (duration / 3600)
        guard kmh.isFinite, kmh > 0 else {
            return nil
        }

        return "Avg \(formatSpeed(kmh, unit: unit))"
    }

    private static func dominantActivityType(_ entries: [(type: String?, distance: Double, duration: TimeInterval)]) -> String? {
        var scores: [String: Double] = [:]

        for entry in entries {
            let normalized = (entry.type ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, normalized.uppercased() != "UNKNOWN" else {
                continue
            }

            let score = max(entry.distance, entry.duration)
            scores[normalized, default: 0] += max(score, 1)
        }

        return scores.max(by: { lhs, rhs in
            if lhs.value != rhs.value {
                return lhs.value < rhs.value
            }
            return lhs.key > rhs.key
        })?.key
    }

    private static func durationInterval(start: String?, end: String?) -> TimeInterval? {
        guard let startDate = start.flatMap(AppTimeDisplay.date(_:)),
              let endDate = end.flatMap(AppTimeDisplay.date(_:)),
              endDate >= startDate else {
            return nil
        }

        return endDate.timeIntervalSince(startDate)
    }

    private static func visitIntensity(_ visit: DayDetailViewState.VisitItem) -> Double? {
        guard let duration = durationInterval(start: visit.startTime, end: visit.endTime) else {
            return nil
        }
        return min(max(duration / (4 * 3600), 0.08), 1)
    }

    private static func activityIntensity(_ activity: DayDetailViewState.ActivityItem) -> Double? {
        let durationScore = (durationInterval(start: activity.startTime, end: activity.endTime) ?? 0) / 5400
        let distanceScore = (activity.distanceM ?? 0) / 10000
        let score = max(durationScore, distanceScore)
        guard score > 0 else {
            return nil
        }
        return min(max(score, 0.08), 1)
    }

    private static func routeIntensity(_ path: DayDetailViewState.PathItem) -> Double? {
        let pointScore = Double(path.pointCount) / 24
        let durationScore = (durationInterval(start: path.startTime, end: path.endTime) ?? 0) / 5400
        let distanceScore = (path.distanceM ?? 0) / 10000
        let score = max(pointScore, durationScore, distanceScore)
        guard score > 0 else {
            return nil
        }
        return min(max(score, 0.08), 1)
    }
}
