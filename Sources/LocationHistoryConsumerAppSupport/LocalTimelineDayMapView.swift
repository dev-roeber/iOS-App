import Foundation
#if canImport(SwiftUI)
import SwiftUI

/// Phase-10A — SwiftUI-Hook für die Store-DayMap-Sektion.
///
/// Diese Datei trägt **keinen** MapKit-Import. Auf Apple-Plattformen ist
/// die echte `Map { … }`/`MKMapView`-Verdrahtung als Mac-/Xcode-Pflicht für
/// Phase 10B dokumentiert (siehe `docs/XCODE_RUNBOOK.md`). Auf Linux und
/// in der Foundation-only Linie liefert die View einen kompakten,
/// kartenfreien Placeholder, der die wichtigsten Routen-Metadaten und
/// Budget-Trunkierungssignale anzeigt.
///
/// Bewusst **keine**:
/// - MapKit/CoreLocation-Abhängigkeit
/// - Heatmap-/Overview-/Live-Tracking-Logik
/// - eager `coord_blob`-Decodierung außerhalb der `selectedPathIDs`
public struct LocalTimelineDayMapView: View {

    public typealias ViewState = LocalTimelineDayMapViewState

    private let state: ViewState

    public init(state: ViewState) {
        self.state = state
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if state.routes.isEmpty {
                emptyRow
            } else {
                ForEach(state.routes, id: \.pathID) { route in
                    routeRow(route)
                    Divider()
                }
            }
            if let bounds = state.bounds {
                boundsRow(bounds)
            }
            footer
        }
        .accessibilityIdentifier("localTimeline.dayMap")
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            Text("Map (Local Store)").font(.headline)
            Spacer()
            Text("\(state.routes.count) route(s)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func routeRow(_ route: ViewState.Route) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(route.mode ?? "Unknown mode")
                    .font(.subheadline)
                Spacer()
                Text("\(route.pointCount) pts")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Text(formatDistance(route.distanceM))
                if let bbox = route.bbox {
                    Text("bbox \(format(bbox.minLat))…\(format(bbox.maxLat)), \(format(bbox.minLon))…\(format(bbox.maxLon))")
                }
                Spacer()
                Text(route.hasGeometry
                     ? "geometry: \(route.decimatedPoints.count) decoded"
                     : "geometry: not loaded")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("localTimeline.dayMap.route.\(route.pathID)")
    }

    @ViewBuilder
    private var emptyRow: some View {
        Text("No path metadata for this day.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("localTimeline.dayMap.empty")
    }

    @ViewBuilder
    private func boundsRow(_ b: LocalTimelineMapBounds) -> some View {
        Text("Bounds: \(format(b.minLat))/\(format(b.minLon)) – \(format(b.maxLat))/\(format(b.maxLon))")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("localTimeline.dayMap.bounds")
    }

    @ViewBuilder
    private var footer: some View {
        VStack(alignment: .leading, spacing: 2) {
            if state.truncatedRoutes {
                Text("Routes truncated by daily budget (max \(state.budget.maxRoutes)).")
            }
            if state.truncatedTotalPoints {
                Text("Decoded points truncated by total budget (max \(state.budget.maxTotalPoints)).")
            }
            Text("MapKit overlay rendering is a Phase-10B Xcode handoff.")
        }
        .font(.footnote)
        .foregroundStyle(.tertiary)
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 { return String(format: "%.1f km", meters / 1000) }
        return String(format: "%.0f m", meters)
    }

    private func format(_ d: Double) -> String {
        String(format: "%.4f", d)
    }
}
#endif
