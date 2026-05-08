import Foundation
#if canImport(SwiftUI)
import SwiftUI

/// Phase-9B — SwiftUI-Hook für die Store-DayList.
///
/// Konsumiert `LocalTimelineDayListViewState` (Foundation-only), zeigt
/// Tage **newest-first**, ohne `coord_blob` zu lesen oder Koordinaten zu
/// dekodieren. Auswahl wird per Closure nach außen gereicht; der Caller
/// hält den Selection-State (typisch: `AppSessionState.selectedLocalTimelineDayId`).
///
/// Sichtbarkeit ist Caller-Pflicht — die View selbst rendert nur, wenn sie
/// instantiiert wurde, und macht keine Annahmen über `localTimelineSession`.
public struct LocalTimelineDayListView: View {

    private let state: LocalTimelineDayListViewState
    private let selectedDayId: String?
    private let onSelect: (LocalTimelineDayListViewState.Row) -> Void

    public init(state: LocalTimelineDayListViewState,
                selectedDayId: String?,
                onSelect: @escaping (LocalTimelineDayListViewState.Row) -> Void) {
        self.state = state
        self.selectedDayId = selectedDayId
        self.onSelect = onSelect
    }

    public var body: some View {
        Group {
            if state.isEmpty {
                emptyState
            } else {
                rowsList
            }
        }
        .accessibilityIdentifier("localTimeline.dayList")
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No days in this import")
                .font(.headline)
            Text("This Google Timeline import did not yield any day entries.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .accessibilityIdentifier("localTimeline.dayList.empty")
    }

    @ViewBuilder
    private var rowsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(state.rows, id: \.dayId) { row in
                Button {
                    onSelect(row)
                } label: {
                    rowLabel(row)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("localTimeline.dayList.row.\(row.dayId)")
                .background(selectedDayId == row.dayId
                            ? Color.accentColor.opacity(0.12)
                            : Color.clear)
                Divider()
            }
        }
    }

    @ViewBuilder
    private func rowLabel(_ row: LocalTimelineDayListViewState.Row) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.date)
                    .font(.subheadline.weight(.semibold))
                Text(metadataLine(row))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(formatDistance(row.distanceM))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }

    private func metadataLine(_ row: LocalTimelineDayListViewState.Row) -> String {
        "\(row.routeCount) routes · \(row.visitCount) visits"
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }
}
#endif
