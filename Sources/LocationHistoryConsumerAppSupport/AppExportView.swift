#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumer
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

private enum ExportAccuracyFilterOption: String, Identifiable, CaseIterable {
    case any = "Any Accuracy"
    case m25 = "25 m"
    case m50 = "50 m"
    case m100 = "100 m"

    var id: String { rawValue }

    var maxAccuracyM: Double? {
        switch self {
        case .any:
            return nil
        case .m25:
            return 25
        case .m50:
            return 50
        case .m100:
            return 100
        }
    }
}

private enum ExportAreaFilterOption: String, Identifiable, CaseIterable {
    case none = "No Area Filter"
    case bounds = "Rectangle"
    case polygon = "Custom Shape"

    var id: String { rawValue }
}

public struct AppExportView: View {
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
    @State private var exportError: String?
    #if canImport(UniformTypeIdentifiers)
    @State private var exportContentType: UTType = .gpx
    #endif

    public init(session: Binding<AppSessionState>, liveLocation: LiveLocationFeatureModel) {
        self._session = session
        self._liveLocation = ObservedObject(wrappedValue: liveLocation)
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
        exportContentStack(selection: selection, summaries: summaries)
    }

    @ViewBuilder
    private func exportContentStack(selection: ExportSelectionState, summaries: [DaySummary]) -> some View {
        exportContentObservers(summaries: summaries) {
            VStack(spacing: 0) {
                exportList(selection: selection, summaries: summaries)
                exportBar(selection: selection, summaries: summaries)
            }
        }
    }

    @ViewBuilder
    private func exportList(selection: ExportSelectionState, summaries: [DaySummary]) -> some View {
        List {
            if insightsExportDrilldownDescription != nil {
                insightsDrilldownSection
            }

            selectionSummarySection(selection: selection, summaries: summaries)

            if hasImportedExport {
                globalRangeSection
            }

            if hasImportedExport {
                filterSection
            }

            if !selection.isEmpty {
                previewSection(selection: selection, summaries: summaries)
            }

            if !summaries.isEmpty {
                daysSection(summaries: summaries, selection: selection)
            }

            if !liveLocation.recordedTracks.isEmpty {
                recordedTracksSection(selection: selection)
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
    }

    @ViewBuilder
    private var insightsDrilldownSection: some View {
        Section {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "scope")
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("Insights Drilldown"))
                        .font(.subheadline.weight(.semibold))
                    Text(insightsExportDrilldownDescription ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(t("Reset")) {
                    clearInsightsDrilldown()
                }
                .font(.caption.weight(.medium))
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func exportContentObservers<Content: View>(summaries: [DaySummary], @ViewBuilder content: () -> Content) -> some View {
        content()
            #if canImport(UniformTypeIdentifiers)
            .fileExporter(
                isPresented: $isExporting,
                document: exportDocument,
                contentType: exportContentType,
                defaultFilename: exportDocument?.suggestedFilename ?? "lh2gpx-export.\(selectedFormat.fileExtension)"
            ) { result in
                if case let .failure(error) = result {
                    exportError = error.localizedDescription
                }
                exportDocument = nil
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

    @ViewBuilder
    private func daysSection(summaries: [DaySummary], selection: ExportSelectionState) -> some View {
        Section {
            ForEach(summaries, id: \.date) { summary in
                dayRow(summary: summary, isSelected: selection.isSelected(summary.date))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        session.exportSelection.toggle(summary.date)
                    }
                    .accessibilityIdentifier("export.day.row")
            }
        } header: {
            HStack {
                Text(t("Days"))
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
        }
    }

    @ViewBuilder
    private func recordedTracksSection(selection: ExportSelectionState) -> some View {
        Section {
            ForEach(liveLocation.recordedTracks) { track in
                recordedTrackRow(track: track, isSelected: selection.isSelected(recordedTrackID: track.id))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        session.exportSelection.toggleRecordedTrack(track.id)
                    }
            }
        } header: {
            HStack {
                Text(t("Saved Live Tracks"))
                Spacer()
                if selection.selectedRecordedTrackCount == liveLocation.recordedTracks.count {
                    Button(t("Deselect All")) {
                        session.exportSelection.clearRecordedTracks()
                    }
                    .font(.subheadline)
                } else {
                    Button(t("Select All")) {
                        session.exportSelection.selectAllRecordedTracks(from: liveLocation.recordedTracks.map(\.id))
                    }
                    .font(.subheadline)
                }
            }
        }
    }

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
                        Label(formatDistance(summary.totalPathDistanceM, unit: preferences.distanceUnit), systemImage: "ruler")
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
        .padding(.vertical, 2)
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
                    Label(pointCountText(track.pointCount), systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                        .foregroundStyle(.secondary)
                    Label(formatDistance(track.distanceM, unit: preferences.distanceUnit), systemImage: "ruler")
                        .foregroundStyle(.secondary)
                    Text(captureModeLabel(for: track))
                        .foregroundStyle(.tertiary)
                }
                .font(.caption)
            }

            Spacer()
        }
        .padding(.vertical, 2)
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
    private func selectionSummarySection(selection: ExportSelectionState, summaries: [DaySummary]) -> some View {
        let snapshot = ExportSelectionContent.snapshot(
            importedExport: session.content?.export,
            selection: selection,
            recordedTracks: liveLocation.recordedTracks,
            queryFilter: effectiveQueryFilter,
            mode: effectiveExportMode
        )
        let distance = selectedDistance(selection: selection, summaries: summaries)

        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectionSummaryTitle(snapshot: snapshot))
                            .font(.subheadline.weight(.semibold))
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
                    }

                    Spacer()

                    if snapshot.selectedSourceCount > 0 {
                        Text(exportFilenamePreview(selection: selection, summaries: summaries))
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(Capsule())
                    }
                }

                if snapshot.selectedSourceCount > 0 {
                    HStack(spacing: 10) {
                        exportSummaryBadge(
                            title: sourceCountText(snapshot.selectedSourceCount),
                            systemImage: "tray.full"
                        )
                        if snapshot.routeCount > 0 {
                            exportSummaryBadge(
                                title: routeCountText(snapshot.routeCount),
                                systemImage: "location.north.line"
                            )
                        }
                        if snapshot.waypointCount > 0 {
                            exportSummaryBadge(
                                title: waypointCountText(snapshot.waypointCount),
                                systemImage: "mappin.and.ellipse"
                            )
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
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var filterSection: some View {
        Section(t("Filter Imported History")) {
            VStack(alignment: .leading, spacing: 12) {
                if !activeFilterDescriptions.isEmpty {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(t("Local export filters are active"), systemImage: "line.3.horizontal.decrease.circle.fill")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.orange)
                            Text(activeFilterDescriptions.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(t("Clear")) {
                            resetLocalFilters()
                        }
                        .font(.caption.weight(.medium))
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
                        ForEach(AppExportContentRequirement.allCases, id: \.self) { requirement in
                            filterChip(
                                title: contentRequirementTitle(requirement),
                                isSelected: selectedContentRequirements.contains(requirement)
                            ) {
                                toggleContentRequirement(requirement)
                            }
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
                                ) {
                                    toggleActivityType(activityType)
                                }
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
                                TextField(t("Min lat"), text: $boundsMinLat)
                                    .textFieldStyle(.roundedBorder)
                                TextField(t("Max lat"), text: $boundsMaxLat)
                                    .textFieldStyle(.roundedBorder)
                            }
                            HStack(spacing: 12) {
                                TextField(t("Min lon"), text: $boundsMinLon)
                                    .textFieldStyle(.roundedBorder)
                                TextField(t("Max lon"), text: $boundsMaxLon)
                                    .textFieldStyle(.roundedBorder)
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
                    Label(t("The current imported-history filters hide all day rows. Saved Live Tracks can still be exported separately."), systemImage: "line.3.horizontal.decrease.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var globalRangeSection: some View {
        Section {
            AppHistoryDateRangeControl(
                filter: $session.historyDateRangeFilter,
                showsExportHint: true
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private func previewSection(selection: ExportSelectionState, summaries: [DaySummary]) -> some View {
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

        Section(t("Preview")) {
            VStack(alignment: .leading, spacing: 12) {
                if previewData.hasMapContent {
                    if #available(iOS 17.0, macOS 14.0, *) {
                        AppExportPreviewMapView(previewData: previewData)
                    } else {
                        Label(t("Map preview requires a newer Apple platform version, but the export summary below still reflects the current selection."), systemImage: "map")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    MapSectionSupplementaryView(presentation: presentation)
                } else {
                    Label(t("The current selection has no routes with exportable geometry to preview."), systemImage: "map")
                        .font(.subheadline.weight(.medium))
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
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func exportBar(selection: ExportSelectionState, summaries: [DaySummary]) -> some View {
        VStack(spacing: 0) {
            Divider()
            VStack(spacing: 12) {
                if ExportFormat.allCases.count > 1 {
                    Picker(t("Format"), selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases) { format in
                            Label(t(format.rawValue), systemImage: format.systemImage).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: selectedFormat.systemImage)
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(t(selectedFormat.rawValue))
                                .font(.subheadline.weight(.medium))
                            Text(t(selectedFormat.description))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }

                if selectedFormat == .csv {
                    Label(t("CSV always exports the visible table rows for visits, activities and routes."), systemImage: "tablecells")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Picker(t("Mode"), selection: $selectedMode) {
                        ForEach(ExportMode.allCases) { mode in
                            Text(t(mode.rawValue)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                exportButton(selection: selection, summaries: summaries)

                if isExportReady(selection: selection, summaries: summaries) {
                    Label(
                        ExportPresentation.filenameMessage(
                            selection: selection,
                            summaries: summaries,
                            recordedTracks: liveLocation.recordedTracks,
                            format: selectedFormat,
                            mode: effectiveExportMode,
                            language: preferences.appLanguage
                        ),
                        systemImage: "doc"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Label(
                        ExportPresentation.helperMessage(
                            importedExport: session.content?.export,
                            selection: selection,
                            recordedTracks: liveLocation.recordedTracks,
                            format: selectedFormat,
                            queryFilter: effectiveQueryFilter,
                            mode: effectiveExportMode,
                            language: preferences.appLanguage
                        ),
                        systemImage: "info.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .background(Color.secondary.opacity(0.05))
        }
    }

    @ViewBuilder
    private func exportButton(selection: ExportSelectionState, summaries: [DaySummary]) -> some View {
        Button {
            prepareExport(selection: selection, summaries: summaries)
        } label: {
            Label(
                ExportPresentation.buttonTitle(
                    importedExport: session.content?.export,
                    selection: selection,
                    recordedTracks: liveLocation.recordedTracks,
                    format: selectedFormat,
                    queryFilter: effectiveQueryFilter,
                    mode: effectiveExportMode,
                    language: preferences.appLanguage
                ),
                systemImage: "square.and.arrow.up"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!isExportReady(selection: selection, summaries: summaries))
        .accessibilityIdentifier("export.action.primary")
    }

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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private func isExportReady(selection: ExportSelectionState, summaries: [DaySummary]) -> Bool {
        switch ExportPresentation.readiness(
            importedExport: session.content?.export,
            selection: selection,
            recordedTracks: liveLocation.recordedTracks,
            queryFilter: effectiveQueryFilter,
            mode: effectiveExportMode
        ) {
        case .ready:
            return true
        case .nothingSelected, .noExportableContent:
            return false
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

    private func selectedRecordedTracks(selection: ExportSelectionState) -> [RecordedTrack] {
        liveLocation.recordedTracks.filter { selection.isSelected(recordedTrackID: $0.id) }
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

    private func customRouteSelectionBadgeTitle(_ explicitDayCount: Int) -> String {
        if preferences.appLanguage.isGerman {
            return "\(explicitDayCount) \(explicitDayCount == 1 ? "Tag mit Routenauswahl" : "Tage mit Routenauswahl")"
        }
        return "\(explicitDayCount) day\(explicitDayCount == 1 ? "" : "s") with custom routes"
    }

    private func selectionSummaryTitle(snapshot: ExportSelectionSnapshot) -> String {
        if snapshot.selectedSourceCount == 0 {
            return preferences.appLanguage.isGerman ? "Inhalt für den Export auswählen" : "Select content for export"
        }
        if snapshot.selectedDayCount > 0 && snapshot.selectedRecordedTrackCount == 0 {
            return preferences.appLanguage.isGerman
                ? "\(snapshot.selectedDayCount) importierte \(snapshot.selectedDayCount == 1 ? "Tag" : "Tage") ausgewählt"
                : "\(snapshot.selectedDayCount) imported day\(snapshot.selectedDayCount == 1 ? "" : "s") selected"
        }
        if snapshot.selectedDayCount == 0 {
            return preferences.appLanguage.isGerman
                ? "\(snapshot.selectedRecordedTrackCount) gespeicherte \(snapshot.selectedRecordedTrackCount == 1 ? "Live-Track" : "Live-Tracks") ausgewählt"
                : "\(snapshot.selectedRecordedTrackCount) saved live track\(snapshot.selectedRecordedTrackCount == 1 ? "" : "s") selected"
        }
        return preferences.appLanguage.isGerman
            ? "\(snapshot.selectedDayCount) importierte \(snapshot.selectedDayCount == 1 ? "Tag" : "Tage") + \(snapshot.selectedRecordedTrackCount) gespeicherte \(snapshot.selectedRecordedTrackCount == 1 ? "Live-Track" : "Live-Tracks") ausgewählt"
            : "\(snapshot.selectedDayCount) imported day\(snapshot.selectedDayCount == 1 ? "" : "s") + \(snapshot.selectedRecordedTrackCount) saved live track\(snapshot.selectedRecordedTrackCount == 1 ? "" : "s") selected"
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

        let content: String
        switch selectedFormat {
        case .gpx:
            content = GPXBuilder.build(from: exportDays, mode: effectiveExportMode)
        case .kml:
            content = KMLBuilder.build(from: exportDays, mode: effectiveExportMode)
        case .geoJSON:
            content = GeoJSONBuilder.build(from: exportDays, mode: effectiveExportMode)
        case .csv:
            content = CSVBuilder.build(from: exportDays)
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
        let validIDs = Set(validTracks.map(\.id))
        let invalidIDs = session.exportSelection.selectedRecordedTrackIDs.subtracting(validIDs)
        for id in invalidIDs {
            session.exportSelection.toggleRecordedTrack(id)
        }
    }

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
        session.content?.daySummaries(applying: effectiveQueryFilter) ?? []
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
        guard hasImportedExport else {
            return nil
        }

        let baseFilter = globalRangeQueryFilter ?? AppExportQueryFilter()
        let fromDate = mergedLowerBound(base: baseFilter.fromDate, local: selectedFromDate)
        let toDate = mergedUpperBound(base: baseFilter.toDate, local: selectedToDate)
        let maxAccuracyM = mergedMaxAccuracy(base: baseFilter.maxAccuracyM, local: selectedAccuracyFilter.maxAccuracyM)
        let requiredContent = baseFilter.requiredContent.union(selectedContentRequirements)
        let activityTypes = mergedActivityTypes(base: baseFilter.activityTypes, local: selectedActivityTypes)
        let spatialFilter = mergedSpatialFilter(base: baseFilter.spatialFilter, local: localSpatialFilter)

        let merged = AppExportQueryFilter(
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

        return merged
    }

    private var activeFilterDescriptions: [String] {
        var descriptions: [String] = []
        if !selectedFromDate.isEmpty {
            descriptions.append("\(t("From")): \(selectedFromDate)")
        }
        if !selectedToDate.isEmpty {
            descriptions.append("\(t("To")): \(selectedToDate)")
        }
        if let maxAccuracyM = selectedAccuracyFilter.maxAccuracyM {
            descriptions.append("\(t("Maximum accuracy")): \(Int(maxAccuracyM))m")
        }
        if !selectedContentRequirements.isEmpty {
            descriptions.append("\(t("Required imported content")): \(selectedContentRequirements.map(contentRequirementTitle).sorted().joined(separator: ", "))")
        }
        if !selectedActivityTypes.isEmpty {
            descriptions.append("\(t("Activity types")): \(selectedActivityTypes.map(activityTypeTitle).sorted().joined(separator: ", "))")
        }
        if let localAreaFilterDescription {
            descriptions.append(localAreaFilterDescription)
        }
        return descriptions
    }

    private func resetLocalFilters() {
        selectedFromDate = ""
        selectedToDate = ""
        selectedAccuracyFilter = .any
        selectedContentRequirements = []
        selectedActivityTypes = []
        selectedAreaFilter = .none
        boundsMinLat = ""
        boundsMaxLat = ""
        boundsMinLon = ""
        boundsMaxLon = ""
        polygonCoordinatesText = ""
    }

    private func clearInsightsDrilldown() {
        session.activeDrilldownFilter = nil
        session.exportSelection.clearAllDays()
        for date in Array(session.exportSelection.routeSelections.keys) {
            session.exportSelection.clearRouteSelection(day: date)
        }
    }

    private func normalizeDateFilterBounds() {
        guard !selectedFromDate.isEmpty, !selectedToDate.isEmpty, selectedFromDate > selectedToDate else {
            return
        }
        selectedToDate = selectedFromDate
    }

    private func pruneInvalidImportedDaySelection(summaries: [DaySummary]) {
        let validDates = Set(summaries.map(\.date))
        let invalidDates = session.exportSelection.selectedDates.subtracting(validDates)
        for date in invalidDates {
            session.exportSelection.toggle(date)
        }
    }

    private func mergedLowerBound(base: String?, local: String) -> String? {
        guard !local.isEmpty else {
            return base
        }
        guard let base else {
            return local
        }
        return max(base, local)
    }

    private func mergedUpperBound(base: String?, local: String) -> String? {
        guard !local.isEmpty else {
            return base
        }
        guard let base else {
            return local
        }
        return min(base, local)
    }

    private func mergedMaxAccuracy(base: Double?, local: Double?) -> Double? {
        switch (base, local) {
        case let (base?, local?):
            return min(base, local)
        case let (base?, nil):
            return base
        case let (nil, local?):
            return local
        case (nil, nil):
            return nil
        }
    }

    private func mergedActivityTypes(base: Set<String>, local: Set<String>) -> Set<String> {
        if base.isEmpty {
            return local
        }
        if local.isEmpty {
            return base
        }
        return base.intersection(local)
    }

    private func mergedSpatialFilter(base: ExportSpatialFilter?, local: ExportSpatialFilter?) -> ExportSpatialFilter? {
        switch (base, local) {
        case let (base?, local?):
            return .all([base, local])
        case let (base?, nil):
            return base
        case let (nil, local?):
            return local
        case (nil, nil):
            return nil
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
        case .visits:
            return "Visits"
        case .activities:
            return "Activities"
        case .paths:
            return "Routes"
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
            else {
                return nil
            }
            return .bounds(
                ExportCoordinateBounds(
                    minLat: minLat,
                    maxLat: maxLat,
                    minLon: minLon,
                    maxLon: maxLon
                )
            )
        case .polygon:
            let coordinates = parsePolygonCoordinates(polygonCoordinatesText)
            guard coordinates.count >= 3 else {
                return nil
            }
            return .polygon(coordinates)
        }
    }

    private var localAreaFilterDescription: String? {
        switch selectedAreaFilter {
        case .none:
            return nil
        case .bounds:
            return localSpatialFilter == nil ? nil : "\(t("Area")): \(t("Rectangle"))"
        case .polygon:
            return localSpatialFilter == nil ? nil : "\(t("Area")): \(t("Custom Shape"))"
        }
    }

    private var spatialFilterValidationMessage: String? {
        switch selectedAreaFilter {
        case .none:
            return nil
        case .bounds:
            guard hasBoundsInput else {
                return nil
            }
            return localSpatialFilter == nil ? "Enter valid min/max latitude and longitude values to activate the rectangle filter." : nil
        case .polygon:
            let trimmed = polygonCoordinatesText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return nil
            }
            return localSpatialFilter == nil ? "Provide at least three valid `lat,lon` lines to activate the custom shape filter." : nil
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
        guard !normalized.isEmpty else {
            return nil
        }
        return Double(normalized)
    }

    private func parsePolygonCoordinates(_ value: String) -> [ExportCoordinate] {
        value
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> ExportCoordinate? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else {
                    return nil
                }
                let parts = trimmed.split(separator: ",", omittingEmptySubsequences: false)
                guard parts.count == 2,
                      let lat = parseCoordinate(String(parts[0])),
                      let lon = parseCoordinate(String(parts[1])) else {
                    return nil
                }
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
        case .foregroundWhileInUse:
            return t("Foreground recording")
        case .backgroundAlways:
            return t("Background recording")
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
