#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumer

struct DayDetailView: View {
    let detail: DayDetailViewState?
    let hasDays: Bool

    var body: some View {
        if let detail {
            if detail.hasContent {
                VStack(alignment: .leading, spacing: 20) {
                    Text(detail.date)
                        .font(.title2)
                        .fontWeight(.semibold)

                    section("Visits", count: detail.visits.count) {
                        ForEach(Array(detail.visits.enumerated()), id: \.offset) { _, visit in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(visit.semanticType ?? "Visit")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("\(visit.startTime ?? "n/a") -> \(visit.endTime ?? "n/a")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let placeID = visit.placeID {
                                    Text(placeID)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    section("Activities", count: detail.activities.count) {
                        ForEach(Array(detail.activities.enumerated()), id: \.offset) { _, activity in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(activity.activityType ?? "Activity")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("\(activity.startTime ?? "n/a") -> \(activity.endTime ?? "n/a")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let distanceM = activity.distanceM {
                                    Text(String(format: "%.0f m", distanceM))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    section("Paths", count: detail.paths.count) {
                        ForEach(Array(detail.paths.enumerated()), id: \.offset) { _, path in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(path.activityType ?? "Path")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("\(path.pointCount) points")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let distanceM = path.distanceM {
                                    Text(String(format: "%.0f m", distanceM))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                emptyState(
                    title: "No Content For This Day",
                    message: "This day exists in the app export, but it does not contain visits, activities or paths."
                )
            }
        } else if hasDays {
            emptyState(
                title: "No Day Selected",
                message: "Choose a day from the list to inspect visits, activities and paths."
            )
        } else {
            emptyState(
                title: "No Day Details Available",
                message: "Load a source with day entries to inspect visits, activities and paths."
            )
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, count: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            content()
        }
    }

    @ViewBuilder
    private func emptyState(title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }
}
#endif
