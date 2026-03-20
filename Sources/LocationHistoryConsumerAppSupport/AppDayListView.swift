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
                        Label("Export", systemImage: "square.and.arrow.up")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.accentColor)
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
        .padding(.horizontal, 8)
        .background(isSelectedForExport ? Color.accentColor.opacity(0.06) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .opacity(summary.hasContent ? 1 : 0.72)
    }
}

// MARK: - Day List (Selection-based, for regular layout)

public struct AppDayListView: View {
    let summaries: [DaySummary]
    let selectedForExportDates: Set<String>
    @Binding var selectedDate: String?
    @Binding var searchText: String

    public init(
        summaries: [DaySummary],
        selectedForExportDates: Set<String> = [],
        selectedDate: Binding<String?>,
        searchText: Binding<String> = .constant("")
    ) {
        self.summaries = summaries
        self.selectedForExportDates = selectedForExportDates
        self._selectedDate = selectedDate
        self._searchText = searchText
    }

    public var body: some View {
        let filteredSummaries = AppDaySearch.filter(summaries, query: searchText)
        if summaries.isEmpty {
            AppDayListEmptyView()
        } else {
            let groups = groupByMonth(filteredSummaries)
            List(selection: $selectedDate) {
                if !selectedForExportDates.isEmpty {
                    exportStatusSection
                }
                if groups.count == 1 {
                    ForEach(filteredSummaries, id: \.date) { summary in
                        AppDayRow(
                            summary: summary,
                            isSelectedForExport: selectedForExportDates.contains(summary.date)
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
                                    isSelectedForExport: selectedForExportDates.contains(summary.date)
                                )
                                    .tag(summary.date)
                                    .disabled(!summary.hasContent)
                            }
                        }
                    }
                }
            }
            .overlay {
                if !summaries.isEmpty && filteredSummaries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text("No Results")
                            .font(.headline)
                        Text("No days match \"\(searchText)\".")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(24)
                }
            }
        }
    }

    private var exportStatusSection: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(selectedForExportDates.count) day\(selectedForExportDates.count == 1 ? "" : "s") selected for export")
                        .font(.subheadline.weight(.semibold))
                    Text("Export markers stay visible directly in the list.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)
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

#endif
