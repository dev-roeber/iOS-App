#if canImport(SwiftUI) && canImport(MapKit)
import SwiftUI
import MapKit
import LocationHistoryConsumer

/// A professional-grade heatmap that uses Level-Of-Detail (LOD) pre-computation
/// and Viewport-Culling for 60FPS rendering of massive datasets.
@available(iOS 17.0, macOS 14.0, *)
public struct AppHeatmapView: View {
    private let export: AppExport
    @EnvironmentObject private var preferences: AppPreferences
    
    // Core state
    @State private var model: AppHeatmapModel
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var isFirstLoad = true

    public init(export: AppExport) {
        self.export = export
        self._model = State(initialValue: AppHeatmapModel(export: export))
    }

    public var body: some View {
        ZStack {
            Map(position: $mapPosition) {
                // Use MapCircle with overlapping radii for a smooth, organic heatmap look.
                // The cells are already viewport-culled, so SwiftUI only renders what is strictly necessary.
                ForEach(model.visibleCells) { cell in
                    MapCircle(center: cell.coordinate, radius: cell.radius)
                        .foregroundStyle(cell.color.opacity(cell.opacity))
                }
            }
            .mapStyle(preferences.preferredMapStyle.isHybrid ? .hybrid : .standard)
            .ignoresSafeArea(edges: .top)
            .onMapCameraChange(frequency: .onEnd) { context in
                // High-performance reactive updates:
                // We use 'onEnd' or a debounced continuous update to slice the pre-computed grid.
                model.updateForRegion(context.region)
            }
            .onMapCameraChange(frequency: .continuous) { context in
                model.debounceUpdateForRegion(context.region)
            }

            // Status indicator for background pre-computation
            if model.isCalculating {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Pre-computing LOD clusters…")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
                    .padding()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("Heatmap")
        .animation(.easeInOut(duration: 0.3), value: model.visibleCells.count)
        .onAppear {
            if isFirstLoad {
                model.startPrecomputation()
                isFirstLoad = false
            }
        }
        .onChange(of: model.initialCenter) { _, newCenter in
            if let center = newCenter {
                mapPosition = .region(MKCoordinateRegion(
                    center: center,
                    span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                ))
            }
        }
    }
}

// MARK: - Level of Detail (LOD)

enum HeatmapLOD: CaseIterable {
    case macro      // Whole country/continent
    case low        // State/Region
    case medium     // City
    case high       // Neighborhood/Street
    
    var step: Double {
        switch self {
        case .macro: return 0.25     // ~25km
        case .low: return 0.05       // ~5km
        case .medium: return 0.01    // ~1km
        case .high: return 0.002     // ~200m
        }
    }
    
    var baseRadius: Double {
        switch self {
        case .macro: return 20000
        case .low: return 4000
        case .medium: return 800
        case .high: return 180
        }
    }
    
    static func optimalLOD(for spanDelta: Double) -> HeatmapLOD {
        if spanDelta > 5.0 { return .macro }
        if spanDelta > 1.0 { return .low }
        if spanDelta > 0.1 { return .medium }
        return .high
    }
}

// MARK: - ViewModel

@available(iOS 17.0, macOS 14.0, *)
@Observable @MainActor
final class AppHeatmapModel {
    // Current visible result (viewport culled)
    var visibleCells: [HeatCell] = []
    var isCalculating = false
    var initialCenter: CLLocationCoordinate2D?

    // Pre-processed data
    private let export: AppExport
    // The pre-computed dictionaries for each LOD. Key is the packed Int64.
    private var lodGrids: [HeatmapLOD: [Int64: HeatCell]] = [:]
    
    private var lastRegion: MKCoordinateRegion?
    private var updateTask: Task<Void, Never>?

    init(export: AppExport) {
        self.export = export
    }

    func startPrecomputation() {
        guard lodGrids.isEmpty, !isCalculating else { return }
        isCalculating = true
        let snapshot = export
        
        Task.detached(priority: .userInitiated) {
            // 1. Flatten all coordinates
            var points: [WeightedPoint] = []
            for day in snapshot.data.days {
                for v in day.visits {
                    if let lat = v.lat, let lon = v.lon {
                        points.append(WeightedPoint(lat: lat, lon: lon, weight: 3))
                    }
                }
                for p in day.paths {
                    for pt in p.points {
                        points.append(WeightedPoint(lat: pt.lat, lon: pt.lon, weight: 1))
                    }
                }
                for a in day.activities {
                    if let lat = a.startLat, let lon = a.startLon {
                        points.append(WeightedPoint(lat: lat, lon: lon, weight: 1))
                    }
                }
            }
            
            // 2. Pre-compute grids for all LODs
            var generatedGrids: [HeatmapLOD: [Int64: HeatCell]] = [:]
            for lod in HeatmapLOD.allCases {
                generatedGrids[lod] = Self.computeGrid(for: points, lod: lod)
            }
            
            // 3. Find center based on highest density in the medium LOD
            var centerCoord: CLLocationCoordinate2D?
            if let mediumGrid = generatedGrids[.medium],
               let denseCell = mediumGrid.values.max(by: { $0.count < $1.count }) {
                centerCoord = denseCell.coordinate
            } else if let first = points.first {
                centerCoord = CLLocationCoordinate2D(latitude: first.lat, longitude: first.lon)
            }
            
            await MainActor.run {
                self.lodGrids = generatedGrids
                self.initialCenter = centerCoord
                self.isCalculating = false
                if let region = self.lastRegion {
                    self.performCulling(region: region)
                }
            }
        }
    }

    func debounceUpdateForRegion(_ region: MKCoordinateRegion) {
        // Light debouncing for continuous scrolling
        self.lastRegion = region
        updateTask?.cancel()
        updateTask = Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            guard !Task.isCancelled else { return }
            performCulling(region: region)
        }
    }

    func updateForRegion(_ region: MKCoordinateRegion) {
        updateTask?.cancel()
        self.lastRegion = region
        performCulling(region: region)
    }
    
    private func performCulling(region: MKCoordinateRegion) {
        guard !lodGrids.isEmpty else { return }
        let lod = HeatmapLOD.optimalLOD(for: region.span.latitudeDelta)
        guard let fullGrid = lodGrids[lod] else { return }
        
        // Define bounding box with a 20% overdraw margin so circles don't pop in
        let marginLat = region.span.latitudeDelta * 0.2
        let marginLon = region.span.longitudeDelta * 0.2
        let minLat = region.center.latitude - (region.span.latitudeDelta / 2) - marginLat
        let maxLat = region.center.latitude + (region.span.latitudeDelta / 2) + marginLat
        let minLon = region.center.longitude - (region.span.longitudeDelta / 2) - marginLon
        let maxLon = region.center.longitude + (region.span.longitudeDelta / 2) + marginLon
        
        // Culling: Only map cells that fall within the bounding box
        var culled: [HeatCell] = []
        // We iterate over the pre-computed grid. For typical viewports this yields a few hundred cells.
        for cell in fullGrid.values {
            if cell.coordinate.latitude >= minLat && cell.coordinate.latitude <= maxLat &&
               cell.coordinate.longitude >= minLon && cell.coordinate.longitude <= maxLon {
                culled.append(cell)
            }
        }
        
        // Sort to ensure "hotter" cells draw on top
        culled.sort { $0.count < $1.count }
        self.visibleCells = culled
    }

    nonisolated private static func computeGrid(for points: [WeightedPoint], lod: HeatmapLOD) -> [Int64: HeatCell] {
        var grid: [Int64: Int] = [:]
        let step = lod.step
        
        for p in points {
            let latBin = Int32(floor(p.lat / step))
            let lonBin = Int32(floor(p.lon / step))
            let key = (Int64(latBin) << 32) | (Int64(UInt32(bitPattern: lonBin)))
            grid[key, default: 0] += p.weight
        }

        guard !grid.isEmpty else { return [:] }
        let maxCount = Double(grid.values.max() ?? 1)
        
        var result: [Int64: HeatCell] = [:]
        result.reserveCapacity(grid.count)
        
        for (key, count) in grid {
            let latBin = Int32(key >> 32)
            let lonBin = Int32(truncatingIfNeeded: key)
            
            let normalized = Double(count) / maxCount
            
            // "Stunning Visuals" Color Gradient: Deep blue -> Cyan -> Green -> Yellow -> Bright Red
            let color: Color
            switch normalized {
            case 0..<0.15: color = Color(red: 0.0, green: 0.2, blue: 0.8) // Deep Blue
            case 0.15..<0.35: color = Color(red: 0.0, green: 0.8, blue: 0.8) // Cyan
            case 0.35..<0.6: color = Color(red: 0.2, green: 0.8, blue: 0.2) // Green
            case 0.6..<0.85: color = Color(red: 1.0, green: 0.8, blue: 0.0) // Yellow
            default: color = Color(red: 1.0, green: 0.2, blue: 0.2) // Red
            }
            
            let centerLat = (Double(latBin) * step) + (step / 2.0)
            let centerLon = (Double(lonBin) * step) + (step / 2.0)
            
            // Overlapping radii: The radius is slightly larger than the step size to blend adjacent cells
            // Hotter cells get slightly larger radii to create a blooming effect
            let radiusMultiplier = 1.2 + (normalized * 0.5)
            
            result[key] = HeatCell(
                id: key,
                coordinate: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                radius: lod.baseRadius * radiusMultiplier,
                count: count,
                opacity: 0.35 + (normalized * 0.5),
                color: color
            )
        }
        
        return result
    }
}

// MARK: - Supporting Types

struct WeightedPoint {
    let lat: Double
    let lon: Double
    let weight: Int
}

struct HeatCell: Identifiable {
    let id: Int64
    let coordinate: CLLocationCoordinate2D
    let radius: Double
    let count: Int
    let opacity: Double
    let color: Color
}

#endif
