#if canImport(SwiftUI) && canImport(MapKit)
import SwiftUI
import MapKit
import LocationHistoryConsumer

/// Aggregated statistics about the heatmap dataset — surfaced in the
/// sheet header so users can see "what they're looking at" at a glance.
struct HeatmapStats: Equatable {
    let totalPoints: Int
    let dayCount: Int
    let firstDate: String?
    let lastDate: String?
}

@available(iOS 17.0, macOS 14.0, *)
@Observable @MainActor
final class AppHeatmapModel {
    var visibleCells: [HeatCell] = []
    var isCalculating = false
    var initialCenter: CLLocationCoordinate2D?
    var dataRegion: MKCoordinateRegion?
    var hasData: Bool { dataRegion != nil }
    var stats: HeatmapStats = HeatmapStats(totalPoints: 0, dayCount: 0, firstDate: nil, lastDate: nil)
    private(set) var lastRegion: MKCoordinateRegion?

    private let export: AppExport
    private var densityPoints: [WeightedPoint] = []
    private var lodGrids: [HeatmapLOD: [GridKey: HeatCell]] = [:]
    private var viewportCache: [HeatmapViewportKey: [HeatCell]] = [:]
    private var activeScale: AppHeatmapScalePreference = .logarithmic

    private var updateTask: Task<Void, Never>?
    private var densityPrecomputationTask: Task<Void, Never>?

    init(export: AppExport) {
        self.export = export
    }

    func startPrecomputation(scale: AppHeatmapScalePreference) {
        guard densityPoints.isEmpty, !isCalculating else { return }
        activeScale = scale
        isCalculating = true
        let snapshot = export

        Task.detached(priority: .userInitiated) {
            var points: [WeightedPoint] = []
            var dayDates: [String] = []
            for day in snapshot.data.days {
                dayDates.append(day.date)
                for visit in day.visits {
                    if let lat = visit.lat, let lon = visit.lon {
                        points.append(WeightedPoint(lat: lat, lon: lon, weight: 3))
                    }
                }
                for path in day.paths {
                    for point in path.points {
                        points.append(WeightedPoint(lat: point.lat, lon: point.lon, weight: 1))
                    }
                    if let flats = path.flatCoordinates {
                        for index in stride(from: 0, to: flats.count - 1, by: 2) {
                            points.append(WeightedPoint(lat: flats[index], lon: flats[index + 1], weight: 1))
                        }
                    }
                }
                for activity in day.activities {
                    if let lat = activity.startLat, let lon = activity.startLon {
                        points.append(WeightedPoint(lat: lat, lon: lon, weight: 1))
                    }
                    if let lat = activity.endLat, let lon = activity.endLon {
                        points.append(WeightedPoint(lat: lat, lon: lon, weight: 1))
                    }
                    if let flats = activity.flatCoordinates {
                        for index in stride(from: 0, to: flats.count - 1, by: 2) {
                            points.append(WeightedPoint(lat: flats[index], lon: flats[index + 1], weight: 1))
                        }
                    }
                }
            }

            let dataRegion = Self.regionThatFits(points: points)
            let completedPoints = points
            let centerCoord = dataRegion.map { region in
                CLLocationCoordinate2D(
                    latitude: region.center.latitude,
                    longitude: region.center.longitude
                )
            } ?? points.first.map {
                CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
            }
            let fallbackRegion = centerCoord.map {
                MKCoordinateRegion(
                    center: $0,
                    span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                )
            }

            let sortedDates = dayDates.sorted()
            let stats = HeatmapStats(
                totalPoints: completedPoints.count,
                dayCount: sortedDates.count,
                firstDate: sortedDates.first,
                lastDate: sortedDates.last
            )

            await MainActor.run {
                self.densityPoints = completedPoints
                self.lodGrids = [:]
                self.viewportCache = [:]
                self.initialCenter = centerCoord
                self.dataRegion = dataRegion
                self.stats = stats
                self.isCalculating = false

                let region = self.lastRegion ?? dataRegion ?? fallbackRegion
                if let region {
                    self.ensureDensityPrecomputation(for: region)
                }
            }
        }
    }

    /// Call when the user changes the scale preference. Invalidates the
    /// pre-computed LOD grids so they get rebuilt with the new mapping.
    func updateScale(_ newScale: AppHeatmapScalePreference) {
        guard newScale != activeScale else { return }
        activeScale = newScale
        lodGrids = [:]
        viewportCache = [:]
        densityPrecomputationTask?.cancel()
        densityPrecomputationTask = nil
        if let region = lastRegion {
            ensureDensityPrecomputation(for: region)
        }
    }

    func debounceUpdateForRegion(_ region: MKCoordinateRegion) {
        lastRegion = region
        updateTask?.cancel()
        updateTask = Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard !Task.isCancelled else { return }
            performCulling(region: region)
        }
    }

    func updateForRegion(_ region: MKCoordinateRegion) {
        updateTask?.cancel()
        lastRegion = region
        performCulling(region: region)
    }

    private func performCulling(region: MKCoordinateRegion) {
        let lod = HeatmapLOD.optimalLOD(for: region.span.latitudeDelta)

        guard let fullGrid = lodGrids[lod] else {
            visibleCells = []
            ensureDensityPrecomputation(for: region)
            return
        }

        let viewportKey = HeatmapViewportKey(region: region, lod: lod)
        if let cached = viewportCache[viewportKey] {
            visibleCells = cached
        } else {
            let culled = HeatmapGridBuilder.visibleCells(in: fullGrid, viewportKey: viewportKey)
            viewportCache[viewportKey] = culled
            visibleCells = culled
        }
    }

    private func ensureDensityPrecomputation(for region: MKCoordinateRegion) {
        lastRegion = region

        if !lodGrids.isEmpty {
            performCulling(region: region)
            return
        }

        guard !densityPoints.isEmpty else {
            visibleCells = []
            return
        }

        guard densityPrecomputationTask == nil else { return }
        isCalculating = true
        let points = densityPoints
        let scale = activeScale

        densityPrecomputationTask = Task.detached(priority: .utility) {
            var generatedGrids: [HeatmapLOD: [GridKey: HeatCell]] = [:]
            for lod in HeatmapLOD.allCases {
                generatedGrids[lod] = HeatmapGridBuilder.computeGrid(for: points, lod: lod, scale: scale)
            }
            let completedGrids = generatedGrids

            await MainActor.run {
                self.lodGrids = completedGrids
                self.viewportCache = [:]
                self.densityPrecomputationTask = nil
                self.isCalculating = false
                self.performCulling(region: self.lastRegion ?? region)
            }
        }
    }

    nonisolated private static func regionThatFits(points: [WeightedPoint]) -> MKCoordinateRegion? {
        guard let first = points.first else { return nil }

        var minLat = first.lat
        var maxLat = first.lat
        var minLon = first.lon
        var maxLon = first.lon

        for point in points.dropFirst() {
            minLat = min(minLat, point.lat)
            maxLat = max(maxLat, point.lat)
            minLon = min(minLon, point.lon)
            maxLon = max(maxLon, point.lon)
        }

        let latPadding = max((maxLat - minLat) * 0.2, 0.02)
        let lonPadding = max((maxLon - minLon) * 0.2, 0.02)

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2.0,
                longitude: (minLon + maxLon) / 2.0
            ),
            span: MKCoordinateSpan(
                latitudeDelta: min(max((maxLat - minLat) + latPadding, 0.04), 160.0),
                longitudeDelta: min(max((maxLon - minLon) + lonPadding, 0.04), 320.0)
            )
        )
    }
}
#endif
