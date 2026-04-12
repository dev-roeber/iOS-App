#if canImport(SwiftUI) && canImport(MapKit)
import SwiftUI
import MapKit
import LocationHistoryConsumer

// MARK: - Overview Tracks Map (Task 3)

/// A map that shows polylines for all tracks in the active time range
/// (and favorites filter). Data is loaded asynchronously off the main thread.
@available(iOS 17.0, macOS 14.0, *)
struct AppOverviewTracksMapView: View {
    @EnvironmentObject private var preferences: AppPreferences

    let daySummaries: [DaySummary]
    let content: AppSessionContent?
    let queryFilter: AppExportQueryFilter?

    @State private var renderData: OverviewMapRenderData = .empty
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        Group {
            if renderData.hasContent, let region = renderData.region {
                mapView(region: region)
            } else if renderData.isLoading {
                loadingPlaceholder
            } else {
                emptyPlaceholder
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .task(id: taskIdentifier) {
            await loadMapData()
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func mapView(region: MKCoordinateRegion) -> some View {
        Map(initialPosition: .region(region)) {
            ForEach(Array(renderData.pathOverlays.enumerated()), id: \.offset) { _, path in
                MapPolyline(coordinates: path.coordinates)
                    .stroke(MapPalette.routeColor(for: path.activityType), lineWidth: 2)
            }
        }
        .mapStyle(preferences.preferredMapStyle.isHybrid ? .hybrid : .standard)
        .disabled(true) // read-only overview; no interaction needed
        .accessibilityLabel(mapAccessibilityLabel)
        .overlay(alignment: .bottomTrailing) {
            Text("\(renderData.pathOverlays.count) \(t(renderData.pathOverlays.count == 1 ? "route" : "routes"))")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.45))
                .clipShape(Capsule())
                .padding(8)
        }
    }

    private var loadingPlaceholder: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text(t("Loading map…"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.secondary.opacity(0.05))
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "map")
                .font(.title2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(t("No tracks in selected range"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.secondary.opacity(0.05))
    }

    // MARK: - Data loading

    /// A stable identifier that changes whenever the input data changes.
    private var taskIdentifier: String {
        let first = daySummaries.first?.date ?? ""
        let last = daySummaries.last?.date ?? ""
        let count = daySummaries.count
        return "\(first)-\(last)-\(count)-\(queryFilter?.fromDate ?? "")-\(queryFilter?.toDate ?? "")"
    }

    private var mapAccessibilityLabel: String {
        let count = renderData.pathOverlays.count
        if preferences.appLanguage.isGerman {
            return "Übersichtskarte mit \(count) \(count == 1 ? "Route" : "Routen")"
        }
        return "Overview map with \(count) \(count == 1 ? "route" : "routes")"
    }

    @MainActor
    private func loadMapData() async {
        guard let content, !daySummaries.isEmpty else {
            renderData = .empty
            return
        }

        renderData = .loading

        let allDates = daySummaries.map(\.date)
        let firstBatchDates = Array(allDates.prefix(100))
        let remainingDates = Array(allDates.dropFirst(100))
        let filter = queryFilter

        // Phase 1: load first 100 days immediately so the user sees content fast.
        let firstBatch = await Task.detached(priority: .userInitiated) {
            buildRenderData(for: firstBatchDates, content: content, filter: filter)
        }.value

        renderData = firstBatch

        guard !remainingDates.isEmpty, !Task.isCancelled else { return }

        // Phase 2: load the rest in the background and append.
        let rest = await Task.detached(priority: .utility) {
            buildRenderData(for: remainingDates, content: content, filter: filter)
        }.value

        guard !Task.isCancelled else { return }

        renderData = renderData.appending(rest)
    }

    private nonisolated func buildRenderData(
        for dates: [String],
        content: AppSessionContent,
        filter: AppExportQueryFilter?
    ) -> OverviewMapRenderData {
        var allPaths: [OverviewMapPathOverlay] = []
        var allCoords: [DayMapCoordinate] = []

        for date in dates {
            guard let mapData = content.mapData(for: date, applying: filter) else { continue }
            for overlay in mapData.pathOverlays {
                guard overlay.coordinates.count >= 2 else { continue }
                let clCoords = overlay.coordinates.map {
                    CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
                }
                // Apply Douglas-Peucker with 50 m tolerance for the small overview map.
                let simplified = PathSimplification.douglasPeucker(clCoords, epsilon: 50.0)
                guard simplified.count >= 2 else { continue }
                allPaths.append(OverviewMapPathOverlay(coordinates: simplified, activityType: overlay.activityType))
                allCoords.append(contentsOf: overlay.coordinates)
            }
        }

        let region = computeRegion(from: allCoords)
        return OverviewMapRenderData(pathOverlays: allPaths, region: region)
    }

    private nonisolated func computeRegion(from coordinates: [DayMapCoordinate]) -> MKCoordinateRegion? {
        guard let first = coordinates.first else { return nil }
        var minLat = first.lat, maxLat = first.lat
        var minLon = first.lon, maxLon = first.lon
        for c in coordinates {
            minLat = min(minLat, c.lat); maxLat = max(maxLat, c.lat)
            minLon = min(minLon, c.lon); maxLon = max(maxLon, c.lon)
        }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.3, 0.01),
            longitudeDelta: max((maxLon - minLon) * 1.3, 0.01)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }
}

// MARK: - Render data models

private struct OverviewMapPathOverlay {
    let coordinates: [CLLocationCoordinate2D]
    let activityType: String?
}

private struct OverviewMapRenderData {
    let pathOverlays: [OverviewMapPathOverlay]
    let region: MKCoordinateRegion?
    let isLoading: Bool

    var hasContent: Bool { !pathOverlays.isEmpty }

    static let empty = OverviewMapRenderData(pathOverlays: [], region: nil, isLoading: false)
    static let loading = OverviewMapRenderData(pathOverlays: [], region: nil, isLoading: true)

    init(pathOverlays: [OverviewMapPathOverlay], region: MKCoordinateRegion?) {
        self.pathOverlays = pathOverlays
        self.region = region
        self.isLoading = false
    }

    private init(pathOverlays: [OverviewMapPathOverlay], region: MKCoordinateRegion?, isLoading: Bool) {
        self.pathOverlays = pathOverlays
        self.region = region
        self.isLoading = isLoading
    }

    /// Returns a new value that merges `other` into the receiver.
    /// The region is expanded to cover both datasets; existing paths are kept.
    func appending(_ other: OverviewMapRenderData) -> OverviewMapRenderData {
        let merged = pathOverlays + other.pathOverlays
        let mergedRegion = unionRegion(self.region, other.region)
        return OverviewMapRenderData(pathOverlays: merged, region: mergedRegion)
    }

    // MARK: - Region helpers

    private func unionRegion(
        _ a: MKCoordinateRegion?,
        _ b: MKCoordinateRegion?
    ) -> MKCoordinateRegion? {
        switch (a, b) {
        case (nil, let r): return r
        case (let r, nil): return r
        case (let r1?, let r2?):
            let minLat = min(r1.center.latitude  - r1.span.latitudeDelta  / 2,
                            r2.center.latitude  - r2.span.latitudeDelta  / 2)
            let maxLat = max(r1.center.latitude  + r1.span.latitudeDelta  / 2,
                            r2.center.latitude  + r2.span.latitudeDelta  / 2)
            let minLon = min(r1.center.longitude - r1.span.longitudeDelta / 2,
                            r2.center.longitude - r2.span.longitudeDelta / 2)
            let maxLon = max(r1.center.longitude + r1.span.longitudeDelta / 2,
                            r2.center.longitude + r2.span.longitudeDelta / 2)
            let center = CLLocationCoordinate2D(
                latitude:  (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            let span = MKCoordinateSpan(
                latitudeDelta:  max(maxLat - minLat, 0.01),
                longitudeDelta: max(maxLon - minLon, 0.01)
            )
            return MKCoordinateRegion(center: center, span: span)
        }
    }
}

#endif
