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

public struct AppExportView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Binding var session: AppSessionState
    @ObservedObject private var liveLocation: LiveLocationFeatureModel
    @State private var selectedFormat: ExportFormat = .gpx
    @State private var selectedFromDate: String = ""
    @State private var selectedToDate: String = ""
    @State private var selectedAccuracyFilter: ExportAccuracyFilterOption = .any
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

        VStack(spacing: 0) {
            List {
                selectionSummarySection(selection: selection, summaries: summaries)

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

            exportBar(selection: selection, summaries: summaries)
        }
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
        .alert("Export Failed", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
        .onChange(of: liveLocation.recordedTracks) { _, tracks in
            pruneInvalidRecordedTrackSelection(validTracks: tracks)
        }
        .onChange(of: selectedFromDate) { _, _ in
            normalizeDateFilterBounds()
            pruneInvalidImportedDaySelection(summaries: filteredSummaries)
        }
        .onChange(of: selectedToDate) { _, _ in
            normalizeDateFilterBounds()
            pruneInvalidImportedDaySelection(summaries: filteredSummaries)
        }
        .onChange(of: selectedAccuracyFilter) { _, _ in
            pruneInvalidImportedDaySelection(summaries: filteredSummaries)
        }
        .onChange(of: session.content?.sourceSummary) { _, _ in
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
            }
        } header: {
            HStack {
                Text("Days")
                Spacer()
                if selection.selectedDayCount == summaries.count {
                    Button("Deselect All") {
                        session.exportSelection.clearAllDays()
                    }
                    .font(.subheadline)
                } else {
                    Button("Select All") {
                        session.exportSelection.selectAll(from: summaries.map(\.date))
                    }
                    .font(.subheadline)
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
                Text("Saved Live Tracks")
                Spacer()
                if selection.selectedRecordedTrackCount == liveLocation.recordedTracks.count {
                    Button("Deselect All") {
                        session.exportSelection.clearRecordedTracks()
                    }
                    .font(.subheadline)
                } else {
                    Button("Select All") {
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
                    if hasRoutes {
                        Label("\(summary.pathCount) route\(summary.pathCount == 1 ? "" : "s")", systemImage: "location.north.line")
                            .foregroundStyle(.secondary)
                    }
                    if summary.totalPathDistanceM > 0 {
                        Label(formatDistance(summary.totalPathDistanceM, unit: preferences.distanceUnit), systemImage: "ruler")
                            .foregroundStyle(.secondary)
                    }
                    if !hasRoutes {
                        Label("No route geometry", systemImage: "exclamationmark.circle")
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
        .accessibilityLabel("\(AppDateDisplay.mediumDate(summary.date)), \(summary.pathCount) routes")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
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
                    Label("\(track.pointCount) points", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
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
        .accessibilityLabel("\(savedTrackTitle(track)), \(track.pointCount) points")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func selectionSummarySection(selection: ExportSelectionState, summaries: [DaySummary]) -> some View {
        let snapshot = ExportSelectionContent.snapshot(
            selection: selection,
            summaries: summaries,
            recordedTracks: liveLocation.recordedTracks
        )

        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectionSummaryTitle(snapshot: snapshot))
                            .font(.subheadline.weight(.semibold))
                        Text(ExportPresentation.helperMessage(
                            selection: selection,
                            summaries: summaries,
                            recordedTracks: liveLocation.recordedTracks,
                            format: selectedFormat
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
                            title: "\(snapshot.selectedSourceCount) \(snapshot.selectedSourceCount == 1 ? "source" : "sources")",
                            systemImage: "tray.full"
                        )
                        exportSummaryBadge(
                            title: "\(snapshot.routeCount) \(snapshot.routeCount == 1 ? "route" : "routes")",
                            systemImage: "location.north.line"
                        )
                        if selectedDistance(selection: selection, summaries: summaries) > 0 {
                            exportSummaryBadge(
                                title: formatDistance(selectedDistance(selection: selection, summaries: summaries), unit: preferences.distanceUnit),
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
        Section("Filter Imported History") {
            VStack(alignment: .leading, spacing: 12) {
                if !activeFilterDescriptions.isEmpty {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Local export filters are active", systemImage: "line.3.horizontal.decrease.circle.fill")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.orange)
                            Text(activeFilterDescriptions.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Clear") {
                            resetLocalFilters()
                        }
                        .font(.caption.weight(.medium))
                    }
                } else {
                    Text("Limit imported history by date window or maximum accuracy. Saved Live Tracks stay unaffected by these local export filters.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !dateOptions.isEmpty {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("From")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            Picker("From", selection: $selectedFromDate) {
                                Text("Any").tag("")
                                ForEach(dateOptions, id: \.self) { date in
                                    Text(AppDateDisplay.mediumDate(date)).tag(date)
                                }
                            }
                            .labelsHidden()
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("To")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            Picker("To", selection: $selectedToDate) {
                                Text("Any").tag("")
                                ForEach(dateOptions, id: \.self) { date in
                                    Text(AppDateDisplay.mediumDate(date)).tag(date)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Maximum accuracy")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Picker("Maximum accuracy", selection: $selectedAccuracyFilter) {
                        ForEach(ExportAccuracyFilterOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if filteredSummaries.isEmpty {
                    Label("The current imported-history filters hide all day rows. Saved Live Tracks can still be exported separately.", systemImage: "line.3.horizontal.decrease.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func previewSection(selection: ExportSelectionState, summaries: [DaySummary]) -> some View {
        let previewData = ExportPreviewDataBuilder.previewData(
            importedExport: session.content?.export,
            selection: selection,
            recordedTracks: liveLocation.recordedTracks,
            queryFilter: effectiveQueryFilter
        )
        let presentation = MapPresentation.exportPreview(previewData, unit: preferences.distanceUnit)

        Section("Preview") {
            VStack(alignment: .leading, spacing: 12) {
                if previewData.hasMapContent {
                    if #available(iOS 17.0, macOS 14.0, *) {
                        AppExportPreviewMapView(previewData: previewData)
                    } else {
                        Label("Map preview requires a newer Apple platform version, but the export summary below still reflects the current selection.", systemImage: "map")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    MapSectionSupplementaryView(presentation: presentation)
                } else {
                    Label("The current selection has no routes with exportable geometry to preview.", systemImage: "map")
                        .font(.subheadline.weight(.medium))
                    Text(ExportPresentation.helperMessage(
                        selection: selection,
                        summaries: summaries,
                        recordedTracks: liveLocation.recordedTracks,
                        format: selectedFormat
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
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases) { format in
                            Label(format.rawValue, systemImage: format.systemImage).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: selectedFormat.systemImage)
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(selectedFormat.rawValue)
                                .font(.subheadline.weight(.medium))
                            Text(selectedFormat.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }

                exportButton(selection: selection, summaries: summaries)

                if isExportReady(selection: selection, summaries: summaries) {
                    Label(
                        ExportPresentation.filenameMessage(
                            selection: selection,
                            summaries: summaries,
                            recordedTracks: liveLocation.recordedTracks,
                            format: selectedFormat
                        ),
                        systemImage: "doc"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Label(
                        ExportPresentation.helperMessage(
                            selection: selection,
                            summaries: summaries,
                            recordedTracks: liveLocation.recordedTracks,
                            format: selectedFormat
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
                    selection: selection,
                    summaries: summaries,
                    recordedTracks: liveLocation.recordedTracks,
                    format: selectedFormat
                ),
                systemImage: "square.and.arrow.up"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!isExportReady(selection: selection, summaries: summaries))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.up.trianglebadge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Nothing to Export")
                .font(.headline)
            Text("Import a location history file or save a live track first to enable export.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private func isExportReady(selection: ExportSelectionState, summaries: [DaySummary]) -> Bool {
        switch ExportPresentation.readiness(
            selection: selection,
            summaries: summaries,
            recordedTracks: liveLocation.recordedTracks
        ) {
        case .ready:
            return true
        case .nothingSelected, .noRoutesSelected:
            return false
        }
    }

    private func selectedDistance(selection: ExportSelectionState, summaries: [DaySummary]) -> Double {
        let dayDistance = summaries
            .filter { selection.isSelected($0.date) }
            .reduce(0) { $0 + $1.totalPathDistanceM }
        let trackDistance = selectedRecordedTracks(selection: selection)
            .reduce(0) { $0 + $1.distanceM }
        return dayDistance + trackDistance
    }

    private func selectedRecordedTracks(selection: ExportSelectionState) -> [RecordedTrack] {
        liveLocation.recordedTracks.filter { selection.isSelected(recordedTrackID: $0.id) }
    }

    private func exportFilenamePreview(selection: ExportSelectionState, summaries: [DaySummary]) -> String {
        ExportPresentation.suggestedFilename(
            selection: selection,
            summaries: summaries,
            recordedTracks: liveLocation.recordedTracks,
            format: selectedFormat
        )
    }

    private func selectionSummaryTitle(snapshot: ExportSelectionSnapshot) -> String {
        if snapshot.selectedSourceCount == 0 {
            return "Select routes for export"
        }
        if snapshot.selectedDayCount > 0 && snapshot.selectedRecordedTrackCount == 0 {
            return "\(snapshot.selectedDayCount) imported day\(snapshot.selectedDayCount == 1 ? "" : "s") selected"
        }
        if snapshot.selectedDayCount == 0 {
            return "\(snapshot.selectedRecordedTrackCount) saved live track\(snapshot.selectedRecordedTrackCount == 1 ? "" : "s") selected"
        }
        return "\(snapshot.selectedDayCount) imported day\(snapshot.selectedDayCount == 1 ? "" : "s") + \(snapshot.selectedRecordedTrackCount) saved live track\(snapshot.selectedRecordedTrackCount == 1 ? "" : "s") selected"
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
        let exportDays = ExportSelectionContent.exportDays(
            importedExport: session.content?.export,
            selection: selection,
            recordedTracks: liveLocation.recordedTracks,
            queryFilter: effectiveQueryFilter
        )

        guard !exportDays.isEmpty else {
            exportError = "The current selection contains no exportable route geometry."
            return
        }

        let content: String
        switch selectedFormat {
        case .gpx:
            content = GPXBuilder.build(from: exportDays)
        case .kml:
            content = KMLBuilder.build(from: exportDays)
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

    private var filteredSummaries: [DaySummary] {
        guard let export = session.content?.export else {
            return []
        }
        return AppExportQueries.daySummaries(from: export, applying: effectiveQueryFilter)
    }

    private var dateOptions: [String] {
        session.daySummaries.map(\.date).sorted()
    }

    private var effectiveQueryFilter: AppExportQueryFilter? {
        guard hasImportedExport else {
            return nil
        }

        let baseFilter = session.content.map { AppExportQueryFilter(exportFilters: $0.export.meta.filters) } ?? AppExportQueryFilter()
        let fromDate = selectedFromDate.isEmpty ? baseFilter.fromDate : selectedFromDate
        let toDate = selectedToDate.isEmpty ? baseFilter.toDate : selectedToDate
        let maxAccuracyM = selectedAccuracyFilter.maxAccuracyM ?? baseFilter.maxAccuracyM

        let merged = AppExportQueryFilter(
            fromDate: fromDate,
            toDate: toDate,
            year: baseFilter.year,
            month: baseFilter.month,
            weekday: baseFilter.weekday,
            limit: baseFilter.limit,
            days: baseFilter.days,
            requiredContent: baseFilter.requiredContent,
            maxAccuracyM: maxAccuracyM,
            activityTypes: baseFilter.activityTypes,
            minGapMin: baseFilter.minGapMin,
            spatialFilter: baseFilter.spatialFilter
        )

        return merged
    }

    private var activeFilterDescriptions: [String] {
        var descriptions: [String] = []
        if !selectedFromDate.isEmpty {
            descriptions.append("From: \(selectedFromDate)")
        }
        if !selectedToDate.isEmpty {
            descriptions.append("To: \(selectedToDate)")
        }
        if let maxAccuracyM = selectedAccuracyFilter.maxAccuracyM {
            descriptions.append("Max accuracy: \(Int(maxAccuracyM))m")
        }
        return descriptions
    }

    private func resetLocalFilters() {
        selectedFromDate = ""
        selectedToDate = ""
        selectedAccuracyFilter = .any
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

    private func savedTrackTitle(_ track: RecordedTrack) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: track.startedAt)
    }

    private func captureModeLabel(for track: RecordedTrack) -> String {
        switch track.captureMode {
        case .foregroundWhileInUse:
            return "Foreground recording"
        case .backgroundAlways:
            return "Background recording"
        }
    }
}

#endif
