import Foundation
#if canImport(SwiftUI)
import SwiftUI

/// Phase-9B — SwiftUI-Hook für Store-DayDetail.
///
/// Zeigt Tagesdatum + Summary + Visits + Activities + Path-**Metadaten**.
/// **Kein** Map-Hook, **keine** Polyline, **kein** eager
/// `coord_blob`-Decoding. Path-Geometrie würde explizit über
/// `LocalTimelineDayDetailViewStateAdapter.coordinates(forPathId:)` gelesen
/// werden — Phase-9B verzichtet komplett auf das Anzeigen der Geometrie und
/// dokumentiert lediglich, dass Punkte vorhanden sind.
public struct LocalTimelineDayDetailView: View {

    public typealias ViewState = LocalTimelineDayDetailViewStateAdapter.ViewState

    private let state: ViewState
    private let mapSource: LocalTimelineDayMapSource?
    @State private var mapState: LocalTimelineDayMapViewState?
    @State private var mapError: String?
    @State private var selectedPathIDs: Set<String> = []

    public init(state: ViewState,
                mapSource: LocalTimelineDayMapSource? = nil) {
        self.state = state
        self.mapSource = mapSource
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                summary
                if !state.visits.isEmpty { visitsSection }
                if !state.activities.isEmpty { activitiesSection }
                if !state.paths.isEmpty { pathsSection }
                if mapSource != nil && !state.paths.isEmpty { mapSection }
                if !state.hasContent { emptyNote }
                geometryNote
            }
            .padding(20)
            .frame(maxWidth: 560, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("localTimeline.dayDetail")
    }

    @ViewBuilder
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Map").font(.headline)
                Spacer()
                if mapState == nil {
                    Button("Load map") { loadMap(decodeSelected: false) }
                        .accessibilityIdentifier("localTimeline.dayDetail.map.load")
                } else {
                    Button(selectedPathIDs.isEmpty ? "Decode all routes" : "Hide geometry") {
                        if selectedPathIDs.isEmpty {
                            selectedPathIDs = Set(state.paths.map(\.id))
                        } else {
                            selectedPathIDs.removeAll()
                        }
                        loadMap(decodeSelected: true)
                    }
                    .accessibilityIdentifier("localTimeline.dayDetail.map.toggle")
                }
            }
            if let mapError {
                Text("Could not load map: \(mapError)")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("localTimeline.dayDetail.map.error")
            } else if let mapState {
                LocalTimelineDayMapView(state: mapState)
            } else {
                Text("Map data is not yet loaded. Coordinates remain on disk until you tap Load.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("localTimeline.dayDetail.map.placeholder")
            }
        }
    }

    private func loadMap(decodeSelected: Bool) {
        guard let source = mapSource else { return }
        do {
            mapState = try source.load(state.dayId,
                                       decodeSelected ? selectedPathIDs : [])
            mapError = nil
        } catch {
            mapState = nil
            mapError = String(describing: error)
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(state.date)
                .font(.title2.weight(.semibold))
            Text("Day \(state.dayId)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("localTimeline.dayDetail.dayId")
        }
    }

    @ViewBuilder
    private var summary: some View {
        VStack(alignment: .leading, spacing: 4) {
            row("Routes", "\(state.routeCount)")
            row("Visits", "\(state.visitCount)")
            row("Distance", formatDistance(state.distanceM))
            row("Path points (metadata)", "\(state.totalPathPointCount)")
        }
        .accessibilityIdentifier("localTimeline.dayDetail.summary")
    }

    @ViewBuilder
    private var visitsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Visits", count: state.visits.count)
            ForEach(state.visits, id: \.id) { visit in
                VStack(alignment: .leading, spacing: 2) {
                    Text(visit.name ?? "Unnamed visit")
                        .font(.subheadline)
                    Text(formatTimeRange(start: visit.startTime, end: visit.endTime))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("localTimeline.dayDetail.visit.\(visit.id)")
                Divider()
            }
        }
    }

    @ViewBuilder
    private var activitiesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Activities", count: state.activities.count)
            ForEach(state.activities, id: \.id) { activity in
                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.mode ?? "Unknown mode")
                        .font(.subheadline)
                    HStack {
                        Text(formatTimeRange(start: activity.startTime, end: activity.endTime))
                        Spacer()
                        if let d = activity.distanceM {
                            Text(formatDistance(d))
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("localTimeline.dayDetail.activity.\(activity.id)")
                Divider()
            }
        }
    }

    @ViewBuilder
    private var pathsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Paths", count: state.paths.count)
            ForEach(state.paths, id: \.id) { path in
                VStack(alignment: .leading, spacing: 2) {
                    Text(path.mode ?? "Unknown mode")
                        .font(.subheadline)
                    HStack {
                        Text("\(path.pointCount) points · \(formatDistance(path.distanceM))")
                        Spacer()
                        Text(formatTimeRange(start: path.startTime, end: path.endTime))
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    if path.pointCount > 0 {
                        Text("Path points available (not decoded)")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                            .accessibilityIdentifier("localTimeline.dayDetail.path.\(path.id).pointsAvailable")
                    }
                }
                .accessibilityIdentifier("localTimeline.dayDetail.path.\(path.id)")
                Divider()
            }
        }
    }

    @ViewBuilder
    private var emptyNote: some View {
        Text("This day has no visits, activities or path metadata.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("localTimeline.dayDetail.empty")
    }

    @ViewBuilder
    private var geometryNote: some View {
        if mapSource == nil {
            Text("Coordinates are not decoded in this view. Map / polyline UI for the local store is not wired in this build.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            Text("Map metadata is loaded on demand. Decoding route geometry is bounded by per-route and per-day point budgets.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func sectionTitle(_ title: String, count: Int) -> some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            Text("\(count)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Text(value).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
        }
    }

    private func formatTimeRange(start: String?, end: String?) -> String {
        switch (start, end) {
        case let (.some(s), .some(e)): return "\(s) → \(e)"
        case let (.some(s), .none): return s
        case let (.none, .some(e)): return "→ \(e)"
        case (.none, .none): return "—"
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }
}
#endif
