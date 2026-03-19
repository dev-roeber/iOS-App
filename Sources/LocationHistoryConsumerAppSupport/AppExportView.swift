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
    case kml = "KML"

    public var id: String { rawValue }
    public var fileExtension: String {
        switch self {
        case .gpx: return "gpx"
        case .kml: return "kml"
        }
    }
    public var description: String {
        switch self {
        case .gpx:
            return "GPS Exchange Format – compatible with most navigation and mapping apps."
        case .kml:
            return "Keyhole Markup Language – useful for Google Earth and map viewers that prefer KML."
        }
    }
    public var systemImage: String {
        switch self {
        case .gpx: return "location.north.line.fill"
        case .kml: return "globe.americas.fill"
        }
    }
    #if canImport(UniformTypeIdentifiers)
    public var contentType: UTType {
        switch self {
        case .gpx: return .gpx
        case .kml: return .kml
        }
    }
    #endif
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
    @State private var exportDocument: ExportDocument?
    @State private var exportError: String?

    public init(session: Binding<AppSessionState>, liveLocation: LiveLocationFeatureModel) {
        self._session = session
        self._liveLocation = ObservedObject(wrappedValue: liveLocation)
    }

    // MARK: - Body

    public var body: some View {
        let summaries = session.daySummaries
        let recordedTracks = liveLocation.recordedTracks
        if summaries.isEmpty && recordedTracks.isEmpty {
            emptyState
        } else {
            exportContent(summaries: summaries, recordedTracks: recordedTracks)
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func exportContent(summaries: [DaySummary], recordedTracks: [RecordedTrack]) -> some View {
        let selection = session.exportSelection
        let previewData = ExportPreviewDataBuilder.previewData(
            importedExport: session.content?.export,
            selection: selection,
            recordedTracks: recordedTracks
        )
        VStack(spacing: 0) {
            exportStatusCard(selection: selection, summaries: summaries, recordedTracks: recordedTracks)
                .padding(.horizontal)
                .padding(.top, 12)

            exportPreviewCard(previewData: previewData)
                .padding(.horizontal)
                .padding(.top, 12)

            List {
                if !summaries.isEmpty {
                    Section {
                        ForEach(summaries, id: \.date) { summary in
                            dayRow(summary: summary, isSelected: selection.isSelected(summary.date))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    session.exportSelection.toggle(summary.date)
                                }
                        }
                    } header: {
                        selectionHeader(
                            title: "Imported Days",
                            isAllSelected: selection.selectedDayCount == summaries.count,
                            onSelectAll: {
                                session.exportSelection.selectAll(from: summaries.map(\.date))
                            },
                            onDeselectAll: {
                                session.exportSelection.clearAllDays()
                            }
                        )
                    }
                }

                if !recordedTracks.isEmpty {
                    Section {
                        ForEach(recordedTracks) { track in
                            recordedTrackRow(
                                track: track,
                                isSelected: selection.isSelected(recordedTrackID: track.id)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                session.exportSelection.toggleRecordedTrack(track.id)
                            }
                        }
                    } header: {
                        selectionHeader(
                            title: "Saved Tracks",
                            isAllSelected: selection.selectedRecordedTrackCount == recordedTracks.count,
                            onSelectAll: {
                                session.exportSelection.selectAllRecordedTracks(from: recordedTracks.map(\.id))
                            },
                            onDeselectAll: {
                                session.exportSelection.clearRecordedTracks()
                            }
                        )
                    }
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.inset)
            #endif

            // Bottom bar: format + export button
            exportBar(selection: selection, summaries: summaries, recordedTracks: recordedTracks)
        }
        #if canImport(UniformTypeIdentifiers)
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: selectedFormat.contentType,
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
    }

    // MARK: - Day Row

    @ViewBuilder
    private func dayRow(summary: DaySummary, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .animation(.easeInOut(duration: 0.15), value: isSelected)

            VStack(alignment: .leading, spacing: 2) {
                Text(AppDateDisplay.mediumDate(summary.date))
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 10) {
                    if summary.pathCount > 0 {
                        Label("\(summary.pathCount) route\(summary.pathCount == 1 ? "" : "s")", systemImage: "location.north.line")
                            .foregroundStyle(.secondary)
                    }
                    if summary.totalPathDistanceM > 0 {
                        Label(formatDistance(summary.totalPathDistanceM, unit: preferences.distanceUnit), systemImage: "ruler")
                            .foregroundStyle(.secondary)
                    }
                    if summary.pathCount == 0 {
                        Text("No routes")
                            .foregroundStyle(.tertiary)
                    }
                }
                .font(.caption)
            }

            Spacer()
        }
        .padding(.vertical, 2)
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
                }
                .font(.caption)
            }

            Spacer()
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(savedTrackTitle(track)), \(track.pointCount) points")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Export Bar

    @ViewBuilder
    private func exportBar(
        selection: ExportSelectionState,
        summaries: [DaySummary],
        recordedTracks: [RecordedTrack]
    ) -> some View {
        VStack(spacing: 0) {
            Divider()
            VStack(spacing: 12) {
                // Format picker (single option for now, architecture ready for more)
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

                exportButton(selection: selection, summaries: summaries, recordedTracks: recordedTracks)

                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        ExportPresentation.helperMessage(
                            selection: selection,
                            summaries: summaries,
                            recordedTracks: recordedTracks,
                            format: selectedFormat
                        )
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !selection.isEmpty {
                        Text(
                            ExportPresentation.filenameMessage(
                                selection: selection,
                                summaries: summaries,
                                recordedTracks: recordedTracks,
                                format: selectedFormat
                            )
                        )
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .background(Color.secondary.opacity(0.05))
        }
    }

    @ViewBuilder
    private func exportButton(
        selection: ExportSelectionState,
        summaries: [DaySummary],
        recordedTracks: [RecordedTrack]
    ) -> some View {
        let readiness = ExportPresentation.readiness(
            selection: selection,
            summaries: summaries,
            recordedTracks: recordedTracks
        )
        let label = ExportPresentation.buttonTitle(
            selection: selection,
            summaries: summaries,
            recordedTracks: recordedTracks,
            format: selectedFormat
        )
        let isDisabled: Bool = {
            switch readiness {
            case .nothingSelected, .noRoutesSelected:
                return true
            case .ready:
                return false
            }
        }()

        Button {
            prepareExport(selection: selection, summaries: summaries, recordedTracks: recordedTracks)
        } label: {
            Label(label, systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isDisabled)
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
            Text("Import a location history file or save a live track first to enable export.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func exportPreviewCard(previewData: ExportPreviewData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Route Preview", systemImage: "map")
                .font(.subheadline.weight(.semibold))

            if previewData.hasMapContent {
                Text(previewSummary(previewData))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                #if canImport(MapKit)
                if #available(iOS 17.0, macOS 14.0, *) {
                    AppExportPreviewMapView(previewData: previewData)
                }
                #endif
            } else if previewData.selectedSourceCount == 0 {
                Text("Select imported days or saved tracks to preview the route before exporting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("The current selection has no exportable route geometry yet, so there is nothing to preview on the map.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func exportStatusCard(
        selection: ExportSelectionState,
        summaries: [DaySummary],
        recordedTracks: [RecordedTrack]
    ) -> some View {
        let readiness = ExportPresentation.readiness(
            selection: selection,
            summaries: summaries,
            recordedTracks: recordedTracks
        )
        let snapshot = ExportSelectionContent.snapshot(
            selection: selection,
            summaries: summaries,
            recordedTracks: recordedTracks
        )
        VStack(alignment: .leading, spacing: 6) {
            Label("Export Selection", systemImage: "square.and.arrow.up")
                .font(.subheadline.weight(.semibold))
            switch readiness {
            case .nothingSelected:
                Text("No export items selected yet.")
                    .font(.subheadline)
                Text("Pick one or more imported days or saved tracks below. Export writes route geometry only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case let .noRoutesSelected(selectedSourceCount):
                Text("\(selectedSourceCount) \(selectedSourceCount == 1 ? "item" : "items") selected, but no routes available.")
                    .font(.subheadline)
                Text("Choose an imported day with routes or a saved track with enough GPS points.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case let .ready(selectedSourceCount, _, routeCount, _, _):
                Text("\(selectedSourceCount) \(selectedSourceCount == 1 ? "item" : "items") selected.")
                    .font(.subheadline)
                Text(selectionDetailText(snapshot: snapshot, routeCount: routeCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func prepareExport(
        selection: ExportSelectionState,
        summaries: [DaySummary],
        recordedTracks: [RecordedTrack]
    ) {
        let exportDays = ExportSelectionContent.exportDays(
            importedExport: session.content?.export,
            selection: selection,
            recordedTracks: recordedTracks
        )
        guard !exportDays.isEmpty else {
            exportError = "The current selection does not contain any routes with GPS points, so no \(selectedFormat.rawValue) file can be created."
            return
        }
        let exportString: String
        switch selectedFormat {
        case .gpx:
            exportString = GPXBuilder.build(from: exportDays)
        case .kml:
            exportString = KMLBuilder.build(from: exportDays)
        }
        let filename = ExportPresentation.suggestedFilename(
            selection: selection,
            summaries: summaries,
            recordedTracks: recordedTracks,
            format: selectedFormat
        )
        exportDocument = ExportDocument(content: exportString, suggestedFilename: filename)
        isExporting = true
    }

    @ViewBuilder
    private func selectionHeader(
        title: String,
        isAllSelected: Bool,
        onSelectAll: @escaping () -> Void,
        onDeselectAll: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            Button(isAllSelected ? "Deselect All" : "Select All") {
                if isAllSelected {
                    onDeselectAll()
                } else {
                    onSelectAll()
                }
            }
            .font(.subheadline)
        }
    }

    private func selectionDetailText(snapshot: ExportSelectionSnapshot, routeCount: Int) -> String {
        let dayPart = snapshot.selectedDayCount > 0
            ? "\(snapshot.selectedDayCount) imported \(snapshot.selectedDayCount == 1 ? "day" : "days")"
            : nil
        let trackPart = snapshot.selectedRecordedTrackCount > 0
            ? "\(snapshot.selectedRecordedTrackCount) saved \(snapshot.selectedRecordedTrackCount == 1 ? "track" : "tracks")"
            : nil
        let sourceParts = [dayPart, trackPart].compactMap { $0 }.joined(separator: " · ")
        let routePart = "\(routeCount) \(routeCount == 1 ? "route" : "routes")"
        return sourceParts.isEmpty ? routePart : "\(sourceParts) · \(routePart)"
    }

    private func previewSummary(_ previewData: ExportPreviewData) -> String {
        let importedPart = previewData.importedDayCount > 0
            ? "\(previewData.importedDayCount) imported \(previewData.importedDayCount == 1 ? "day" : "days")"
            : nil
        let trackPart = previewData.savedTrackCount > 0
            ? "\(previewData.savedTrackCount) saved \(previewData.savedTrackCount == 1 ? "track" : "tracks")"
            : nil
        let sourceSummary = [importedPart, trackPart].compactMap { $0 }.joined(separator: " · ")
        let routeSummary = "\(previewData.pathOverlays.count) \(previewData.pathOverlays.count == 1 ? "route" : "routes") in preview"
        return sourceSummary.isEmpty ? routeSummary : "\(sourceSummary) · \(routeSummary)"
    }

    private func savedTrackTitle(_ track: RecordedTrack) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: track.startedAt)
    }
}

#endif
