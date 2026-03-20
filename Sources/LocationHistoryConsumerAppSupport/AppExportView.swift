#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumer
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

// MARK: - Export Format

/// Supported export formats. Architecture is ready for additional cases.
public enum ExportFormat: String, CaseIterable, Identifiable {
    case gpx = "GPX"

    public var id: String { rawValue }
    public var fileExtension: String {
        switch self { case .gpx: return "gpx" }
    }
    public var description: String {
        switch self { case .gpx: return "GPS Exchange Format – compatible with most navigation and mapping apps." }
    }
    public var systemImage: String {
        switch self { case .gpx: return "location.north.line.fill" }
    }
}

// MARK: - Export View

/// The Export tab / sheet content.
///
/// Displays all available days with checkboxes, a format picker,
/// and a button that triggers the system file-export flow.
public struct AppExportView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Binding var session: AppSessionState
    @ObservedObject private var liveLocation: LiveLocationFeatureModel
    @State private var selectedFormat: ExportFormat = .gpx
    @State private var isExporting = false
    @State private var exportDocument: GPXDocument?
    @State private var exportError: String?
    @State private var selectedRecordedTrackIDs: Set<UUID> = []

    public init(session: Binding<AppSessionState>, liveLocation: LiveLocationFeatureModel) {
        self._session = session
        self._liveLocation = ObservedObject(wrappedValue: liveLocation)
    }

    // MARK: - Body

    public var body: some View {
        let summaries = session.daySummaries
        if summaries.isEmpty {
            emptyState
        } else {
            exportContent(summaries: summaries)
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func exportContent(summaries: [DaySummary]) -> some View {
        let selection = session.exportSelection
        VStack(spacing: 0) {
            List {
                selectionSummarySection(selection: selection, summaries: summaries)

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
                        if selection.count == summaries.count {
                            Button("Deselect All") {
                                session.exportSelection.clearAll()
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

                if !liveLocation.recordedTracks.isEmpty {
                    Section {
                        ForEach(liveLocation.recordedTracks) { track in
                            recordedTrackRow(track: track, isSelected: selectedRecordedTrackIDs.contains(track.id))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    toggleRecordedTrack(track.id)
                                }
                        }
                    } header: {
                        HStack {
                            Text("Saved Live Tracks")
                            Spacer()
                            if selectedRecordedTrackIDs.count == liveLocation.recordedTracks.count {
                                Button("Deselect All") {
                                    selectedRecordedTrackIDs.removeAll()
                                }
                                .font(.subheadline)
                            } else {
                                Button("Select All") {
                                    selectedRecordedTrackIDs = Set(liveLocation.recordedTracks.map(\.id))
                                }
                                .font(.subheadline)
                            }
                        }
                    }
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
            contentType: .gpx,
            defaultFilename: exportDocument?.suggestedFilename ?? "lh2gpx-export.gpx"
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
            let validIDs = Set(tracks.map(\.id))
            selectedRecordedTrackIDs = selectedRecordedTrackIDs.intersection(validIDs)
        }
    }

    // MARK: - Day Row

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
                        Label("No GPX route data", systemImage: "exclamationmark.circle")
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
                    Text("Local recording")
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
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectionSummaryTitle(selection: selection))
                            .font(.subheadline.weight(.semibold))
                        Text(selectionSummaryMessage(selection: selection, summaries: summaries))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !selection.isEmpty || !selectedRecordedTrackIDs.isEmpty {
                        Text(exportFilenamePreview(selection: selection))
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(Capsule())
                    }
                }

                if !selection.isEmpty {
                    HStack(spacing: 10) {
                        exportSummaryBadge(
                            title: "\(selectedRouteDayCount(selection: selection, summaries: summaries)) route day\(selectedRouteDayCount(selection: selection, summaries: summaries) == 1 ? "" : "s")",
                            systemImage: "location.north.line"
                        )
                        exportSummaryBadge(
                            title: formatDistance(selectedRouteDistance(selection: selection, summaries: summaries), unit: preferences.distanceUnit),
                            systemImage: "ruler"
                        )
                        if !selectedRecordedTrackIDs.isEmpty {
                            exportSummaryBadge(
                                title: "\(selectedRecordedTrackIDs.count) live track\(selectedRecordedTrackIDs.count == 1 ? "" : "s")",
                                systemImage: "point.topleft.down.curvedto.point.bottomright.up"
                            )
                        }
                    }
                } else if !selectedRecordedTrackIDs.isEmpty {
                    HStack(spacing: 10) {
                        exportSummaryBadge(
                            title: "\(selectedRecordedTrackIDs.count) live track\(selectedRecordedTrackIDs.count == 1 ? "" : "s")",
                            systemImage: "point.topleft.down.curvedto.point.bottomright.up"
                        )
                        exportSummaryBadge(
                            title: formatDistance(selectedRecordedTrackDistance, unit: preferences.distanceUnit),
                            systemImage: "ruler"
                        )
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Export Bar

    @ViewBuilder
    private func exportBar(selection: ExportSelectionState, summaries: [DaySummary]) -> some View {
        let disabledReason = exportDisabledReason(selection: selection, summaries: summaries)
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
                            Text("GPX")
                                .font(.subheadline.weight(.medium))
                            Text(selectedFormat.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }

                exportButton(selection: selection, summaries: summaries)

                if let disabledReason {
                    Label(disabledReason, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if !selection.isEmpty || !selectedRecordedTrackIDs.isEmpty {
                    Label("Suggested file name: \(exportFilenamePreview(selection: selection))", systemImage: "doc")
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
        let hasRoutes = selectedDaysHaveRoutes(selection: selection, summaries: summaries) || hasSelectedRecordedTracks
        let label: String = {
            let dayCount = selection.count
            let trackCount = selectedRecordedTrackIDs.count
            if dayCount == 0 && trackCount == 0 { return "Select routes or live tracks to export" }
            if dayCount > 0 && trackCount == 0 {
                return "Export \(dayCount) \(dayCount == 1 ? "day" : "days") as \(selectedFormat.rawValue)"
            }
            if dayCount == 0 {
                return "Export \(trackCount) \(trackCount == 1 ? "live track" : "live tracks") as \(selectedFormat.rawValue)"
            }
            return "Export \(dayCount) day\(dayCount == 1 ? "" : "s") + \(trackCount) live track\(trackCount == 1 ? "" : "s")"
        }()

        Button {
            prepareExport(selection: selection, summaries: summaries)
        } label: {
            Label(label, systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled((selection.isEmpty && selectedRecordedTrackIDs.isEmpty) || !hasRoutes)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.up.trianglebadge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Nothing to Export")
                .font(.headline)
            Text("Import a location history file first to enable export.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    // MARK: - Helpers

    private func selectedDaysHaveRoutes(selection: ExportSelectionState, summaries: [DaySummary]) -> Bool {
        summaries
            .filter { selection.isSelected($0.date) }
            .contains { $0.pathCount > 0 }
    }

    private var hasSelectedRecordedTracks: Bool {
        !selectedRecordedTracks.isEmpty
    }

    private var selectedRecordedTracks: [RecordedTrack] {
        liveLocation.recordedTracks.filter { selectedRecordedTrackIDs.contains($0.id) }
    }

    private var selectedRecordedTrackDistance: Double {
        selectedRecordedTracks.reduce(0) { $0 + $1.distanceM }
    }

    private func selectedRouteDayCount(selection: ExportSelectionState, summaries: [DaySummary]) -> Int {
        summaries
            .filter { selection.isSelected($0.date) && $0.pathCount > 0 }
            .count
    }

    private func selectedRouteDistance(selection: ExportSelectionState, summaries: [DaySummary]) -> Double {
        summaries
            .filter { selection.isSelected($0.date) }
            .reduce(0) { $0 + $1.totalPathDistanceM }
    }

    private func exportDisabledReason(selection: ExportSelectionState, summaries: [DaySummary]) -> String? {
        if selection.isEmpty && selectedRecordedTrackIDs.isEmpty {
            return "Select at least one day or saved live track to enable GPX export."
        }
        if !selectedDaysHaveRoutes(selection: selection, summaries: summaries) && !hasSelectedRecordedTracks {
            return "The current selection contains no routes with GPS points and no saved live tracks, so no GPX file can be generated."
        }
        return nil
    }

    private func exportFilenamePreview(selection: ExportSelectionState) -> String {
        let selectedDates = Array(selection.selectedDates)
        let selectedTrackCount = selectedRecordedTrackIDs.count
        if selectedDates.isEmpty && selectedTrackCount == 0 {
            return GPXBuilder.suggestedFilename(for: [])
        }
        if !selectedDates.isEmpty && selectedTrackCount == 0 {
            return GPXBuilder.suggestedFilename(for: selectedDates)
        }
        if selectedDates.isEmpty {
            if let firstTrack = selectedRecordedTracks.first, selectedTrackCount == 1 {
                return "lh2gpx-live-track-\(firstTrack.dayKey).gpx"
            }
            return "lh2gpx-live-tracks.gpx"
        }
        let baseName = GPXBuilder.suggestedFilename(for: selectedDates).replacingOccurrences(of: ".gpx", with: "")
        return "\(baseName)_plus-live-tracks.gpx"
    }

    private func selectionSummaryTitle(selection: ExportSelectionState) -> String {
        let dayCount = selection.count
        let trackCount = selectedRecordedTrackIDs.count
        if dayCount == 0 && trackCount == 0 {
            return "Select routes for GPX export"
        }
        if dayCount > 0 && trackCount == 0 {
            return "\(dayCount) day\(dayCount == 1 ? "" : "s") selected"
        }
        if dayCount == 0 {
            return "\(trackCount) live track\(trackCount == 1 ? "" : "s") selected"
        }
        return "\(dayCount) day\(dayCount == 1 ? "" : "s") + \(trackCount) live track\(trackCount == 1 ? "" : "s") selected"
    }

    private func selectionSummaryMessage(selection: ExportSelectionState, summaries: [DaySummary]) -> String {
        if selection.isEmpty && selectedRecordedTrackIDs.isEmpty {
            return "Pick one or more imported days with recorded routes or include saved live tracks. The suggested filename updates automatically from your selection."
        }

        let routeDays = selectedRouteDayCount(selection: selection, summaries: summaries)
        let liveTracks = selectedRecordedTrackIDs.count

        if routeDays == 0 && liveTracks == 0 {
            return "Selected days are tracked for export, but none of them currently contain route points that GPX can write."
        }

        if routeDays == 0 {
            return "GPX will include \(liveTracks) selected saved live track\(liveTracks == 1 ? "" : "s")."
        }

        if liveTracks == 0 {
            return "GPX will include routes from \(routeDays) selected day\(routeDays == 1 ? "" : "s")."
        }

        return "GPX will include routes from \(routeDays) day\(routeDays == 1 ? "" : "s") plus \(liveTracks) saved live track\(liveTracks == 1 ? "" : "s")."
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
        guard let export = session.content?.export else { return }
        let selectedDates = selection.selectedDates
        let days = AppExportQueries.days(in: export).filter { selectedDates.contains($0.date) }
        let additionalTracks = selectedRecordedTracks.map(gpxTrack(from:))
        let gpxString = GPXBuilder.build(from: days, additionalTracks: additionalTracks)
        let filename = exportFilenamePreview(selection: selection)
        exportDocument = GPXDocument(content: gpxString, suggestedFilename: filename)
        isExporting = true
    }

    private func toggleRecordedTrack(_ id: UUID) {
        if selectedRecordedTrackIDs.contains(id) {
            selectedRecordedTrackIDs.remove(id)
        } else {
            selectedRecordedTrackIDs.insert(id)
        }
    }

    private func savedTrackTitle(_ track: RecordedTrack) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: track.startedAt)
    }

    private func gpxTrack(from track: RecordedTrack) -> GPXTrack {
        GPXTrack(
            name: "Saved Live Track – \(savedTrackTitle(track))",
            type: "foreground_while_in_use",
            points: track.points.map {
                GPXTrackPoint(
                    latitude: $0.latitude,
                    longitude: $0.longitude,
                    time: ISO8601DateFormatter().string(from: $0.timestamp)
                )
            }
        )
    }
}

#endif
