#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumer

// MARK: - Day Row

struct AppDayRow: View {
    @EnvironmentObject private var preferences: AppPreferences
    let summary: DaySummary
    var highlightIcons: [String] = []
    var isSelectedForExport: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(AppDateDisplay.weekday(summary.date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    if isSelectedForExport {
                        Label(DayListPresentation.exportBadgeTitle, systemImage: "square.and.arrow.up.circle.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    ForEach(highlightIcons, id: \.self) { icon in
                        Image(systemName: icon)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Text(AppDateDisplay.mediumDate(summary.date))
                .font(.headline)
            if summary.hasContent {
                HStack(spacing: 12) {
                    Label("\(summary.visitCount)", systemImage: "mappin.and.ellipse")
                    Label("\(summary.activityCount)", systemImage: "figure.walk")
                    Label("\(summary.pathCount)", systemImage: "location.north.line")
                    if summary.totalPathDistanceM > 0 {
                        Label(formatDistance(summary.totalPathDistanceM, unit: preferences.distanceUnit), systemImage: "ruler")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(summary.visitCount) Visits, \(summary.activityCount) Activities, \(summary.pathCount) Routes")
            } else {
                Label("No recorded entries", systemImage: "tray")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("No recorded entries for this day")
            }
        }
        .padding(.vertical, 4)
        .opacity(summary.hasContent ? 1 : 0.72)
    }
}

// MARK: - Day List (Selection-based, for regular layout)

public struct AppDayListView: View {
    let summaries: [DaySummary]
    @Binding var selectedDate: String?
    let exportSelection: ExportSelectionState
    var onOpenExport: (() -> Void)? = nil

    public init(
        summaries: [DaySummary],
        selectedDate: Binding<String?>,
        exportSelection: ExportSelectionState = ExportSelectionState(),
        onOpenExport: (() -> Void)? = nil
    ) {
        self.summaries = summaries
        self._selectedDate = selectedDate
        self.exportSelection = exportSelection
        self.onOpenExport = onOpenExport
    }

    public var body: some View {
        if summaries.isEmpty {
            AppDayListEmptyView()
        } else {
            let groups = groupByMonth(summaries)
            List(selection: $selectedDate) {
                Section {
                    DayListExportSelectionCard(
                        selectionCount: exportSelection.count,
                        onOpenExport: onOpenExport
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                }

                if groups.count == 1 {
                    ForEach(summaries, id: \.date) { summary in
                        AppDayRow(
                            summary: summary,
                            isSelectedForExport: exportSelection.isSelected(summary.date)
                        )
                        .tag(summary.date)
                        .disabled(!summary.hasContent)
                    }
                } else {
                    ForEach(groups) { group in
                        Section(group.title) {
                            ForEach(group.summaries, id: \.date) { summary in
                                AppDayRow(
                                    summary: summary,
                                    isSelectedForExport: exportSelection.isSelected(summary.date)
                                )
                                .tag(summary.date)
                                .disabled(!summary.hasContent)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Day List Empty

struct AppDayListEmptyView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("No Days")
                .font(.headline)
            Text("This export does not contain any day entries.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

struct AppDaySearchEmptyView: View {
    let query: String
    let exportSelectionCount: Int

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("No Results")
                .font(.headline)
            Text(DayListPresentation.searchEmptyMessage(query: query, exportSelectionCount: exportSelectionCount))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

struct DayListExportSelectionCard: View {
    let selectionCount: Int
    var onOpenExport: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Label(DayListPresentation.exportSelectionTitle(count: selectionCount), systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                Text(DayListPresentation.exportSelectionMessage(count: selectionCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let onOpenExport {
                Button(DayListPresentation.exportButtonTitle, action: onOpenExport)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#endif
