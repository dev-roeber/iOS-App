#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumer
#if canImport(MapKit)
import MapKit
#endif

// MARK: - Day Detail

public struct AppDayDetailView: View {
    @EnvironmentObject private var preferences: AppPreferences
    let detail: DayDetailViewState?
    let hasDays: Bool
    let onBackToOverview: (() -> Void)?
    let liveLocation: LiveLocationFeatureModel?
    let onOpenSavedTracks: (() -> Void)?

    public init(
        detail: DayDetailViewState?,
        hasDays: Bool,
        onBackToOverview: (() -> Void)? = nil,
        liveLocation: LiveLocationFeatureModel? = nil,
        onOpenSavedTracks: (() -> Void)? = nil
    ) {
        self.detail = detail
        self.hasDays = hasDays
        self.onBackToOverview = onBackToOverview
        self.liveLocation = liveLocation
        self.onOpenSavedTracks = onOpenSavedTracks
    }

    init(detail: DayDetailViewState) {
        self.detail = detail
        self.hasDays = true
        self.onBackToOverview = nil
        self.liveLocation = nil
        self.onOpenSavedTracks = nil
    }

    public var body: some View {
        if let detail {
            if detail.hasContent {
                contentView(detail)
            } else {
                emptyDayState(
                    "Nothing Recorded",
                    message: "This day has no visits, activities or paths in the export.",
                    recovery: onBackToOverview
                )
            }
        } else if hasDays {
            emptyDayState(
                "Select a Day",
                message: "Choose a day from the list to view details."
            )
        } else {
            emptyDayState(
                "No Day Entries",
                message: "Import a file with day entries to view details."
            )
        }
    }

    @ViewBuilder
    private func contentView(_ detail: DayDetailViewState) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppDateDisplay.weekday(detail.date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(AppDateDisplay.longDate(detail.date))
                    .font(.title2.weight(.semibold))
                dayTimeRange(detail)
            }

            let dayDistance = detail.paths.reduce(0.0) { $0 + ($1.distanceM ?? 0) }
            HStack(spacing: 12) {
                quickStat("\(detail.visits.count)", label: "Visits", icon: "mappin.and.ellipse", color: .blue)
                quickStat("\(detail.activities.count)", label: "Activities", icon: "figure.walk", color: .green)
                quickStat("\(detail.paths.count)", label: "Routes", icon: "location.north.line", color: .orange)
                if dayDistance > 0 {
                    quickStat(formatDistance(dayDistance, unit: preferences.distanceUnit), label: "Distance", icon: "road.lanes", color: .purple)
                }
            }

            detailContextHeader(
                "Imported Day Data",
                message: "Map, timeline and entry cards below come from the currently imported history file."
            )

            #if canImport(MapKit)
            if #available(iOS 17.0, macOS 14.0, *) {
                AppDayMapView(mapData: DayMapDataExtractor.mapData(from: detail))
            } else {
                Label("Map view requires iOS 17 or later.", systemImage: "map")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            #endif

            DayTimelineView(detail: detail)

            if !detail.visits.isEmpty {
                detailSection("Visits", icon: "mappin.and.ellipse", count: detail.visits.count) {
                    ForEach(Array(detail.visits.enumerated()), id: \.offset) { _, visit in
                        visitCard(visit)
                    }
                }
            }

            if !detail.activities.isEmpty {
                detailSection("Activities", icon: "figure.walk", count: detail.activities.count) {
                    ForEach(Array(detail.activities.enumerated()), id: \.offset) { _, activity in
                        activityCard(activity)
                    }
                }
            }

            if !detail.paths.isEmpty {
                detailSection("Routes", icon: "location.north.line", count: detail.paths.count) {
                    ForEach(Array(detail.paths.enumerated()), id: \.offset) { _, path in
                        pathCard(path)
                    }
                }
            }

            if let liveLocation {
                detailContextHeader(
                    "Local Recording",
                    message: "Live location and saved live tracks stay separate from the imported day data above."
                )
                AppLiveLocationSection(
                    liveLocation: liveLocation,
                    onOpenSavedTracksLibrary: onOpenSavedTracks
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func detailSection<Content: View>(
        _ title: String,
        icon: String,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.headline)
                Spacer()
                Text("\(count)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(count) \(title)")
            content()
        }
    }

    @ViewBuilder
    private func detailContextHeader(_ title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func visitCard(_ visit: DayDetailViewState.VisitItem) -> some View {
        coloredCard(color: CardAccent.visit) {
            HStack(spacing: 6) {
                Image(systemName: iconForVisitType(visit.semanticType))
                    .foregroundColor(CardAccent.visit)
                    .font(.subheadline)
                Text(visit.semanticType?.capitalized ?? "Visit")
                    .font(.subheadline.weight(.medium))
            }
            if let start = visit.startTime, let end = visit.endTime {
                Label("\(AppTimeDisplay.time(start)) – \(AppTimeDisplay.time(end))", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func activityCard(_ activity: DayDetailViewState.ActivityItem) -> some View {
        coloredCard(color: CardAccent.activity) {
            HStack(spacing: 6) {
                Image(systemName: iconForActivityType(activity.activityType))
                    .foregroundColor(CardAccent.activity)
                    .font(.subheadline)
                Text(displayNameForActivityType(activity.activityType))
                    .font(.subheadline.weight(.medium))
            }
            HStack(spacing: 12) {
                if let start = activity.startTime, let end = activity.endTime {
                    Label("\(AppTimeDisplay.time(start)) – \(AppTimeDisplay.time(end))", systemImage: "clock")
                }
                if let dist = activity.distanceM {
                    Label(formatDistance(dist, unit: preferences.distanceUnit), systemImage: "ruler")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func pathCard(_ path: DayDetailViewState.PathItem) -> some View {
        coloredCard(color: CardAccent.path) {
            HStack(spacing: 6) {
                Image(systemName: iconForActivityType(path.activityType))
                    .foregroundColor(CardAccent.path)
                    .font(.subheadline)
                Text(displayNameForActivityType(path.activityType, default: "Route"))
                    .font(.subheadline.weight(.medium))
            }
            HStack(spacing: 12) {
                Label("\(path.pointCount) points", systemImage: "location.north.line")
                if let dist = path.distanceM {
                    Label(formatDistance(dist, unit: preferences.distanceUnit), systemImage: "ruler")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func quickStat(_ value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func dayTimeRange(_ detail: DayDetailViewState) -> some View {
        let allStarts = detail.visits.compactMap(\.startTime) + detail.activities.compactMap(\.startTime) + detail.paths.compactMap(\.startTime)
        let allEnds = detail.visits.compactMap(\.endTime) + detail.activities.compactMap(\.endTime) + detail.paths.compactMap(\.endTime)
        let earliest = allStarts.min()
        let latest = allEnds.max()
        if let earliest, let latest {
            Label("\(AppTimeDisplay.time(earliest)) – \(AppTimeDisplay.time(latest))", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func emptyDayState(_ title: String, message: String, recovery: (() -> Void)? = nil) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let recovery {
                Button(action: recovery) {
                    Label("Back to Overview", systemImage: "chevron.backward")
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }
}

// MARK: - Day Timeline

private struct DayTimelineView: View {
    let detail: DayDetailViewState

    private static let isoParser = ISO8601DateFormatter()

    private struct Slot: Identifiable {
        let id: Int
        let start: Date
        let end: Date
    }

    private func makeSlots(_ pairs: [(start: String?, end: String?)]) -> [Slot] {
        pairs.enumerated().compactMap { idx, pair in
            guard let s = pair.start.flatMap(Self.isoParser.date(from:)),
                  let e = pair.end.flatMap(Self.isoParser.date(from:)),
                  e > s else { return nil }
            return Slot(id: idx, start: s, end: e)
        }
    }

    private var visitSlots: [Slot] {
        makeSlots(detail.visits.map { ($0.startTime, $0.endTime) })
    }

    private var activitySlots: [Slot] {
        makeSlots(detail.activities.map { ($0.startTime, $0.endTime) })
    }

    private var bounds: (start: Date, end: Date)? {
        let all = visitSlots + activitySlots
        guard let earliest = all.map(\.start).min(),
              let latest = all.map(\.end).max(),
              latest > earliest else { return nil }
        return (earliest, latest)
    }

    private var accessibilitySummary: String {
        let from = bounds.map { AppTimeDisplay.time($0.start) } ?? ""
        let to   = bounds.map { AppTimeDisplay.time($0.end) } ?? ""
        var parts: [String] = []
        if !visitSlots.isEmpty {
            parts.append("\(visitSlots.count) visit\(visitSlots.count == 1 ? "" : "s")")
        }
        if !activitySlots.isEmpty {
            parts.append("\(activitySlots.count) \(activitySlots.count == 1 ? "activity" : "activities")")
        }
        if !from.isEmpty { parts.append("from \(from) to \(to)") }
        return "Day timeline: \(parts.joined(separator: ", "))"
    }

    var body: some View {
        if let b = bounds {
            let span = b.end.timeIntervalSince(b.start)
            VStack(alignment: .leading, spacing: 8) {
                Label("Timeline", systemImage: "clock.arrow.2.circlepath")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 6) {
                    if !visitSlots.isEmpty {
                        timelineRow(slots: visitSlots, color: CardAccent.visit, label: "Visits", bounds: b, span: span)
                    }
                    if !activitySlots.isEmpty {
                        timelineRow(slots: activitySlots, color: CardAccent.activity, label: "Activities", bounds: b, span: span)
                    }
                }
                HStack {
                    Text(AppTimeDisplay.time(b.start))
                    Spacer()
                    Text(AppTimeDisplay.time(b.end))
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            // Treat the whole Gantt chart as one accessibility element; the
            // individual coloured shapes have no standalone meaning for VoiceOver.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary)
        }
    }

    @ViewBuilder
    private func timelineRow(slots: [Slot], color: Color, label: String, bounds: (start: Date, end: Date), span: TimeInterval) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .trailing)
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    Color.clear
                    ForEach(slots) { slot in
                        let xFrac = slot.start.timeIntervalSince(bounds.start) / span
                        let wFrac = slot.end.timeIntervalSince(slot.start) / span
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color.opacity(0.75))
                            .frame(width: max(4, wFrac * geo.size.width), height: 16)
                            .offset(x: xFrac * geo.size.width)
                    }
                }
            }
            .frame(height: 16)
        }
    }
}

#endif
