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
    @State private var loadGeneration: UInt64 = 0

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
        .task(id: taskKey) {
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
            Text("\(renderData.visibleRouteCount) \(t(renderData.visibleRouteCount == 1 ? "route" : "routes"))")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.45))
                .clipShape(Capsule())
                .padding(8)
        }
        .overlay(alignment: .bottomLeading) {
            if renderData.isOptimized {
                Text(t("Optimized overview"))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.35))
                    .clipShape(Capsule())
                    .padding(8)
            }
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

    /// A stable identifier that changes whenever the input data or relevant filters change.
    private var taskKey: Int {
        OverviewMapTaskKey.make(daySummaries: daySummaries, queryFilter: queryFilter)
    }

    private var mapAccessibilityLabel: String {
        let count = renderData.visibleRouteCount
        if preferences.appLanguage.isGerman {
            if renderData.isOptimized {
                return "Optimierte Übersichtskarte mit \(count) dargestellten \(count == 1 ? "Route" : "Routen")"
            }
            return "Übersichtskarte mit \(count) \(count == 1 ? "Route" : "Routen")"
        }
        if renderData.isOptimized {
            return "Optimized overview map with \(count) displayed \(count == 1 ? "route" : "routes")"
        }
        return "Overview map with \(count) \(count == 1 ? "route" : "routes")"
    }

    @MainActor
    private func loadMapData() async {
        guard let content, !daySummaries.isEmpty else {
            renderData = .empty
            return
        }

        loadGeneration &+= 1
        let generation = loadGeneration
        renderData = .loading

        let allDates = daySummaries.map(\.date)
        let filter = queryFilter

        let prepared = await Task.detached(priority: .userInitiated) {
            OverviewMapPreparation.buildRenderData(for: allDates, content: content, filter: filter)
        }.value

        guard generation == loadGeneration, !Task.isCancelled else { return }
        renderData = prepared
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }
}

// MARK: - Render data models

struct OverviewMapPathOverlay: Equatable {
    let coordinates: [CLLocationCoordinate2D]
    let activityType: String?
}

struct OverviewMapRenderData {
    let pathOverlays: [OverviewMapPathOverlay]
    let region: MKCoordinateRegion?
    let totalRouteCount: Int
    let isOptimized: Bool
    let isLoading: Bool

    var hasContent: Bool { !pathOverlays.isEmpty }
    var visibleRouteCount: Int { pathOverlays.count }

    static let empty = OverviewMapRenderData(pathOverlays: [], region: nil, totalRouteCount: 0, isOptimized: false, isLoading: false)
    static let loading = OverviewMapRenderData(pathOverlays: [], region: nil, totalRouteCount: 0, isOptimized: false, isLoading: true)

    init(pathOverlays: [OverviewMapPathOverlay], region: MKCoordinateRegion?, totalRouteCount: Int, isOptimized: Bool = false) {
        self.pathOverlays = pathOverlays
        self.region = region
        self.totalRouteCount = totalRouteCount
        self.isOptimized = isOptimized
        self.isLoading = false
    }

    private init(pathOverlays: [OverviewMapPathOverlay], region: MKCoordinateRegion?, totalRouteCount: Int, isOptimized: Bool, isLoading: Bool) {
        self.pathOverlays = pathOverlays
        self.region = region
        self.totalRouteCount = totalRouteCount
        self.isOptimized = isOptimized
        self.isLoading = isLoading
    }
}

enum OverviewMapTaskKey {
    nonisolated static func make(daySummaries: [DaySummary], queryFilter: AppExportQueryFilter?) -> Int {
        var hasher = Hasher()
        hasher.combine(queryFilter)
        for summary in daySummaries {
            hasher.combine(summary.date)
            hasher.combine(summary.pathCount)
            hasher.combine(summary.exportablePathCount)
            hasher.combine(summary.totalPathPointCount)
            hasher.combine(summary.visitCount)
            hasher.combine(summary.activityCount)
        }
        return hasher.finalize()
    }
}

private struct OverviewMapPathCandidate {
    let signature: Int
    let fullCoordinates: [CLLocationCoordinate2D]
    let midpoint: CLLocationCoordinate2D
    let activityType: String?
    let score: Double
}

struct OverviewMapRenderProfile {
    let routeLimit: Int
    let gridDimension: Int
    let maxRoutesPerCell: Int
    let simplificationEpsilonM: Double
    let maxPolylinePoints: Int

    static func resolve(routeCount: Int, totalPointCount: Int) -> OverviewMapRenderProfile {
        // Route limits no longer hide routes from the selected time range. They track
        // the full candidate count so downstream code can stay explicit about coverage
        // while optimization is done via simplification and point decimation only.
        switch (routeCount, totalPointCount) {
        case let (routes, points) where routes > 500 || points > 150_000:
            return OverviewMapRenderProfile(
                routeLimit: routeCount,
                gridDimension: 12,
                maxRoutesPerCell: 2,
                simplificationEpsilonM: 140,
                maxPolylinePoints: 64
            )
        case let (routes, points) where routes > 240 || points > 60_000:
            return OverviewMapRenderProfile(
                routeLimit: routeCount,
                gridDimension: 10,
                maxRoutesPerCell: 3,
                simplificationEpsilonM: 100,
                maxPolylinePoints: 96
            )
        case let (routes, points) where routes > 120 || points > 30_000:
            return OverviewMapRenderProfile(
                routeLimit: routeCount,
                gridDimension: 9,
                maxRoutesPerCell: 4,
                simplificationEpsilonM: 70,
                maxPolylinePoints: 120
            )
        case let (routes, points) where routes > 60 || points > 15_000:
            return OverviewMapRenderProfile(
                routeLimit: routeCount,
                gridDimension: 8,
                maxRoutesPerCell: 6,
                simplificationEpsilonM: 50,
                maxPolylinePoints: 160
            )
        default:
            return OverviewMapRenderProfile(
                routeLimit: routeCount,
                gridDimension: 6,
                maxRoutesPerCell: 6,
                simplificationEpsilonM: 30,
                maxPolylinePoints: 220
            )
        }
    }
}

enum OverviewMapPreparation {
    nonisolated static func buildRenderData(
        for dates: [String],
        content: AppSessionContent,
        filter: AppExportQueryFilter?
    ) -> OverviewMapRenderData {
        var candidates: [OverviewMapPathCandidate] = []
        var allCoords: [DayMapCoordinate] = []
        var totalPointCount = 0

        for date in dates {
            guard let mapData = content.mapData(for: date, applying: filter) else { continue }
            for overlay in mapData.pathOverlays {
                guard let candidate = makeCandidate(from: overlay) else { continue }
                candidates.append(candidate)
                totalPointCount += overlay.coordinates.count
                allCoords.append(contentsOf: overlay.coordinates)
            }
        }

        let region = computeRegion(from: allCoords)
        guard !candidates.isEmpty else {
            return OverviewMapRenderData(pathOverlays: [], region: region, totalRouteCount: 0)
        }

        let profile = OverviewMapRenderProfile.resolve(
            routeCount: candidates.count,
            totalPointCount: totalPointCount
        )
        let selected = selectCandidates(candidates, region: region, profile: profile)
        let pathOverlays = selected.compactMap { candidate in
            makeOverlay(from: candidate, profile: profile)
        }
        let isOptimized = profile.simplificationEpsilonM > 30 || profile.maxPolylinePoints < 220

        return OverviewMapRenderData(
            pathOverlays: pathOverlays,
            region: region,
            totalRouteCount: candidates.count,
            isOptimized: isOptimized
        )
    }

    private nonisolated static func makeCandidate(from overlay: DayMapPathOverlay) -> OverviewMapPathCandidate? {
        guard overlay.coordinates.count >= 2 else { return nil }

        let coordinates = overlay.coordinates.map {
            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
        }
        guard coordinates.count >= 2 else { return nil }

        let scoreBase = overlay.distanceM ?? approximateDistance(for: coordinates)
        let pointWeight = log(Double(max(overlay.coordinates.count, 2)))
        let midpointIndex = coordinates.count / 2
        var hasher = Hasher()
        hasher.combine(overlay.activityType)
        hasher.combine(overlay.coordinates.count)
        hasher.combine(overlay.distanceM ?? 0)
        hasher.combine(coordinates.first?.latitude ?? 0)
        hasher.combine(coordinates.first?.longitude ?? 0)
        hasher.combine(coordinates[midpointIndex].latitude)
        hasher.combine(coordinates[midpointIndex].longitude)
        hasher.combine(coordinates.last?.latitude ?? 0)
        hasher.combine(coordinates.last?.longitude ?? 0)

        return OverviewMapPathCandidate(
            signature: hasher.finalize(),
            fullCoordinates: coordinates,
            midpoint: coordinates[midpointIndex],
            activityType: overlay.activityType,
            score: scoreBase + pointWeight * 100
        )
    }

    private nonisolated static func selectCandidates(
        _ candidates: [OverviewMapPathCandidate],
        region: MKCoordinateRegion?,
        profile: OverviewMapRenderProfile
    ) -> [OverviewMapPathCandidate] {
        _ = region
        _ = profile
        return candidates.sorted { $0.score > $1.score }
    }

    private nonisolated static func makeOverlay(
        from candidate: OverviewMapPathCandidate,
        profile: OverviewMapRenderProfile
    ) -> OverviewMapPathOverlay? {
        let simplified = PathSimplification.douglasPeucker(
            candidate.fullCoordinates,
            epsilon: profile.simplificationEpsilonM
        )
        let decimated = decimate(simplified, maxPoints: profile.maxPolylinePoints)
        guard decimated.count >= 2 else { return nil }

        return OverviewMapPathOverlay(
            coordinates: decimated,
            activityType: candidate.activityType
        )
    }

    private nonisolated static func decimate(
        _ coordinates: [CLLocationCoordinate2D],
        maxPoints: Int
    ) -> [CLLocationCoordinate2D] {
        guard coordinates.count > maxPoints, maxPoints >= 2 else {
            return coordinates
        }

        let step = max(1, Int(ceil(Double(coordinates.count - 1) / Double(maxPoints - 1))))
        var result: [CLLocationCoordinate2D] = []
        result.reserveCapacity(maxPoints)

        var index = 0
        while index < coordinates.count - 1 {
            result.append(coordinates[index])
            index += step
        }
        result.append(coordinates[coordinates.count - 1])
        return result
    }

    nonisolated static func computeRegion(from coordinates: [DayMapCoordinate]) -> MKCoordinateRegion? {
        guard let first = coordinates.first else { return nil }
        var minLat = first.lat
        var maxLat = first.lat
        var minLon = first.lon
        var maxLon = first.lon

        for coordinate in coordinates {
            minLat = min(minLat, coordinate.lat)
            maxLat = max(maxLat, coordinate.lat)
            minLon = min(minLon, coordinate.lon)
            maxLon = max(maxLon, coordinate.lon)
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

    private nonisolated static func approximateDistance(for coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count >= 2 else { return 0 }
        return zip(coordinates, coordinates.dropFirst()).reduce(0) { partial, pair in
            let a = CLLocation(latitude: pair.0.latitude, longitude: pair.0.longitude)
            let b = CLLocation(latitude: pair.1.latitude, longitude: pair.1.longitude)
            return partial + a.distance(from: b)
        }
    }
}

#endif
