#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumer
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

private enum ExportAccuracyFilterOption: String, Identifiable, CaseIterable {
    case any  = "Any Accuracy"
    case m25  = "25 m"
    case m50  = "50 m"
    case m100 = "100 m"

    var id: String { rawValue }

    var maxAccuracyM: Double? {
        switch self {
        case .any:  return nil
        case .m25:  return 25
        case .m50:  return 50
        case .m100: return 100
        }
    }
}

private enum ExportAreaFilterOption: String, Identifiable, CaseIterable {
    case none    = "No Area Filter"
    case bounds  = "Rectangle"
    case polygon = "Custom Shape"

    var id: String { rawValue }
}

public struct AppExportView: View {
    @Environment(\.dismiss) private var dismiss
    private struct ImportedSelectionPruneTrigger: Equatable {
        let fromDate: String
        let toDate: String
        let accuracyFilter: ExportAccuracyFilterOption
        let requiredContent: Set<AppExportContentRequirement>
        let activityTypes: Set<String>
        let areaFilter: ExportAreaFilterOption
        let boundsMinLat: String
        let boundsMaxLat: String
        let boundsMinLon: String
        let boundsMaxLon: String
        let polygonCoordinatesText: String
        let rangeFilter: HistoryDateRangeFilter
    }

    @EnvironmentObject private var preferences: AppPreferences
    @Binding var session: AppSessionState
    @ObservedObject private var liveLocation: LiveLocationFeatureModel
    private let onOpenImport: (() -> Void)?
    private let onOpenDays: (() -> Void)?
    @State private var selectedFormat: ExportFormat = .gpx
    @State private var selectedMode: ExportMode = .tracks
    @State private var selectedFromDate: String = ""
    @State private var selectedToDate: String = ""
    @State private var selectedAccuracyFilter: ExportAccuracyFilterOption = .any
    @State private var selectedContentRequirements: Set<AppExportContentRequirement> = []
    @State private var selectedActivityTypes: Set<String> = []
    @State private var selectedAreaFilter: ExportAreaFilterOption = .none
    @State private var boundsMinLat: String = ""
    @State private var boundsMaxLat: String = ""
    @State private var boundsMinLon: String = ""
    @State private var boundsMaxLon: String = ""
    @State private var polygonCoordinatesText: String = ""
    @State private var isExporting = false
    @State private var exportDocument: ExportDocument?
    @State private var kmzExportDocument: KMZExportDocument?
    @State private var isExportingKMZ = false
    @State private var exportError: String?
    #if canImport(UniformTypeIdentifiers)
    @State private var exportContentType: UTType = .gpx
    #endif
    @State private var exportMapHeaderState = LHMapHeaderState(
        visibility: .compact,
        compactHeight: LHHeroMapLayout.compactHeight,
        expandedHeight: LHHeroMapLayout.expandedHeight,
        isSticky: true
    )
    private let heroEnabled: Bool

    public init(
        session: Binding<AppSessionState>,
        liveLocation: LiveLocationFeatureModel,
        onOpenImport: (() -> Void)? = nil,
        onOpenDays: (() -> Void)? = nil,
        heroEnabled: Bool = false
    ) {
        self._session      = session
        self._liveLocation = ObservedObject(wrappedValue: liveLocation)
        self.onOpenImport  = onOpenImport
        self.onOpenDays    = onOpenDays
        self.heroEnabled   = heroEnabled
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }

    private func tf(_ englishFormat: String, _ arguments: CVarArg...) -> String {
        preferences.localized(format: englishFormat, arguments: arguments)
    }

    private var effectiveExportMode: ExportMode {
        selectedFormat == .csv ? .both : selectedMode
    }

    // MARK: - Body

    public var body: some View {
        if session.daySummaries.isEmpty && liveLocation.recordedTracks.isEmpty {
            emptyState
        } else {
            exportContent(summaries: filteredSummaries)
        }
    }

    @ViewBuilder
    private func exportContent(summaries: [DaySummary]) -> some View {
        let selection = session.exportSelection
        exportContentObservers(summaries: summaries) {
            checkoutLayout(selection: selection, summaries: summaries)
        }
    }

    // MARK: - Checkout Layout

    @ViewBuilder
    private func checkoutLayout(selection: ExportSelectionState, summaries: [DaySummary]) -> some View {
        if heroEnabled {
            ScrollViewReader { proxy in
                ScrollView {
                    LHPageScaffold(spacing: 14) {
                        checkoutScrollContent(selection: selection, summaries: summaries, proxy: proxy)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    exportHeroMap(selection: selection, summaries: summaries)
                    exportHeroFilterPanel(selection: selection, summaries: summaries)
                }
                .background(Color.black)
            }
            .safeAreaInset(edge: .bottom) {
                bottomBar(selection: selection, summaries: summaries)
            }
            .ignoresSafeArea(edges: .top)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LHPageScaffold(spacing: 14) {
                        checkoutScrollContent(selection: selection, summaries: summaries, proxy: proxy)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomBar(selection: selection, summaries: summaries)
            }
        }
    }

    @ViewBuilder
    private func checkoutScrollContent(
        selection: ExportSelectionState,
        summaries: [DaySummary],
        proxy: ScrollViewProxy
    ) -> some View {
        titleHeaderSection
            .accessibilityIdentifier("export.title")

        if insightsExportDrilldownDescription != nil {
            insightsDrilldownCard
        }

        if hasImportedExport {
            rangeFilterCard
                .accessibilityIdentifier("export.range.card")
        }

        selectionSummaryCard(selection: selection, summaries: summaries, proxy: proxy)
            .accessibilityIdentifier("export.selection.card")

        previewCard(selection: selection, summaries: summaries)

        if !summaries.isEmpty {
            daysCard(summaries: summaries, selection: selection)
                .id("export.days.section")
        }

        if !liveLocation.recordedTracks.isEmpty {
            liveTracksCard(selection: selection)
                .accessibilityIdentifier("export.liveTracks.card")
        }

        formatCard
            .accessibilityIdentifier("export.format.card")

        if selectedFormat == .csv {
            csvNoteCard
        } else {
            contentCard
                .accessibilityIdentifier("export.content.card")
        }

        exportTargetCard

        if hasImportedExport {
            LHExportFilterDisclosure(
                title: t("Advanced Filters"),
                isActive: !activeFilterDescriptions.isEmpty,
                startsExpanded: !activeFilterDescriptions.isEmpty
            ) {
                filterContent
            }
        }
    }

    // MARK: - Hero Map (compact width)

    @ViewBuilder
    private func exportHeroMap(selection: ExportSelectionState, summaries: [DaySummary]) -> some View {
        let previewData = ExportPreviewDataBuilder.previewData(
            importedExport: session.content?.export,
            selection: selection,
            recordedTracks: liveLocation.recordedTracks,
            queryFilter: effectiveQueryFilter,
            mode: effectiveExportMode
        )

        LHCollapsibleMapHeader(
            state: $exportMapHeaderState,
            language: preferences.appLanguage,
            overlayControls: true,
            safeAreaTopInset: lhDeviceTopSafeInset()
        ) {
            if previewData.hasMapContent {
                if #available(iOS 17.0, macOS 14.0, *) {
                    AppExportPreviewMapView(
                        previewData: previewData,
                        fillContainer: true,
                        mapControlTopPadding: lhDeviceTopSafeInset() + LHHeroMapLayout.mapControlTopOffset,
                        verticalMapControls: true
                    )
                } else {
                    exportHeroMapPlaceholder
                }
            } else {
                exportHeroMapPlaceholder
            }
        }
        .accessibilityIdentifier("export.map.header")
    }

    @ViewBuilder
    private var exportHeroMapPlaceholder: some View {
        let hasSelectableItems = !filteredSummaries.isEmpty || !liveLocation.recordedTracks.isEmpty
        VStack(spacing: 12) {
            Image(systemName: "map")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(hasSelectableItems
                 ? t("Pick a day or live track to preview")
                 : t("No preview yet"))
                .font(.headline)
            Text(hasSelectableItems
                 ? t("Tap any item below to build your export.")
                 : t("Select at least one day or saved live track to see the export preview here."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.secondary.opacity(0.06))
    }

    @ViewBuilder
    private func exportHeroFilterPanel(selection: ExportSelectionState, summaries: [DaySummary]) -> some View {
        let review = ExportPresentation.reviewSnapshot(
            importedExport: session.content?.export,
            selection: selection,
            recordedTracks: liveLocation.recordedTracks,
            queryFilter: effectiveQueryFilter,
            mode: effectiveExportMode
        )

        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Text(t("Export"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)

                Text(selectedFormat.rawValue.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(LH2GPXTheme.primaryBlue)
                    .clipShape(Capsule())
                    .accessibilityIdentifier("export.hero.formatPill")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if selection.isEmpty {
                        let hasSelectableItems = !summaries.isEmpty || !liveLocation.recordedTracks.isEmpty
                        LHFilterChip(
                            title: hasSelectableItems ? t("Tap to choose") : t("Nothing selected"),
                            systemImage: hasSelectableItems ? "hand.tap" : "exclamationmark.triangle",
                            isActive: false,
                            action: {}
                        )
                    } else {
                        if review.selectedDayCount > 0 {
                            LHFilterChip(
                                title: "\(review.selectedDayCount) \(t("days"))",
                                systemImage: "calendar",
                                isActive: false,
                                action: {}
                            )
                        }
                        if review.selectedRecordedTrackCount > 0 {
                            LHFilterChip(
                                title: "\(review.selectedRecordedTrackCount) \(t("tracks"))",
                                systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                                isActive: false,
                                action: {}
                            )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .accessibilityIdentifier("export.hero.filterPanel")
    }

    // MARK: - Title Header

    @ViewBuilder
    private var titleHeaderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("Export"))
                .font(.title.weight(.bold))
            Text(t("Review your selection, confirm the file format and then export a real generated file."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Insights Drilldown Card

    @ViewBuilder
    private var insightsDrilldownCard: some View {
        LHCard {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "scope")
                    .foregroundStyle(LH2GPXTheme.primaryBlue)
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("Adopted from Insights"))
                        .font(.subheadline.weight(.semibold))
                    Text(insightsExportDrilldownDescription ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(t("Reset Drilldown")) {
                    clearInsightsDrilldown()
                }
                .font(.caption.weight(.medium))
                .accessibilityIdentifier("export.resetDrilldown")
            }
        }
    }

    // MARK: - Range Filter Card

    @ViewBuilder
    private var rangeFilterCard: some View {
        LHCard {
            LHSectionHeader(t("Time Range"))
            AppHistoryDateRangeControl(
                filter: $session.historyDateRangeFilter,
                showsExportHint: true
            )
            .accessibilityIdentifier("export.range.card")
        }
    }

    // MARK: - Preview Card

    @ViewBuilder
    private func previewCard(selection: ExportSelectionState, summaries: [DaySummary]) -> some View {
        let previewData = ExportPreviewDataBuilder.previewData(
            importedExport: session.content?.export,
            selection: selection,
            recordedTracks: liveLocation.recordedTracks,
            queryFilter: effectiveQueryFilter,
            mode: effectiveExportMode
        )
        let presentation = MapPresentation.exportPreview(
            previewData,
            unit: preferences.distanceUnit,
            mode: effectiveExportMode,
            language: preferences.appLanguage
        )
        let hasSelectableItems = !summaries.isEmpty || !liveLocation.recordedTracks.isEmpty

        if selection.isEmpty && hasSelectableItems {
            // Suppressed: hero placeholder is the canonical empty surface when
            // selectable items exist. Avoids duplicate "select something" copy.
            EmptyView()
        } else {
        LHCard {
            LHSectionHeader(t("Preview"))
            if selection.isEmpty {
                Label(
                    t("Select at least one day or saved live track to unlock the preview."),
                    systemImage: "map"
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            } else if previewData.hasMapContent {
                // When heroEnabled the map is already rendered full-bleed via
                // safeAreaInset(.top); only show stats/legend here to avoid a
                // duplicated map. Empty/legacy paths keep the inline map.
                if !heroEnabled {
                    if #available(iOS 17.0, macOS 14.0, *) {
                        AppExportPreviewMapView(previewData: previewData)
                            .accessibilityIdentifier("export.map.preview")
                    } else {
                        Label(
                            t("Map preview requires a newer Apple platform version, but the export summary below still reflects the current selection."),
                            systemImage: "map"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                MapSectionSupplementaryView(presentation: presentation)
            } else {
                compactPreviewSummary(selection: selection, summaries: summaries)
            }
        }
        }
    }

    // MARK: - Selection Summary Card

    @ViewBuilder
    private func selectionSummaryCard(
        selection: ExportSelectionState,
        summaries: [DaySummary],
        proxy: ScrollViewProxy
    ) -> some View {
        let review = ExportPresentation.reviewSnapshot(
            importedExport: session.content?.export,
            selection: selection,
            recordedTracks: liveLocation.recordedTracks,
            queryFilter: effectiveQueryFilter,
            mode: effectiveExportMode
        )
        let distance = selectedDistance(selection: selection, summaries: summaries)

        LHCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("Review Selection"))
                        .font(.subheadline.weight(.semibold))
                    Text(selectionSummarySubtitle(review: review))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !selection.isEmpty {
                    Button {
                        if !summaries.isEmpty {
                            withAnimation { proxy.scrollTo("export.days.section", anchor: .top) }
                        } else {
                            openDaysReview()
                        }
                    } label: {
                        Label(t("Review in Days"), systemImage: "calendar")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityIdentifier("export.selection.edit")
                }
            }

            if review.selectedSourceCount > 0 {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 10
                ) {
                    LHMetricCard(
                        icon: "calendar",
                        label: t("Days"),
                        value: "\(review.selectedDayCount)",
                        color: LH2GPXTheme.primaryBlue
                    )
                    LHMetricCard(
                        icon: "location.north.line",
                        label: t("Tracks"),
                        value: "\(review.routeCount)",
                        color: LH2GPXTheme.routeOrange
                    )
                    LHMetricCard(
                        icon: "calendar.badge.clock",
                        label: t("Period"),
                        value: selectionPeriodLabel(review: review),
                        color: LH2GPXTheme.distancePurple
                    )
                    LHMetricCard(
                        icon: "point.topleft.down.curvedto.point.bottomright.up",
                        label: t("Points"),
                        value: "\(review.pointCount)",
                        color: LH2GPXTheme.liveMint
                    )
                }

                if review.routeCount > 0 || review.waypointCount > 0 || distance > 0 || selection.hasExplicitRouteSelection {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if review.routeCount > 0 {
                                exportSummaryBadge(title: routeCountText(review.routeCount), systemImage: "location.north.line")
                            }
                            if review.waypointCount > 0 {
                                exportSummaryBadge(title: waypointCountText(review.waypointCount), systemImage: "mappin.and.ellipse")
                            }
                            if selection.hasExplicitRouteSelection {
                                exportSummaryBadge(
                                    title: customRouteSelectionBadgeTitle(selection.explicitRouteSelectionCount),
                                    systemImage: "line.3.horizontal.decrease.circle"
                                )
                            }
                            if distance > 0 {
                                exportSummaryBadge(
                                    title: formatDistance(distance, unit: preferences.distanceUnit),
                                    systemImage: "ruler"
                                )
                            }
                        }
                    }
                }

                Text(exportFilenamePreview(selection: selection, summaries: summaries))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)

                if let readinessMessage = invalidSelectionMessage(review: review) {
                    LHContextBar(
                        message: readinessMessage,
                        systemImage: "exclamationmark.triangle.fill",
                        tint: .orange
                    ) {
                        openDaysReview()
                    }
                }
            } else {
                let hasSelectableItems = !summaries.isEmpty || !liveLocation.recordedTracks.isEmpty
                VStack(alignment: .leading, spacing: 10) {
                    if hasSelectableItems {
                        Text(t("Tap any day or saved live track below to start your export."))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    } else {
                        Label(
                            t("No exportable days or tracks are selected yet."),
                            systemImage: "square.and.arrow.up.trianglebadge.exclamationmark"
                        )
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        Text(t("Start from Days to pick one or more dates, or import a file first if your history is still empty."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if hasSelectableItems {
                        selectionStartActions(summaries: summaries)
                    } else {
                        selectionFallbackActions
                    }
                }
            }
        }
    }

    // MARK: - Days Card

    @ViewBuilder
    private func daysCard(summaries: [DaySummary], selection: ExportSelectionState) -> some View {
        LHCard {
            HStack {
                LHSectionHeader(t("Days"))
                Spacer()
                if selection.selectedDayCount == summaries.count {
                    Button(t("Deselect All")) {
                        session.exportSelection.clearAllDays()
                    }
                    .font(.subheadline)
                    .accessibilityIdentifier("export.days.deselectAll")
                } else {
                    Button(t("Select All")) {
                        session.exportSelection.selectAll(from: summaries.map(\.date))
                    }
                    .font(.subheadline)
                    .accessibilityIdentifier("export.days.selectAll")
                }
            }

            VStack(spacing: 0) {
                ForEach(summaries, id: \.date) { summary in
                    dayRow(summary: summary, isSelected: selection.isSelected(summary.date))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            session.exportSelection.toggle(summary.date)
                        }
                        .accessibilityIdentifier("export.day.row")
                    if summary.date != summaries.last?.date {
                        Divider().padding(.leading, 44)
                    }
                }
            }
        }
    }

    // MARK: - Live Tracks Card

    @ViewBuilder
    private func liveTracksCard(selection: ExportSelectionState) -> some View {
        LHCard {
            HStack {
                LHSectionHeader(t("Saved Live Tracks"))
                Spacer()
                if selection.selectedRecordedTrackCount == liveLocation.recordedTracks.count {
                    Button(t("Deselect All")) {
                        session.exportSelection.clearRecordedTracks()
                    }
                    .font(.subheadline)
                    .accessibilityIdentifier("export.liveTracks.deselectAll")
                } else {
                    Button(t("Select All")) {
                        session.exportSelection.selectAllRecordedTracks(
                            from: liveLocation.recordedTracks.map(\.id)
                        )
                    }
                    .font(.subheadline)
                    .accessibilityIdentifier("export.liveTracks.selectAll")
                }
            }

            VStack(spacing: 0) {
                ForEach(liveLocation.recordedTracks) { track in
                    recordedTrackRow(
                        track: track,
                        isSelected: selection.isSelected(recordedTrackID: track.id)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        session.exportSelection.toggleRecordedTrack(track.id)
                    }
                    if track.id != liveLocation.recordedTracks.last?.id {
                        Divider().padding(.leading, 44)
                    }
                }
            }
        }
    }

    // MARK: - Format Card

    @ViewBuilder
    private var formatCard: some View {
        LHCard {
            LHSectionHeader(t("Choose Format"))
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(ExportFormat.allCases) { format in
                    formatPill(format)
                }
            }
        }
    }

    @ViewBuilder
    private func formatPill(_ format: ExportFormat) -> some View {
        let isSelected = selectedFormat == format
        Button { selectedFormat = format } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: format.systemImage)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white : LH2GPXTheme.primaryBlue)
                    Text(format.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : .primary)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                }
                Text(t(format.description))
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? LH2GPXTheme.primaryBlue : LH2GPXTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.clear : LH2GPXTheme.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content Card

    @ViewBuilder
    private var contentCard: some View {
        LHCard {
            LHSectionHeader(t("What to include"))
            VStack(spacing: 8) {
                ForEach(ExportMode.allCases) { mode in
                    modePill(mode)
                }
            }
        }
    }

    @ViewBuilder
    private func modePill(_ mode: ExportMode) -> some View {
        let isSelected = selectedMode == mode
        Button { selectedMode = mode } label: {
            HStack(spacing: 10) {
                Image(systemName: modeIcon(mode))
                    .foregroundStyle(isSelected ? .white : LH2GPXTheme.primaryBlue)
                    .frame(width: 20)
                Text(t(mode.rawValue))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isSelected ? .white : .primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(isSelected ? LH2GPXTheme.primaryBlue : LH2GPXTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.clear : LH2GPXTheme.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func modeIcon(_ mode: ExportMode) -> String {
        switch mode {
        case .tracks:    return "location.north.line"
        case .waypoints: return "mappin.and.ellipse"
        case .both:      return "map"
        }
    }

    // MARK: - CSV Note Card

    @ViewBuilder
    private var csvNoteCard: some View {
        LHCard {
            LHSectionHeader(t("What to include"))
            Label(
                t("CSV always exports the visible table rows for visits, activities and routes."),
                systemImage: "tablecells"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var exportTargetCard: some View {
        LHCard {
            LHSectionHeader(t("Export Destination"))
            VStack(alignment: .leading, spacing: 10) {
                Label(t("Save or Share"), systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                Text(exportTargetDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !hasImportedExport && !liveLocation.recordedTracks.isEmpty {
                    Text(t("Saved live tracks are exported through the same system sheet and remain local unless you explicitly share the generated file."))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier("export.target.card")
    }

    // MARK: - Filter Content (inside LHExportFilterDisclosure)

    @ViewBuilder
    private var filterContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !activeFilterDescriptions.isEmpty {
                LHContextBar(
                    message: activeFilterDescriptions.joined(separator: " · "),
                    systemImage: "line.3.horizontal.decrease.circle.fill",
                    tint: .orange
                ) {
                    resetLocalFilters()
                }
            } else {
                Text(t("Limit imported history by date window or maximum accuracy. Saved Live Tracks stay unaffected by these local export filters."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !dateOptions.isEmpty {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(t("From"))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Picker(t("From"), selection: $selectedFromDate) {
                            Text(t("Any")).tag("")
                            ForEach(dateOptions, id: \.self) { date in
                                Text(AppDateDisplay.mediumDate(date)).tag(date)
                            }
                        }
                        .labelsHidden()
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(t("To"))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Picker(t("To"), selection: $selectedToDate) {
                            Text(t("Any")).tag("")
                            ForEach(dateOptions, id: \.self) { date in
                                Text(AppDateDisplay.mediumDate(date)).tag(date)
                            }
                        }
                        .labelsHidden()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(t("Maximum accuracy"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Picker(t("Maximum accuracy"), selection: $selectedAccuracyFilter) {
                    ForEach(ExportAccuracyFilterOption.allCases) { option in
                        Text(t(option.rawValue)).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(t("Required imported content"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                filterChipRow {
                    ForEach(AppExportContentRequirement.allCases, id: \.self) { req in
                        filterChip(
                            title: contentRequirementTitle(req),
                            isSelected: selectedContentRequirements.contains(req)
                        ) { toggleContentRequirement(req) }
                    }
                }
            }

            if !availableActivityTypes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("Activity types"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    filterChipRow {
                        ForEach(availableActivityTypes, id: \.self) { activityType in
                            filterChip(
                                title: activityTypeTitle(activityType),
                                isSelected: selectedActivityTypes.contains(activityType)
                            ) { toggleActivityType(activityType) }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(t("Area filter"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Picker(t("Area filter"), selection: $selectedAreaFilter) {
                    ForEach(ExportAreaFilterOption.allCases) { option in
                        Text(t(option.rawValue)).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                switch selectedAreaFilter {
                case .none:
                    Text(t("Optional area filters affect imported history only. Saved Live Tracks always keep their full recorded geometry."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .bounds:
                    VStack(alignment: .leading, spacing: 8) {
                        Text(t("Enter latitude and longitude bounds. Values are combined with any upstream export filters."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            TextField(t("Min lat"), text: $boundsMinLat).textFieldStyle(.roundedBorder)
                            TextField(t("Max lat"), text: $boundsMaxLat).textFieldStyle(.roundedBorder)
                        }
                        HStack(spacing: 12) {
                            TextField(t("Min lon"), text: $boundsMinLon).textFieldStyle(.roundedBorder)
                            TextField(t("Max lon"), text: $boundsMaxLon).textFieldStyle(.roundedBorder)
                        }
                    }
                case .polygon:
                    VStack(alignment: .leading, spacing: 8) {
                        Text(t("Enter one `lat,lon` pair per line. At least three vertices are required."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $polygonCoordinatesText)
                            .frame(minHeight: 96)
                            .padding(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.secondary.opacity(0.2))
                            )
                    }
                }

                if let spatialFilterValidationMessage {
                    Label(spatialFilterValidationMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            if filteredSummaries.isEmpty {
                Label(
                    t("The current imported-history filters hide all day rows. Saved Live Tracks can still be exported separately."),
                    systemImage: "line.3.horizontal.decrease.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Bottom Bar

    @ViewBuilder
    private func bottomBar(selection: ExportSelectionState, summaries: [DaySummary]) -> some View {
        LHExportBottomBar(
            summary: ExportPresentation.bottomBarSummary(
                importedExport: session.content?.export,
                selection: selection,
                recordedTracks: liveLocation.recordedTracks,
                queryFilter: effectiveQueryFilter,
                mode: effectiveExportMode,
                format: selectedFormat,
                language: preferences.appLanguage
            ),
            buttonTitle: t("Export"),
            isEnabled: isExportReady(selection: selection, summaries: summaries),
            disabledReason: ExportPresentation.disabledReason(
                importedExport: session.content?.export,
                selection: selection,
                recordedTracks: liveLocation.recordedTracks,
                queryFilter: effectiveQueryFilter,
                mode: effectiveExportMode,
                language: preferences.appLanguage
            ),
            onExport: {
                prepareExport(selection: selection, summaries: summaries)
            }
        )
    }

    // MARK: - Shared Row Views

    @ViewBuilder
    private func dayRow(summary: DaySummary, isSelected: Bool) -> some View {
        let hasRoutes = summary.pathCount > 0
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .animation(.easeInOut(duration: 0.15), value: isSelected)

            VStack(alignment: .leading, spacing: 2) {
                Text(AppDateDisplay.mediumDate(summary.date))
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 10) {
                    if summary.visitCount > 0 {
                        Label(visitCountText(summary.visitCount), systemImage: "mappin.and.ellipse")
                            .foregroundStyle(.secondary)
                    }
                    if summary.activityCount > 0 {
                        Label(activityCountText(summary.activityCount), systemImage: "figure.walk")
                            .foregroundStyle(.secondary)
                    }
                    if hasRoutes {
                        Label(routeCountText(summary.pathCount), systemImage: "location.north.line")
                            .foregroundStyle(.secondary)
                    }
                    if summary.totalPathDistanceM > 0 {
                        Label(
                            formatDistance(summary.totalPathDistanceM, unit: preferences.distanceUnit),
                            systemImage: "ruler"
                        )
                        .foregroundStyle(.secondary)
                    }
                    if !hasRoutes && summary.visitCount == 0 && summary.activityCount == 0 {
                        Label(t("No map content"), systemImage: "exclamationmark.circle")
                            .foregroundStyle(.tertiary)
                    }
                }
                .font(.caption)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(AppDateDisplay.mediumDate(summary.date)), \(routeCountText(summary.pathCount))")
        .accessibilityValue(isSelected ? t("Selected") : t("Not selected"))
        .accessibilityHint(t("Double-tap to toggle selection"))
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func recordedTrackRow(track: RecordedTrack, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .animation(.easeInOut(duration: 0.15), value: isSelected)

            VStack(alignment: .leading, spacing: 2) {
                Text(savedTrackTitle(track))
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 10) {
                    Label(
                        pointCountText(track.pointCount),
                        systemImage: "point.topleft.down.curvedto.point.bottomright.up"
                    )
                    .foregroundStyle(.secondary)
                    Label(
                        formatDistance(track.distanceM, unit: preferences.distanceUnit),
                        systemImage: "ruler"
                    )
                    .foregroundStyle(.secondary)
                    Text(captureModeLabel(for: track))
                        .foregroundStyle(.tertiary)
                }
                .font(.caption)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(savedTrackTitle(track)), \(pointCountText(track.pointCount))")
        .accessibilityValue(isSelected ? t("Selected") : t("Not selected"))
        .accessibilityHint(t("Double-tap to toggle selection"))
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func exportSummaryBadge(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func compactPreviewSummary(selection: ExportSelectionState, summaries: [DaySummary]) -> some View {
        let review = ExportPresentation.reviewSnapshot(
            importedExport: session.content?.export,
            selection: selection,
            recordedTracks: liveLocation.recordedTracks,
            queryFilter: effectiveQueryFilter,
            mode: effectiveExportMode
        )

        VStack(alignment: .leading, spacing: 10) {
            Label(
                t("No stable map preview is available for the current selection."),
                systemImage: "map"
            )
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)

            Text(ExportPresentation.helperMessage(
                importedExport: session.content?.export,
                selection: selection,
                recordedTracks: liveLocation.recordedTracks,
                format: selectedFormat,
                queryFilter: effectiveQueryFilter,
                mode: effectiveExportMode,
                language: preferences.appLanguage
            ))
            .font(.caption)
            .foregroundStyle(.secondary)

            if review.selectedSourceCount > 0 {
                HStack(spacing: 8) {
                    exportSummaryBadge(title: selectionPeriodLabel(review: review), systemImage: "calendar")
                    if review.routeCount > 0 {
                        exportSummaryBadge(title: routeCountText(review.routeCount), systemImage: "location.north.line")
                    }
                    if review.pointCount > 0 {
                        exportSummaryBadge(title: pointCountText(review.pointCount), systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var selectionFallbackActions: some View {
        HStack(spacing: 10) {
            Button(t("Open Days")) {
                openDaysReview()
            }
            .buttonStyle(.borderedProminent)

            if let onOpenImport {
                Button(t("Import File")) {
                    onOpenImport()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    /// Prominent CTAs shown in the summary card when the user has nothing
    /// selected yet but selectable items (days or saved live tracks) exist.
    /// The primary action is `.borderedProminent` to draw the eye toward the
    /// fastest path to a non-empty selection.
    @ViewBuilder
    private func selectionStartActions(summaries: [DaySummary]) -> some View {
        HStack(spacing: 10) {
            if !summaries.isEmpty {
                Button(t("Select All Days")) {
                    session.exportSelection.selectAll(from: summaries.map(\.date))
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("export.days.selectAll.cta")
            }
            if !liveLocation.recordedTracks.isEmpty {
                if summaries.isEmpty {
                    Button(t("Select All Tracks")) {
                        session.exportSelection.selectAllRecordedTracks(
                            from: liveLocation.recordedTracks.map(\.id)
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("export.liveTracks.selectAll.cta")
                } else {
                    Button(t("Select All Tracks")) {
                        session.exportSelection.selectAllRecordedTracks(
                            from: liveLocation.recordedTracks.map(\.id)
                        )
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("export.liveTracks.selectAll.cta")
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.up.trianglebadge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(t("Nothing to Export"))
                .font(.headline)
            Text(t("Import a location history file or save a live track first to enable export."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            selectionFallbackActions
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    // MARK: - Observers (file exporters, onChange, alerts)

    @ViewBuilder
    private func exportContentObservers<Content: View>(
        summaries: [DaySummary],
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            #if canImport(UniformTypeIdentifiers)
            .fileExporter(
                isPresented: $isExporting,
                document: exportDocument,
                contentType: exportContentType,
                defaultFilename: exportDocument?.suggestedFilename ?? "lh2gpx-export.\(selectedFormat.fileExtension)"
            ) { result in
                if case let .failure(error) = result { exportError = error.localizedDescription }
                exportDocument = nil
            }
            .fileExporter(
                isPresented: $isExportingKMZ,
                document: kmzExportDocument,
                contentType: .kmz,
                defaultFilename: kmzExportDocument?.suggestedFilename ?? "lh2gpx-export.kmz"
            ) { result in
                if case let .failure(error) = result { exportError = error.localizedDescription }
                kmzExportDocument = nil
            }
            #endif
            .alert(t("Export Failed"), isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )) {
                Button(t("OK"), role: .cancel) { exportError = nil }
            } message: {
                Text(exportError ?? "")
            }
            .onChange(of: liveLocation.recordedTracks) { tracks in
                pruneInvalidRecordedTrackSelection(validTracks: tracks)
            }
            .onChange(of: importedSelectionPruneTrigger) { _ in
                normalizeDateFilterBounds()
                pruneInvalidImportedDaySelection(summaries: filteredSummaries)
            }
            .onChange(of: session.sourceSummary) { _ in
                resetLocalFilters()
            }
    }

    // MARK: - Export Logic

    private func isExportReady(selection: ExportSelectionState, summaries: [DaySummary]) -> Bool {
        switch ExportPresentation.readiness(
            importedExport: session.content?.export,
            selection: selection,
            recordedTracks: liveLocation.recordedTracks,
            queryFilter: effectiveQueryFilter,
            mode: effectiveExportMode
        ) {
        case .ready:                         return true
        case .nothingSelected, .noExportableContent: return false
        }
    }

    private func selectedDistance(selection: ExportSelectionState, summaries _: [DaySummary]) -> Double {
        let exportDays = ExportSelectionContent.exportDays(
            importedExport: session.content?.export,
            selection: selection,
            recordedTracks: liveLocation.recordedTracks,
            queryFilter: effectiveQueryFilter
        )
        return exportDays.reduce(0) { partial, day in
            partial + day.paths.reduce(0) { $0 + ($1.distanceM ?? 0) }
        }
    }

    private func exportFilenamePreview(selection: ExportSelectionState, summaries: [DaySummary]) -> String {
        ExportPresentation.suggestedFilename(
            selection: selection,
            summaries: summaries,
            recordedTracks: liveLocation.recordedTracks,
            format: selectedFormat,
            mode: effectiveExportMode
        )
    }

    private func selectionPeriodLabel(review: ExportPresentation.ReviewSnapshot) -> String {
        guard let first = review.selectedDates.first, let last = review.selectedDates.last else { return "–" }
        if first == last { return String(first.prefix(7)) }
        return "\(first.prefix(7)) – \(last.prefix(7))"
    }

    private func customRouteSelectionBadgeTitle(_ explicitDayCount: Int) -> String {
        if preferences.appLanguage.isGerman {
            return "\(explicitDayCount) \(explicitDayCount == 1 ? "Tag mit Routenauswahl" : "Tage mit Routenauswahl")"
        }
        return "\(explicitDayCount) day\(explicitDayCount == 1 ? "" : "s") with custom routes"
    }

    private func selectionSummarySubtitle(review: ExportPresentation.ReviewSnapshot) -> String {
        if review.selectedSourceCount == 0 {
            return t("Choose the days or saved live tracks you want to review before exporting.")
        }
        return ExportPresentation.selectionSummary(
            selectedDayCount: review.selectedDayCount,
            selectedRecordedTrackCount: review.selectedRecordedTrackCount,
            language: preferences.appLanguage
        )
    }

    private func invalidSelectionMessage(review: ExportPresentation.ReviewSnapshot) -> String? {
        switch review.readiness {
        case .ready:
            return nil
        case .nothingSelected:
            // Unreachable in practice: `LHContextBar` only renders when
            // `selectedSourceCount > 0`, which means readiness is never
            // `.nothingSelected` at this call site. Kept for switch
            // exhaustiveness; intentionally returns nil.
            return nil
        case .noExportableContent:
            return ExportPresentation.disabledReason(
                importedExport: session.content?.export,
                selection: session.exportSelection,
                recordedTracks: liveLocation.recordedTracks,
                queryFilter: effectiveQueryFilter,
                mode: effectiveExportMode,
                language: preferences.appLanguage
            )
        }
    }

    private var exportTargetDescription: String {
        if preferences.appLanguage.isGerman {
            return "Nach dem Tippen auf Export öffnet die Systemfreigabe den echten \(selectedFormat.rawValue)-Export. Dort kannst du die Datei in Dateien sichern oder direkt teilen."
        }
        return "After you tap Export, the system sheet opens the real generated \(selectedFormat.rawValue) file so you can save it to Files or share it directly."
    }

    private func openDaysReview() {
        if let onOpenDays {
            onOpenDays()
            return
        }
        dismiss()
    }

    private func prepareExport(selection: ExportSelectionState, summaries: [DaySummary]) {
        guard isExportReady(selection: selection, summaries: summaries) else {
            exportError = ExportPresentation.helperMessage(
                importedExport: session.content?.export,
                selection: selection,
                recordedTracks: liveLocation.recordedTracks,
                format: selectedFormat,
                queryFilter: effectiveQueryFilter,
                mode: effectiveExportMode,
                language: preferences.appLanguage
            )
            return
        }

        let exportDays = ExportSelectionContent.exportDays(
            importedExport: session.content?.export,
            selection: selection,
            recordedTracks: liveLocation.recordedTracks,
            queryFilter: effectiveQueryFilter
        )

        guard !exportDays.isEmpty else {
            exportError = t("The current selection contains no exportable route paths.")
            return
        }

        if selectedFormat == .kmz {
            do {
                let kmzData = try KMZBuilder.build(from: exportDays, mode: effectiveExportMode)
                kmzExportDocument = KMZExportDocument(
                    data: kmzData,
                    suggestedFilename: exportFilenamePreview(selection: selection, summaries: summaries)
                )
                isExportingKMZ = true
            } catch {
                exportError = t("KMZ export failed. The archive could not be created.")
            }
            return
        }

        let content: String
        switch selectedFormat {
        case .gpx:
            content = GPXBuilder.build(from: exportDays, mode: effectiveExportMode)
        case .kml:
            content = KMLBuilder.build(from: exportDays, mode: effectiveExportMode)
        case .geoJSON:
            do {
                content = try GeoJSONBuilder.build(from: exportDays, mode: effectiveExportMode)
            } catch {
                exportError = t("GeoJSON export failed. The data could not be serialized.")
                return
            }
        case .csv:
            content = CSVBuilder.build(from: exportDays)
        case .kmz:
            return
        }

        exportDocument = ExportDocument(
            content: content,
            suggestedFilename: exportFilenamePreview(selection: selection, summaries: summaries)
        )
        #if canImport(UniformTypeIdentifiers)
        exportContentType = selectedFormat.contentType
        #endif
        isExporting = true
    }

    private func pruneInvalidRecordedTrackSelection(validTracks: [RecordedTrack]) {
        let validIDs   = Set(validTracks.map(\.id))
        let invalidIDs = session.exportSelection.selectedRecordedTrackIDs.subtracting(validIDs)
        for id in invalidIDs { session.exportSelection.toggleRecordedTrack(id) }
    }

    // MARK: - Computed Properties

    private var hasImportedExport: Bool {
        session.content?.export != nil
    }

    private var insightsExportDrilldownDescription: String? {
        InsightsDrilldownBridge.description(
            for: InsightsDrilldownBridge.exportAction(from: session.activeDrilldownFilter),
            language: preferences.appLanguage
        )
    }

    private var filteredSummaries: [DaySummary] {
        DaySummaryDisplayOrdering.newestFirst(
            session.content?.daySummaries(applying: effectiveQueryFilter) ?? []
        )
    }

    private var dateOptions: [String] {
        session.daySummaries.map(\.date).sorted()
    }

    private var availableActivityTypes: [String] {
        session.content?.overview(applying: globalRangeQueryFilter).statsActivityTypes ?? []
    }

    private var importedSelectionPruneTrigger: ImportedSelectionPruneTrigger {
        ImportedSelectionPruneTrigger(
            fromDate: selectedFromDate,
            toDate: selectedToDate,
            accuracyFilter: selectedAccuracyFilter,
            requiredContent: selectedContentRequirements,
            activityTypes: selectedActivityTypes,
            areaFilter: selectedAreaFilter,
            boundsMinLat: boundsMinLat,
            boundsMaxLat: boundsMaxLat,
            boundsMinLon: boundsMinLon,
            boundsMaxLon: boundsMaxLon,
            polygonCoordinatesText: polygonCoordinatesText,
            rangeFilter: session.historyDateRangeFilter
        )
    }

    private var baseExportQueryFilter: AppExportQueryFilter? {
        session.content.map { AppExportQueryFilter(exportFilters: $0.export.meta.filters) }
    }

    private var globalRangeQueryFilter: AppExportQueryFilter? {
        AppHistoryDateRangeQueryBridge.mergedFilter(
            base: baseExportQueryFilter,
            rangeFilter: session.historyDateRangeFilter
        )
    }

    private var effectiveQueryFilter: AppExportQueryFilter? {
        guard hasImportedExport else { return nil }
        let baseFilter  = globalRangeQueryFilter ?? AppExportQueryFilter()
        let fromDate    = mergedLowerBound(base: baseFilter.fromDate, local: selectedFromDate)
        let toDate      = mergedUpperBound(base: baseFilter.toDate,   local: selectedToDate)
        let maxAccuracyM = mergedMaxAccuracy(
            base: baseFilter.maxAccuracyM,
            local: selectedAccuracyFilter.maxAccuracyM
        )
        let requiredContent = baseFilter.requiredContent.union(selectedContentRequirements)
        let activityTypes   = mergedActivityTypes(
            base:  baseFilter.activityTypes,
            local: selectedActivityTypes
        )
        let spatialFilter = mergedSpatialFilter(
            base:  baseFilter.spatialFilter,
            local: localSpatialFilter
        )
        return AppExportQueryFilter(
            fromDate: fromDate,
            toDate: toDate,
            year: baseFilter.year,
            month: baseFilter.month,
            weekday: baseFilter.weekday,
            limit: baseFilter.limit,
            days: baseFilter.days,
            requiredContent: requiredContent,
            maxAccuracyM: maxAccuracyM,
            activityTypes: activityTypes,
            minGapMin: baseFilter.minGapMin,
            spatialFilter: spatialFilter
        )
    }

    private var activeFilterDescriptions: [String] {
        var d: [String] = []
        if !selectedFromDate.isEmpty         { d.append("\(t("From")): \(selectedFromDate)") }
        if !selectedToDate.isEmpty           { d.append("\(t("To")): \(selectedToDate)") }
        if let m = selectedAccuracyFilter.maxAccuracyM {
            d.append("\(t("Maximum accuracy")): \(Int(m))m")
        }
        if !selectedContentRequirements.isEmpty {
            d.append("\(t("Required imported content")): \(selectedContentRequirements.map(contentRequirementTitle).sorted().joined(separator: ", "))")
        }
        if !selectedActivityTypes.isEmpty {
            d.append("\(t("Activity types")): \(selectedActivityTypes.map(activityTypeTitle).sorted().joined(separator: ", "))")
        }
        if let localAreaFilterDescription { d.append(localAreaFilterDescription) }
        return d
    }

    // MARK: - Mutations / helpers

    private func resetLocalFilters() {
        selectedFromDate             = ""
        selectedToDate               = ""
        selectedAccuracyFilter       = .any
        selectedContentRequirements  = []
        selectedActivityTypes        = []
        selectedAreaFilter           = .none
        boundsMinLat                 = ""
        boundsMaxLat                 = ""
        boundsMinLon                 = ""
        boundsMaxLon                 = ""
        polygonCoordinatesText       = ""
    }

    private func clearInsightsDrilldown() {
        session.activeDrilldownFilter = nil
        session.exportSelection.clearAllDays()
        for date in Array(session.exportSelection.routeSelections.keys) {
            session.exportSelection.clearRouteSelection(day: date)
        }
    }

    private func normalizeDateFilterBounds() {
        guard !selectedFromDate.isEmpty, !selectedToDate.isEmpty,
              selectedFromDate > selectedToDate else { return }
        selectedToDate = selectedFromDate
    }

    private func pruneInvalidImportedDaySelection(summaries: [DaySummary]) {
        let validDates   = Set(summaries.map(\.date))
        let invalidDates = session.exportSelection.selectedDates.subtracting(validDates)
        for date in invalidDates { session.exportSelection.toggle(date) }
    }

    private func mergedLowerBound(base: String?, local: String) -> String? {
        guard !local.isEmpty else { return base }
        guard let base else { return local }
        return max(base, local)
    }

    private func mergedUpperBound(base: String?, local: String) -> String? {
        guard !local.isEmpty else { return base }
        guard let base else { return local }
        return min(base, local)
    }

    private func mergedMaxAccuracy(base: Double?, local: Double?) -> Double? {
        switch (base, local) {
        case let (b?, l?): return min(b, l)
        case let (b?, nil): return b
        case let (nil, l?): return l
        case (nil, nil):    return nil
        }
    }

    private func mergedActivityTypes(base: Set<String>, local: Set<String>) -> Set<String> {
        if base.isEmpty  { return local }
        if local.isEmpty { return base  }
        return base.intersection(local)
    }

    private func mergedSpatialFilter(
        base:  ExportSpatialFilter?,
        local: ExportSpatialFilter?
    ) -> ExportSpatialFilter? {
        switch (base, local) {
        case let (b?, l?): return .all([b, l])
        case let (b?, nil): return b
        case let (nil, l?): return l
        case (nil, nil):    return nil
        }
    }

    private func toggleContentRequirement(_ requirement: AppExportContentRequirement) {
        if selectedContentRequirements.contains(requirement) {
            selectedContentRequirements.remove(requirement)
        } else {
            selectedContentRequirements.insert(requirement)
        }
    }

    private func toggleActivityType(_ activityType: String) {
        if selectedActivityTypes.contains(activityType) {
            selectedActivityTypes.remove(activityType)
        } else {
            selectedActivityTypes.insert(activityType)
        }
    }

    private func contentRequirementTitle(_ requirement: AppExportContentRequirement) -> String {
        switch requirement {
        case .visits:     return "Visits"
        case .activities: return "Activities"
        case .paths:      return "Routes"
        }
    }

    private func activityTypeTitle(_ activityType: String) -> String {
        activityType.capitalized
    }

    private var localSpatialFilter: ExportSpatialFilter? {
        switch selectedAreaFilter {
        case .none:
            return nil
        case .bounds:
            guard
                let minLat = parseCoordinate(boundsMinLat),
                let maxLat = parseCoordinate(boundsMaxLat),
                let minLon = parseCoordinate(boundsMinLon),
                let maxLon = parseCoordinate(boundsMaxLon)
            else { return nil }
            return .bounds(ExportCoordinateBounds(
                minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon
            ))
        case .polygon:
            let coordinates = parsePolygonCoordinates(polygonCoordinatesText)
            guard coordinates.count >= 3 else { return nil }
            return .polygon(coordinates)
        }
    }

    private var localAreaFilterDescription: String? {
        switch selectedAreaFilter {
        case .none:    return nil
        case .bounds:  return localSpatialFilter == nil ? nil : "\(t("Area")): \(t("Rectangle"))"
        case .polygon: return localSpatialFilter == nil ? nil : "\(t("Area")): \(t("Custom Shape"))"
        }
    }

    private var spatialFilterValidationMessage: String? {
        switch selectedAreaFilter {
        case .none: return nil
        case .bounds:
            guard hasBoundsInput else { return nil }
            return localSpatialFilter == nil
                ? "Enter valid min/max latitude and longitude values to activate the rectangle filter."
                : nil
        case .polygon:
            let trimmed = polygonCoordinatesText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return localSpatialFilter == nil
                ? "Provide at least three valid `lat,lon` lines to activate the custom shape filter."
                : nil
        }
    }

    private var hasBoundsInput: Bool {
        !boundsMinLat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !boundsMaxLat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !boundsMinLon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !boundsMaxLon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func parseCoordinate(_ value: String) -> Double? {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }

    private func parsePolygonCoordinates(_ value: String) -> [ExportCoordinate] {
        value
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> ExportCoordinate? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return nil }
                let parts = trimmed.split(separator: ",", omittingEmptySubsequences: false)
                guard parts.count == 2,
                      let lat = parseCoordinate(String(parts[0])),
                      let lon = parseCoordinate(String(parts[1])) else { return nil }
                return ExportCoordinate(lat: lat, lon: lon)
            }
    }

    @ViewBuilder
    private func filterChipRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
            content()
        }
    }

    @ViewBuilder
    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                Text(title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func savedTrackTitle(_ track: RecordedTrack) -> String {
        AppDateDisplay.abbreviatedDateTime(track.startedAt)
    }

    private func captureModeLabel(for track: RecordedTrack) -> String {
        switch track.captureMode {
        case .foregroundWhileInUse: return t("Foreground recording")
        case .backgroundAlways:     return t("Background recording")
        }
    }

    private func visitCountText(_ count: Int) -> String {
        preferences.appLanguage.isGerman
            ? "\(count) \(count == 1 ? "Besuch" : "Besuche")"
            : "\(count) visit\(count == 1 ? "" : "s")"
    }

    private func activityCountText(_ count: Int) -> String {
        preferences.appLanguage.isGerman
            ? "\(count) \(count == 1 ? "Aktivität" : "Aktivitäten")"
            : "\(count) activit\(count == 1 ? "y" : "ies")"
    }

    private func routeCountText(_ count: Int) -> String {
        preferences.appLanguage.isGerman
            ? "\(count) \(count == 1 ? "Route" : "Routen")"
            : "\(count) route\(count == 1 ? "" : "s")"
    }

    private func pointCountText(_ count: Int) -> String {
        preferences.appLanguage.isGerman
            ? "\(count) \(count == 1 ? "Punkt" : "Punkte")"
            : "\(count) point\(count == 1 ? "" : "s")"
    }

    private func sourceCountText(_ count: Int) -> String {
        preferences.appLanguage.isGerman
            ? "\(count) \(count == 1 ? "Quelle" : "Quellen")"
            : "\(count) source\(count == 1 ? "" : "s")"
    }

    private func waypointCountText(_ count: Int) -> String {
        preferences.appLanguage.isGerman
            ? "\(count) \(count == 1 ? "Wegpunkt" : "Wegpunkte")"
            : "\(count) waypoint\(count == 1 ? "" : "s")"
    }
}

#endif
