#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumer

// MARK: - Day Row

struct AppDayRow: View {
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
                        Image(systemName: "square.and.arrow.up.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.accentColor)
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
            HStack(spacing: 12) {
                Label("\(summary.visitCount)", systemImage: "mappin.and.ellipse")
                Label("\(summary.activityCount)", systemImage: "figure.walk")
                Label("\(summary.pathCount)", systemImage: "location.north.line")
                if summary.totalPathDistanceM > 0 {
                    Label(formatDistance(summary.totalPathDistanceM), systemImage: "ruler")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(summary.visitCount) Visits, \(summary.activityCount) Activities, \(summary.pathCount) Routes")
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Day List (Selection-based, for regular layout)

public struct AppDayListView: View {
    let summaries: [DaySummary]
    @Binding var selectedDate: String?

    public init(summaries: [DaySummary], selectedDate: Binding<String?>) {
        self.summaries = summaries
        self._selectedDate = selectedDate
    }

    public var body: some View {
        if summaries.isEmpty {
            AppDayListEmptyView()
        } else {
            let groups = groupByMonth(summaries)
            if groups.count == 1 {
                List(summaries, id: \.date, selection: $selectedDate) { summary in
                    AppDayRow(summary: summary)
                        .tag(summary.date)
                }
            } else {
                List(selection: $selectedDate) {
                    ForEach(groups) { group in
                        Section(group.title) {
                            ForEach(group.summaries, id: \.date) { summary in
                                AppDayRow(summary: summary)
                                    .tag(summary.date)
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

#endif
