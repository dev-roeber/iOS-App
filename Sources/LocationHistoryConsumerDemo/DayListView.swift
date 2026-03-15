#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumer

struct DayListView: View {
    let summaries: [DaySummary]
    @Binding var selectedDate: String?

    var body: some View {
        if summaries.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text("No Days Available")
                    .font(.headline)
                Text("This app export does not contain any day entries to inspect.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        } else {
            List(summaries, id: \.date, selection: $selectedDate) { summary in
                VStack(alignment: .leading, spacing: 6) {
                    Text(summary.date)
                        .font(.headline)
                    Text("\(summary.visitCount) visits, \(summary.activityCount) activities, \(summary.pathCount) paths")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if summary.pathCount > 0 {
                        Text("\(summary.totalPathPointCount) path points")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .tag(summary.date)
            }
        }
    }
}
#endif
