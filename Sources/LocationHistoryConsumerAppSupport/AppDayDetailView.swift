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

    public init(
        detail: DayDetailViewState?,
        hasDays: Bool,
        onBackToOverview: (() -> Void)? = nil,
        liveLocation: LiveLocationFeatureModel? = nil
    ) {
        self.detail = detail
        self.hasDays = hasDays
        self.onBackToOverview = onBackToOverview
        self.liveLocation = liveLocation
    }

    init(detail: DayDetailViewState) {
        self.detail = detail
        self.hasDays = true
        self.onBackToOverview = nil
        self.liveLocation = nil
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
        let canShowLocalRecording = {
            #if canImport(MapKit)
            if #available(iOS 17.0, macOS 14.0, *) {
                return liveLocation != nil
            }
            #endif
            return false
        }()
        let hierarchy = DayDetailContentHierarchy(detail: detail, hasLiveLocationTools: canShowLocalRecording)
        let summary = DayDetailPresentation.summary(detail: detail, unit: preferences.distanceUnit)

        VStack(alignment: .leading, spacing: 24) {
            headerSection(detail, hierarchy: hierarchy)

            summarySection(summary)

            #if canImport(MapKit)
            importedMapSection(detail)
            #endif

            if hierarchy.sections.contains(.importedTimeline) {
                VStack(alignment: .leading, spacing: 10) {
                    DayDetailSectionHeaderView(
                        title: "Imported Timeline",
                        icon: "clock.arrow.2.circlepath",
                        subtitle: "Visits and activities stay ahead of local recording tools."
                    )
                    DayTimelineView(detail: detail)
                }
            }

            if hierarchy.sections.contains(.visits) {
                detailSection(
                    "Visits",
                    icon: "mappin.and.ellipse",
                    count: detail.visits.count,
                    subtitle: DayDetailPresentation.visitsSectionSubtitle(detail.visits)
                ) {
                    ForEach(Array(detail.visits.enumerated()), id: \.offset) { _, visit in
                        visitCard(visit)
                    }
                }
            }

            if hierarchy.sections.contains(.activities) {
                detailSection(
                    "Activities",
                    icon: "figure.walk",
                    count: detail.activities.count,
                    subtitle: DayDetailPresentation.activitiesSectionSubtitle(detail.activities, unit: preferences.distanceUnit)
                ) {
                    ForEach(Array(detail.activities.enumerated()), id: \.offset) { _, activity in
                        activityCard(activity)
                    }
                }
            }

            if hierarchy.sections.contains(.routes) {
                detailSection(
                    "Routes",
                    icon: "location.north.line",
                    count: detail.paths.count,
                    subtitle: DayDetailPresentation.routesSectionSubtitle(detail.paths, unit: preferences.distanceUnit)
                ) {
                    ForEach(Array(detail.paths.enumerated()), id: \.offset) { _, path in
                        pathCard(path)
                    }
                }
            }

            if hierarchy.sections.contains(.localRecording), let liveLocation {
                #if canImport(MapKit)
                if #available(iOS 17.0, macOS 14.0, *) {
                    VStack(alignment: .leading, spacing: 10) {
                        DayDetailSectionHeaderView(
                            title: "Local Recording Tools",
                            icon: "record.circle",
                            subtitle: "These tools are local-only and stay separate from the imported day history above."
                        )
                        AppLiveLocationSection(liveLocation: liveLocation)
                    }
                }
                #endif
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func headerSection(_ detail: DayDetailViewState, hierarchy: DayDetailContentHierarchy) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AppDateDisplay.weekday(detail.date))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(AppDateDisplay.longDate(detail.date))
                .font(.title2.weight(.semibold))
            if let timeRange = hierarchy.timeRange {
                Label(
                    "\(timeRange.earliest.formatted(date: .omitted, time: .shortened)) - \(timeRange.latest.formatted(date: .omitted, time: .shortened))",
                    systemImage: "clock"
                )
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            } else {
                Text("Imported day history")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func summarySection(_ summary: DayDetailSummaryPresentation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            DayDetailSectionHeaderView(
                title: "Day Summary",
                icon: "sparkles",
                subtitle: summary.footnote
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
                ForEach(summary.items) { item in
                    DayDetailSummaryMetricView(item: item)
                }
            }
        }
    }

    @ViewBuilder
    private func importedMapSection(_ detail: DayDetailViewState) -> some View {
        let mapData = DayMapDataExtractor.mapData(from: detail)
        let presentation = MapPresentation.daySection(
            detail: detail,
            mapData: mapData,
            unit: preferences.distanceUnit
        )

        VStack(alignment: .leading, spacing: 10) {
            DayDetailSectionHeaderView(
                title: "Map Context",
                icon: "map",
                subtitle: "Imported coordinates only. Local recording tools stay separate below."
            )
            if mapData.hasMapContent {
                if #available(iOS 17.0, macOS 14.0, *) {
                    AppDayMapView(mapData: mapData)
                    MapSectionSupplementaryView(presentation: presentation)
                } else {
                    Label("Map view requires iOS 17 or later.", systemImage: "map")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    MapSectionSupplementaryView(presentation: presentation)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Label("No map coordinates available for this day.", systemImage: "map")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("This day still has imported history, but none of the entries contain enough coordinates for pins or route geometry.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func detailSection<Content: View>(
        _ title: String,
        icon: String,
        count: Int,
        subtitle: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            DayDetailSectionHeaderView(
                title: title,
                icon: icon,
                count: count,
                subtitle: subtitle
            )
            content()
        }
    }

    @ViewBuilder
    private func visitCard(_ visit: DayDetailViewState.VisitItem) -> some View {
        DayDetailCardView(
            accent: CardAccent.visit,
            icon: iconForVisitType(visit.semanticType),
            presentation: DayDetailPresentation.visitCard(for: visit)
        )
    }

    @ViewBuilder
    private func activityCard(_ activity: DayDetailViewState.ActivityItem) -> some View {
        DayDetailCardView(
            accent: CardAccent.activity,
            icon: iconForActivityType(activity.activityType),
            presentation: DayDetailPresentation.activityCard(for: activity, unit: preferences.distanceUnit)
        )
    }

    @ViewBuilder
    private func pathCard(_ path: DayDetailViewState.PathItem) -> some View {
        DayDetailCardView(
            accent: CardAccent.path,
            icon: iconForActivityType(path.activityType),
            presentation: DayDetailPresentation.routeCard(for: path, unit: preferences.distanceUnit)
        )
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

private struct DayDetailSectionHeaderView: View {
    let title: String
    let icon: String
    var count: Int? = nil
    var subtitle: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: icon)
                    .font(.headline)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if let count {
                Text("\(count)")
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct DayDetailSummaryMetricView: View {
    let item: DayDetailSummaryPresentation.Item

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: item.icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(item.value)
                .font(.headline.monospacedDigit())
            Text(item.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.06))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.value) \(item.label)")
    }
}

private struct DayDetailCardView: View {
    let accent: Color
    let icon: String
    let presentation: DayDetailCardPresentation

    var body: some View {
        DayDetailCardContainer(accent: accent) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accent)
                        .frame(width: 18)
                    Text(presentation.title)
                        .font(.headline)
                    Spacer(minLength: 8)
                    if let durationText = presentation.durationText {
                        Text(durationText)
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                if presentation.timeRangeText != nil || presentation.durationText != nil {
                    DayDetailTimeContextRow(
                        timeRangeText: presentation.timeRangeText,
                        durationText: presentation.durationText
                    )
                }

                if !presentation.chips.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                        ForEach(presentation.chips) { chip in
                            DayDetailMetricChipView(chip: chip, accent: accent)
                        }
                    }
                }

                if let note = presentation.note {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let intensity = presentation.intensity {
                    DayDetailIntensityBar(accent: accent, intensity: intensity)
                }
            }
        }
    }
}

private struct DayDetailCardContainer<Content: View>: View {
    let accent: Color
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 0) {
            accent
                .frame(width: 4)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(accent.opacity(0.07))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent.opacity(0.14), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct DayDetailTimeContextRow: View {
    let timeRangeText: String?
    let durationText: String?

    var body: some View {
        HStack(spacing: 12) {
            if let timeRangeText {
                Label(timeRangeText, systemImage: "clock")
                    .lineLimit(1)
            }
            if let durationText {
                Label(durationText, systemImage: "hourglass")
                    .lineLimit(1)
            }
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
    }
}

private struct DayDetailMetricChipView: View {
    let chip: DayDetailMetricChipPresentation
    let accent: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: chip.icon)
                .font(.caption2)
                .foregroundStyle(accent)
            Text(chip.text)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(accent.opacity(0.11))
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(chip.accessibilityLabel)
    }
}

private struct DayDetailIntensityBar: View {
    let accent: Color
    let intensity: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(accent.opacity(0.12))
                Capsule()
                    .fill(accent.opacity(0.55))
                    .frame(width: max(12, geometry.size.width * min(max(intensity, 0), 1)))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
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
        let from = bounds.map { $0.start.formatted(date: .omitted, time: .shortened) } ?? ""
        let to = bounds.map { $0.end.formatted(date: .omitted, time: .shortened) } ?? ""
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
                    Text(b.start.formatted(date: .omitted, time: .shortened))
                    Spacer()
                    Text(b.end.formatted(date: .omitted, time: .shortened))
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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

#if DEBUG
private enum AppDayDetailPreviewSamples {
    static let knownVisit = detail(date: "2024-05-01", dayJSON: """
      {
        "date":"2024-05-01",
        "visits":[
          {
            "lat":52.5208,
            "lon":13.4095,
            "start_time":"2024-05-01T06:10:00Z",
            "end_time":"2024-05-01T07:15:00Z",
            "semantic_type":"HOME",
            "place_id":"fixture-home-a",
            "accuracy_m":18,
            "source_type":"placeVisit"
          }
        ],
        "activities":[],
        "paths":[]
      }
    """)

    static let unknownVisit = detail(date: "2024-05-02", dayJSON: """
      {
        "date":"2024-05-02",
        "visits":[
          {
            "lat":52.519,
            "lon":13.401,
            "start_time":"2024-05-02T09:30:00Z",
            "end_time":"2024-05-02T10:05:00Z",
            "accuracy_m":9,
            "source_type":"placeVisit"
          }
        ],
        "activities":[],
        "paths":[]
      }
    """)

    static let shortActivity = detail(date: "2024-05-03", dayJSON: """
      {
        "date":"2024-05-03",
        "visits":[],
        "activities":[
          {
            "start_time":"2024-05-03T07:15:00Z",
            "end_time":"2024-05-03T07:27:00Z",
            "activity_type":"WALKING",
            "distance_m":780,
            "split_from_midnight":false,
            "source_type":"activity"
          }
        ],
        "paths":[]
      }
    """)

    static let longActivity = detail(date: "2024-05-04", dayJSON: """
      {
        "date":"2024-05-04",
        "visits":[],
        "activities":[
          {
            "start_time":"2024-05-04T07:15:00Z",
            "end_time":"2024-05-04T07:47:00Z",
            "activity_type":"IN PASSENGER VEHICLE",
            "distance_m":29500,
            "split_from_midnight":false,
            "source_type":"activity"
          }
        ],
        "paths":[]
      }
    """)

    static let routeFewPoints = detail(date: "2024-05-05", dayJSON: """
      {
        "date":"2024-05-05",
        "visits":[],
        "activities":[],
        "paths":[
          {
            "start_time":"2024-05-05T08:00:00Z",
            "end_time":"2024-05-05T08:20:00Z",
            "activity_type":"WALKING",
            "distance_m":1400,
            "source_type":"timelinePath",
            "points":[
              {"lat":52.52,"lon":13.405,"time":"2024-05-05T08:00:00Z","accuracy_m":5},
              {"lat":52.523,"lon":13.407,"time":"2024-05-05T08:10:00Z","accuracy_m":6},
              {"lat":52.526,"lon":13.41,"time":"2024-05-05T08:20:00Z","accuracy_m":5}
            ]
          }
        ]
      }
    """)

    static let routeManyPoints = detail(date: "2024-05-06", dayJSON: """
      {
        "date":"2024-05-06",
        "visits":[],
        "activities":[],
        "paths":[
          {
            "start_time":"2024-05-06T08:00:00Z",
            "end_time":"2024-05-06T09:10:00Z",
            "activity_type":"CYCLING",
            "distance_m":18200,
            "source_type":"timelinePath",
            "points":[
              {"lat":52.52,"lon":13.405,"time":"2024-05-06T08:00:00Z","accuracy_m":5},
              {"lat":52.531,"lon":13.415,"time":"2024-05-06T08:35:00Z","accuracy_m":7},
              {"lat":52.543,"lon":13.428,"time":"2024-05-06T09:10:00Z","accuracy_m":6},
              {"lat":52.549,"lon":13.435,"time":"2024-05-06T09:18:00Z","accuracy_m":6}
            ]
          }
        ]
      }
    """)

    static let fullDay = detail(date: "2024-05-07", dayJSON: """
      {
        "date":"2024-05-07",
        "visits":[
          {
            "lat":52.5208,
            "lon":13.4095,
            "start_time":"2024-05-07T06:10:00Z",
            "end_time":"2024-05-07T07:15:00Z",
            "semantic_type":"HOME",
            "place_id":"fixture-home",
            "accuracy_m":12,
            "source_type":"placeVisit"
          },
          {
            "lat":52.5164,
            "lon":13.3777,
            "start_time":"2024-05-07T07:47:00Z",
            "end_time":"2024-05-07T09:26:00Z",
            "accuracy_m":8,
            "source_type":"placeVisit"
          }
        ],
        "activities":[
          {
            "start_time":"2024-05-07T07:15:00Z",
            "end_time":"2024-05-07T07:47:00Z",
            "activity_type":"IN PASSENGER VEHICLE",
            "distance_m":29500,
            "split_from_midnight":false,
            "source_type":"activity"
          },
          {
            "start_time":"2024-05-07T17:10:00Z",
            "end_time":"2024-05-07T17:34:00Z",
            "activity_type":"WALKING",
            "distance_m":1450,
            "split_from_midnight":false,
            "source_type":"activity"
          }
        ],
        "paths":[
          {
            "start_time":"2024-05-07T07:15:00Z",
            "end_time":"2024-05-07T07:47:00Z",
            "activity_type":"IN PASSENGER VEHICLE",
            "distance_m":30100,
            "source_type":"timelinePath",
            "points":[
              {"lat":52.5208,"lon":13.4095,"time":"2024-05-07T07:15:00Z","accuracy_m":8},
              {"lat":52.519,"lon":13.394,"time":"2024-05-07T07:30:00Z","accuracy_m":9},
              {"lat":52.5164,"lon":13.3777,"time":"2024-05-07T07:47:00Z","accuracy_m":7}
            ]
          },
          {
            "start_time":"2024-05-07T17:10:00Z",
            "end_time":"2024-05-07T17:34:00Z",
            "activity_type":"WALKING",
            "distance_m":1450,
            "source_type":"timelinePath",
            "points":[
              {"lat":52.5164,"lon":13.3777,"time":"2024-05-07T17:10:00Z","accuracy_m":5},
              {"lat":52.512,"lon":13.384,"time":"2024-05-07T17:22:00Z","accuracy_m":6},
              {"lat":52.509,"lon":13.392,"time":"2024-05-07T17:34:00Z","accuracy_m":5}
            ]
          }
        ]
      }
    """)

    private static func detail(date: String, dayJSON: String) -> DayDetailViewState {
        let json = """
        {
          "schema_version":"1.0",
          "meta":{
            "exported_at":"2024-01-01T00:00:00Z",
            "tool_version":"1.0",
            "source":{},
            "output":{},
            "config":{},
            "filters":{}
          },
          "data":{
            "days":[\(dayJSON)]
          }
        }
        """

        do {
            let export = try AppExportDecoder.decode(data: Data(json.utf8))
            if let detail = AppExportQueries.dayDetail(for: date, in: export) {
                return detail
            }
        } catch {
            assertionFailure("Failed to build preview detail: \(error)")
        }

        return AppExportQueries.dayDetail(
            for: "2024-01-01",
            in: try! AppExportDecoder.decode(
                data: Data("""
                {
                  "schema_version":"1.0",
                  "meta":{"exported_at":"2024-01-01T00:00:00Z","tool_version":"1.0","source":{},"output":{},"config":{},"filters":{}},
                  "data":{"days":[{"date":"2024-01-01","visits":[],"activities":[],"paths":[]}]}
                }
                """.utf8)
            )
        )!
    }
}

struct AppDayDetailView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            preview(AppDayDetailPreviewSamples.knownVisit, name: "Known Visit")
            preview(AppDayDetailPreviewSamples.unknownVisit, name: "Unknown Visit")
            preview(AppDayDetailPreviewSamples.shortActivity, name: "Short Activity")
            preview(AppDayDetailPreviewSamples.longActivity, name: "Long Activity")
            preview(AppDayDetailPreviewSamples.routeFewPoints, name: "Route Few Points")
            preview(AppDayDetailPreviewSamples.routeManyPoints, name: "Route Many Points")
            preview(AppDayDetailPreviewSamples.fullDay, name: "Full Day")
        }
    }

    @MainActor
    private static func preview(_ detail: DayDetailViewState, name: String) -> some View {
        ScrollView {
            AppDayDetailView(detail: detail)
                .padding()
        }
        .environmentObject(AppPreferences())
        .previewDisplayName(name)
    }
}
#endif

#endif
