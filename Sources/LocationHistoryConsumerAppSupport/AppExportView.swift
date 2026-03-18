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
    @Binding var session: AppSessionState
    @State private var selectedFormat: ExportFormat = .gpx
    @State private var isExporting = false
    @State private var exportDocument: GPXDocument?
    @State private var exportError: String?

    public init(session: Binding<AppSessionState>) {
        self._session = session
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
            // Day list with selection checkboxes
            List {
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
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.inset)
            #endif

            // Bottom bar: format + export button
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
                        Label(formatDistance(summary.totalPathDistanceM), systemImage: "ruler")
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

    // MARK: - Export Bar

    @ViewBuilder
    private func exportBar(selection: ExportSelectionState, summaries: [DaySummary]) -> some View {
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

                exportButton(selection: selection, summaries: summaries)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .background(Color.secondary.opacity(0.05))
        }
    }

    @ViewBuilder
    private func exportButton(selection: ExportSelectionState, summaries: [DaySummary]) -> some View {
        let hasRoutes = selectedDaysHaveRoutes(selection: selection, summaries: summaries)
        let label: String = {
            if selection.isEmpty { return "Select days to export" }
            let n = selection.count
            return "Export \(n) \(n == 1 ? "day" : "days") as \(selectedFormat.rawValue)"
        }()

        Button {
            prepareExport(selection: selection, summaries: summaries)
        } label: {
            Label(label, systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(selection.isEmpty || !hasRoutes)
        .overlay {
            if !selection.isEmpty && !hasRoutes {
                Text("Selected days contain no routes with GPS points.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 44)
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

    private func prepareExport(selection: ExportSelectionState, summaries: [DaySummary]) {
        guard let export = session.content?.export else { return }
        let selectedDates = selection.selectedDates
        let days = AppExportQueries.days(in: export).filter { selectedDates.contains($0.date) }
        let gpxString = GPXBuilder.build(from: days)
        let filename = GPXBuilder.suggestedFilename(for: Array(selectedDates))
        exportDocument = GPXDocument(content: gpxString, suggestedFilename: filename)
        isExporting = true
    }
}

#endif
