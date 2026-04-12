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
    let mapData: DayMapData?
    let hasDays: Bool
    let onBackToOverview: (() -> Void)?
    @Binding private var exportSelection: ExportSelectionState
    let isFavorited: Bool
    let onToggleFavorite: (() -> Void)?
    let liveLocation: LiveLocationFeatureModel?
    let onOpenSavedTracks: (() -> Void)?

    public init(
        detail: DayDetailViewState?,
        mapData: DayMapData? = nil,
        hasDays: Bool,
        onBackToOverview: (() -> Void)? = nil,
        exportSelection: Binding<ExportSelectionState> = .constant(ExportSelectionState()),
        isFavorited: Bool = false,
        onToggleFavorite: (() -> Void)? = nil,
        liveLocation: LiveLocationFeatureModel? = nil,
        onOpenSavedTracks: (() -> Void)? = nil
    ) {
        self.detail = detail
        self.mapData = mapData
        self.hasDays = hasDays
        self.onBackToOverview = onBackToOverview
        self._exportSelection = exportSelection
        self.isFavorited = isFavorited
        self.onToggleFavorite = onToggleFavorite
        self.liveLocation = liveLocation
        self.onOpenSavedTracks = onOpenSavedTracks
    }

    init(detail: DayDetailViewState) {
        self.detail = detail
        self.mapData = nil
        self.hasDays = true
        self.onBackToOverview = nil
        self._exportSelection = .constant(ExportSelectionState())
        self.isFavorited = false
        self.onToggleFavorite = nil
        self.liveLocation = nil
        self.onOpenSavedTracks = nil
    }

    public var body: some View {
        if let detail {
            if detail.hasContent {
                contentView(detail)
            } else {
                emptyDayState(
                    t("Nothing Recorded"),
                    message: t("This day has no visits, activities or paths in the export."),
                    recovery: onBackToOverview
                )
            }
        } else if hasDays {
            emptyDayState(
                t("Select a Day"),
                message: t("Choose a day from the list to view details.")
            )
        } else {
            emptyDayState(
                t("No Day Entries"),
                message: t("Import a file with day entries to view details.")
            )
        }
    }

    @ViewBuilder
    private func contentView(_ detail: DayDetailViewState) -> some View {
        let resolvedMapData = mapData ?? DayMapDataExtractor.mapData(from: detail)

        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            if isLandscape {
                HStack(spacing: 0) {
                    landscapeMapColumn(detail: detail, resolvedMapData: resolvedMapData)
                        .frame(width: geometry.size.width * 0.6)
                    Divider()
                    ScrollView {
                        landscapeContentColumn(detail: detail)
                            .padding()
                    }
                    .frame(width: geometry.size.width * 0.4)
                }
            } else {
                ScrollView {
                    portraitContentView(detail: detail, resolvedMapData: resolvedMapData)
                        .padding()
                }
            }
        }
    }

    @ViewBuilder
    private func landscapeMapColumn(detail: DayDetailViewState, resolvedMapData: DayMapData) -> some View {
        VStack(spacing: 0) {
            #if canImport(MapKit)
            if #available(iOS 17.0, macOS 14.0, *) {
                if !detail.paths.isEmpty {
                    Picker(t("Route Display"), selection: $preferences.dayPathDisplayMode) {
                        ForEach(AppDayPathDisplayMode.allCases) { mode in
                            Text(t(mode.label)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                }
                AppDayMapView(mapData: resolvedMapData, fillHeight: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Label(t("Map view requires iOS 17 or later."), systemImage: "map")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            #else
            Color.secondary.opacity(0.1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            #endif
        }
    }

    @ViewBuilder
    private func landscapeContentColumn(_ detail: DayDetailViewState) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppDateDisplay.weekday(detail.date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(AppDateDisplay.longDate(detail.date))
                    .font(.title3.weight(.semibold))
                dayTimeRange(detail)
            }

            let dayDistance = detail.paths.reduce(0.0) { $0 + ($1.distanceM ?? 0) }
            HStack(spacing: 8) {
                quickStat("\(detail.visits.count)", label: t("Visits"), icon: "mappin.and.ellipse", color: .blue)
                quickStat("\(detail.activities.count)", label: t("Activities"), icon: "figure.walk", color: .green)
                quickStat("\(detail.paths.count)", label: t("Routes"), icon: "location.north.line", color: .orange)
                if dayDistance > 0 {
                    quickStat(formatDistance(dayDistance, unit: preferences.distanceUnit), label: t("Distance"), icon: "road.lanes", color: .purple)
                }
            }

            dayActionsSection(detail)

            DayTimelineView(detail: detail)

            if !detail.visits.isEmpty {
                detailSection(t("Visits"), icon: "mappin.and.ellipse", count: detail.visits.count) {
                    ForEach(Array(detail.visits.enumerated()), id: \.offset) { _, visit in
                        visitCard(visit)
                    }
                }
            }

            if !detail.activities.isEmpty {
                detailSection(t("Activities"), icon: "figure.walk", count: detail.activities.count) {
                    ForEach(Array(detail.activities.enumerated()), id: \.offset) { _, activity in
                        activityCard(activity)
                    }
                }
            }

            if !detail.paths.isEmpty {
                detailSection(t("Routes"), icon: "location.north.line", count: detail.paths.count) {
                    routeSelectionSummary(detail)
                    ForEach(Array(detail.paths.enumerated()), id: \.offset) { index, path in
                        pathCard(
                            path,
                            dayIdentifier: detail.date,
                            routeIndex: index,
                            availableRouteIndices: exportableRouteIndices(for: detail)
                        )
                    }
                }
            }

            if let liveLocation {
                detailContextHeader(
                    t("Local Recording"),
                    message: t("Live location and saved live tracks stay separate from the imported day data above.")
                )
                if #available(iOS 17.0, macOS 14.0, *) {
                    AppLiveLocationSection(
                        liveLocation: liveLocation,
                        onOpenSavedTracksLibrary: onOpenSavedTracks
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func portraitContentView(detail: DayDetailViewState, resolvedMapData: DayMapData) -> some View {
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
                quickStat("\(detail.visits.count)", label: t("Visits"), icon: "mappin.and.ellipse", color: .blue)
                quickStat("\(detail.activities.count)", label: t("Activities"), icon: "figure.walk", color: .green)
                quickStat("\(detail.paths.count)", label: t("Routes"), icon: "location.north.line", color: .orange)
                if dayDistance > 0 {
                    quickStat(formatDistance(dayDistance, unit: preferences.distanceUnit), label: t("Distance"), icon: "road.lanes", color: .purple)
                }
            }

            dayActionsSection(detail)

            detailContextHeader(
                t("Imported Day Data"),
                message: t("Map, timeline and entry cards below come from the currently imported history file.")
            )

            #if canImport(MapKit)
            if #available(iOS 17.0, macOS 14.0, *) {
                if !detail.paths.isEmpty {
                    Picker(t("Route Display"), selection: $preferences.dayPathDisplayMode) {
                        ForEach(AppDayPathDisplayMode.allCases) { mode in
                            Text(t(mode.label)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                AppDayMapView(mapData: resolvedMapData)
            } else {
                Label(t("Map view requires iOS 17 or later."), systemImage: "map")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            #endif

            DayTimelineView(detail: detail)

            if !detail.visits.isEmpty {
                detailSection(t("Visits"), icon: "mappin.and.ellipse", count: detail.visits.count) {
                    ForEach(Array(detail.visits.enumerated()), id: \.offset) { _, visit in
                        visitCard(visit)
                    }
                }
            }

            if !detail.activities.isEmpty {
                detailSection(t("Activities"), icon: "figure.walk", count: detail.activities.count) {
                    ForEach(Array(detail.activities.enumerated()), id: \.offset) { _, activity in
                        activityCard(activity)
                    }
                }
            }

            if !detail.paths.isEmpty {
                detailSection(t("Routes"), icon: "location.north.line", count: detail.paths.count) {
                    routeSelectionSummary(detail)
                    ForEach(Array(detail.paths.enumerated()), id: \.offset) { index, path in
                        pathCard(
                            path,
                            dayIdentifier: detail.date,
                            routeIndex: index,
                            availableRouteIndices: exportableRouteIndices(for: detail)
                        )
                    }
                }
            }

            if let liveLocation {
                detailContextHeader(
                    t("Local Recording"),
                    message: t("Live location and saved live tracks stay separate from the imported day data above.")
                )
                if #available(iOS 17.0, macOS 14.0, *) {
                    AppLiveLocationSection(
                        liveLocation: liveLocation,
                        onOpenSavedTracksLibrary: onOpenSavedTracks
                    )
                }
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
    private func dayActionsSection(_ detail: DayDetailViewState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("Day Actions"))
                .font(.title3.weight(.semibold))

            HStack(spacing: 10) {
                if let onToggleFavorite {
                    Button(action: onToggleFavorite) {
                        Label(
                            isFavorited ? t("Remove Favorite") : t("Add Favorite"),
                            systemImage: isFavorited ? "star.slash.fill" : "star.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(isFavorited ? .gray : .yellow)
                }

                Button {
                    exportSelection.toggle(detail.date)
                } label: {
                    Label(
                        exportSelection.isSelected(detail.date) ? t("Remove Day from Export") : t("Add Day to Export"),
                        systemImage: exportSelection.isSelected(detail.date) ? "square.and.arrow.up.fill" : "square.and.arrow.up"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            if !detail.paths.isEmpty {
                Text(routeSelectionStatus(detail))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func routeSelectionSummary(_ detail: DayDetailViewState) -> some View {
        let exportableIndices = exportableRouteIndices(for: detail)
        if exportableIndices.isEmpty {
            Label(t("No exportable routes are available for this day."), systemImage: "exclamationmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(t("Route Export"), systemImage: "line.3.horizontal.decrease.circle")
                        .font(.subheadline.weight(.medium))
                    Text(routeSelectionStatus(detail))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if exportSelection.routeSelections[detail.date] != nil {
                    Button(t("Reset to All Routes")) {
                        exportSelection.clearRouteSelection(day: detail.date)
                    }
                    .font(.caption.weight(.medium))
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func visitCard(_ visit: DayDetailViewState.VisitItem) -> some View {
        coloredCard(color: CardAccent.visit) {
            HStack(spacing: 6) {
                Image(systemName: iconForVisitType(visit.semanticType))
                    .foregroundColor(CardAccent.visit)
                    .font(.subheadline)
                Text(t(visit.semanticType?.capitalized ?? "Visit"))
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
                Text(displayNameForActivityType(activity.activityType, language: preferences.appLanguage))
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
    private func pathCard(
        _ path: DayDetailViewState.PathItem,
        dayIdentifier: String,
        routeIndex: Int,
        availableRouteIndices: Set<Int>
    ) -> some View {
        let isExportable = availableRouteIndices.contains(routeIndex)
        let hasExplicitSelection = exportSelection.routeSelections[dayIdentifier] != nil
        let isSelected = isExportable && exportSelection.isRouteSelected(day: dayIdentifier, routeIndex: routeIndex)

        coloredCard(color: CardAccent.path) {
            HStack(alignment: .top, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: iconForActivityType(path.activityType))
                        .foregroundColor(CardAccent.path)
                        .font(.subheadline)
                    Text(displayNameForActivityType(path.activityType, default: t("Route"), language: preferences.appLanguage))
                        .font(.subheadline.weight(.medium))
                }
                Spacer()
                if isExportable {
                    Button {
                        if !exportSelection.isSelected(dayIdentifier) {
                            exportSelection.toggle(dayIdentifier)
                        }
                        exportSelection.toggleRoute(
                            day: dayIdentifier,
                            routeIndex: routeIndex,
                            availableRouteIndices: availableRouteIndices
                        )
                    } label: {
                        Label(
                            routeSelectionLabel(isSelected: isSelected, hasExplicitSelection: hasExplicitSelection),
                            systemImage: isSelected ? "checkmark.circle.fill" : "circle"
                        )
                        .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .accessibilityLabel(routeSelectionLabel(isSelected: isSelected, hasExplicitSelection: hasExplicitSelection))
                } else {
                    Image(systemName: "slash.circle")
                        .foregroundStyle(.tertiary)
                        .accessibilityLabel(t("Route unavailable for export"))
                }
            }
            HStack(spacing: 12) {
                Label(pointCountText(path.pointCount), systemImage: "location.north.line")
                if let dist = path.distanceM {
                    Label(formatDistance(dist, unit: preferences.distanceUnit), systemImage: "ruler")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if isExportable {
                Text(routeSelectionHint(isSelected: isSelected, hasExplicitSelection: hasExplicitSelection))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text(t("This route has no exportable geometry."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
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
                .minimumScaleFactor(0.7)
                .lineLimit(1)
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
                    Label(t("Back to Overview"), systemImage: "chevron.backward")
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }

    private func pointCountText(_ count: Int) -> String {
        preferences.appLanguage.isGerman
            ? "\(count) \(count == 1 ? "Punkt" : "Punkte")"
            : "\(count) \(count == 1 ? "point" : "points")"
    }

    private func exportableRouteIndices(for detail: DayDetailViewState) -> Set<Int> {
        Set(
            detail.paths.enumerated().compactMap { index, path in
                let rawPath = Path(
                    startTime: path.startTime,
                    endTime: path.endTime,
                    activityType: path.activityType,
                    distanceM: path.distanceM,
                    sourceType: "day_detail",
                    points: path.points.map {
                        PathPoint(
                            lat: $0.lat,
                            lon: $0.lon,
                            time: $0.time,
                            accuracyM: $0.accuracyM
                        )
                    },
                    flatCoordinates: nil
                )
                return ExportRouteSanitizer.sanitizedPath(rawPath) == nil ? nil : index
            }
        )
    }

    private func routeSelectionStatus(_ detail: DayDetailViewState) -> String {
        let exportableIndices = exportableRouteIndices(for: detail)
        guard !exportableIndices.isEmpty else {
            return t("No exportable routes are available for this day.")
        }

        if let explicitSelection = exportSelection.routeSelections[detail.date] {
            let selectedCount = explicitSelection.intersection(exportableIndices).count
            if preferences.appLanguage.isGerman {
                return "\(selectedCount) von \(exportableIndices.count) exportierbaren \(exportableIndices.count == 1 ? "Route" : "Routen") ausgewählt. Besuche und Aktivitäten bleiben vom Exportmodus abhängig."
            }
            return "\(selectedCount) of \(exportableIndices.count) exportable route\(exportableIndices.count == 1 ? "" : "s") selected. Visits and activities still follow the export mode."
        }

        if preferences.appLanguage.isGerman {
            return "Standardmäßig sind alle \(exportableIndices.count) exportierbaren \(exportableIndices.count == 1 ? "Route" : "Routen") enthalten. Tippe auf eine Route, um auf eine benutzerdefinierte Auswahl umzuschalten."
        }
        return "All \(exportableIndices.count) exportable route\(exportableIndices.count == 1 ? "" : "s") are included by default. Tap a route to switch to a custom subset."
    }

    private func routeSelectionLabel(isSelected: Bool, hasExplicitSelection: Bool) -> String {
        if preferences.appLanguage.isGerman {
            if hasExplicitSelection {
                return isSelected ? "Für den Export ausgewählt" : "Nicht für den Export ausgewählt"
            }
            return "Standardmäßig im Export enthalten"
        }
        if hasExplicitSelection {
            return isSelected ? "Selected for export" : "Not selected for export"
        }
        return "Included by default"
    }

    private func routeSelectionHint(isSelected: Bool, hasExplicitSelection: Bool) -> String {
        if preferences.appLanguage.isGerman {
            if hasExplicitSelection {
                return isSelected ? "Tippe, um diese Route aus der Exportauswahl zu entfernen." : "Tippe, um diese Route zur Exportauswahl hinzuzufügen."
            }
            return "Tippe, um eine benutzerdefinierte Routenauswahl für diesen Tag zu starten."
        }
        if hasExplicitSelection {
            return isSelected ? "Tap to remove this route from the export subset." : "Tap to add this route to the export subset."
        }
        return "Tap to start a custom route subset for this day."
    }
}

// MARK: - Day Timeline

private struct DayTimelineView: View {
    @EnvironmentObject private var preferences: AppPreferences
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
            parts.append(countedText(visitSlots.count, englishSingular: "visit", englishPlural: "visits", germanSingular: "Besuch", germanPlural: "Besuche"))
        }
        if !activitySlots.isEmpty {
            parts.append(countedText(activitySlots.count, englishSingular: "activity", englishPlural: "activities", germanSingular: "Aktivität", germanPlural: "Aktivitäten"))
        }
        if !from.isEmpty {
            parts.append(preferences.appLanguage.isGerman ? "von \(from) bis \(to)" : "from \(from) to \(to)")
        }
        return preferences.appLanguage.isGerman
            ? "Tageszeitachse: \(parts.joined(separator: ", "))"
            : "Day timeline: \(parts.joined(separator: ", "))"
    }

    var body: some View {
        if let b = bounds {
            let span = b.end.timeIntervalSince(b.start)
            VStack(alignment: .leading, spacing: 8) {
                Label(t("Timeline"), systemImage: "clock.arrow.2.circlepath")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 6) {
                    if !visitSlots.isEmpty {
                        timelineRow(slots: visitSlots, color: CardAccent.visit, label: t("Visits"), bounds: b, span: span)
                    }
                    if !activitySlots.isEmpty {
                        timelineRow(slots: activitySlots, color: CardAccent.activity, label: t("Activities"), bounds: b, span: span)
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

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }

    private func countedText(_ count: Int, englishSingular: String, englishPlural: String, germanSingular: String, germanPlural: String) -> String {
        if preferences.appLanguage.isGerman {
            return "\(count) \(count == 1 ? germanSingular : germanPlural)"
        }
        return "\(count) \(count == 1 ? englishSingular : englishPlural)"
    }
}

#endif
