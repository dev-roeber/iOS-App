#if canImport(SwiftUI) && canImport(MapKit)
import SwiftUI
import MapKit
import LocationHistoryConsumer

/// Aggregated statistics about the heatmap dataset — surfaced in the
/// sheet header so users can see "what they're looking at" at a glance.
///
/// Phase-10C: zusätzlich Truncation-Signale, falls der Sammel-Loop in
/// `AppHeatmapModel.startPrecomputation` durch das harte Density-Budget
/// (`AppHeatmapModel.densityPointCap`) limitiert wurde.
struct HeatmapStats: Equatable {
    let totalPoints: Int
    let dayCount: Int
    let firstDate: String?
    let lastDate: String?
    let truncatedDensityPoints: Bool

    init(totalPoints: Int,
         dayCount: Int,
         firstDate: String?,
         lastDate: String?,
         truncatedDensityPoints: Bool = false) {
        self.totalPoints = totalPoints
        self.dayCount = dayCount
        self.firstDate = firstDate
        self.lastDate = lastDate
        self.truncatedDensityPoints = truncatedDensityPoints
    }
}

@available(iOS 17.0, macOS 14.0, *)
@Observable @MainActor
final class AppHeatmapModel {
    /// Phase-10C — hartes Cap für die Anzahl der `WeightedPoint`-Einträge,
    /// die `startPrecomputation` aus dem Export sammelt. Größere Datensätze
    /// erzeugen ein `HeatmapStats.truncatedDensityPoints`-Signal, statt
    /// das Array unbounded wachsen zu lassen. 500 000 Punkte korrespondieren
    /// grob mit dem oberen Ende eines typischen Privatprofils auf einem
    /// iPhone 15 Pro Max bei medium LOD und liegen deutlich unter Jetsam-
    /// Schwellen für `WeightedPoint` (≈ 24 B / Eintrag → ≈ 12 MB).
    static let densityPointCap: Int = 500_000

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

        let cap = Self.densityPointCap

        Task.detached(priority: .userInitiated) {
            var points: [WeightedPoint] = []
            var dayDates: [String] = []
            var truncated = false
            // Phase-10C: hartes Cap auf den Sammel-Loop. Sobald `points.count`
            // den Schwellwert erreicht, wird die Iteration abgebrochen und
            // `HeatmapStats.truncatedDensityPoints` signalisiert. Das schützt
            // gegen Jetsam bei extremen Datensätzen, ohne die Reihenfolge der
            // ersten Tage/Visits/Paths/Activities zu verändern.
            collect: for day in snapshot.data.days {
                dayDates.append(day.date)
                for visit in day.visits {
                    if let lat = visit.lat, let lon = visit.lon {
                        if points.count >= cap { truncated = true; break collect }
                        points.append(WeightedPoint(lat: lat, lon: lon, weight: 3))
                    }
                }
                for path in day.paths {
                    // Phase-8B: Doppelbug-Fix zentralisiert in
                    // `AppHeatmapPathSampler`. Kanonische Priorität:
                    // flatCoordinates (wenn valide), sonst points-fallback.
                    // Hybrid-Daten zählen genau einmal.
                    for sample in AppHeatmapPathSampler.samples(forPath: path) {
                        if points.count >= cap { truncated = true; break collect }
                        points.append(WeightedPoint(lat: sample.lat, lon: sample.lon, weight: 1))
                    }
                }
                for activity in day.activities {
                    let split = AppHeatmapPathSampler.samples(forActivity: activity)
                    for marker in split.markers {
                        if points.count >= cap { truncated = true; break collect }
                        points.append(WeightedPoint(lat: marker.lat, lon: marker.lon, weight: 1))
                    }
                    for geo in split.geometry {
                        if points.count >= cap { truncated = true; break collect }
                        points.append(WeightedPoint(lat: geo.lat, lon: geo.lon, weight: 1))
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
                lastDate: sortedDates.last,
                truncatedDensityPoints: truncated
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
