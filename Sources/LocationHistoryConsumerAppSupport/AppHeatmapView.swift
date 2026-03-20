#if canImport(SwiftUI) && canImport(MapKit)
import SwiftUI
import MapKit
import LocationHistoryConsumer

/// A professional-grade heatmap that adapts its resolution to the map's zoom level
/// and uses spatial pre-processing for near-instant re-calculation.
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
                // Use MapPolygon for high-performance vector rendering of grid cells.
                // We use id: \.id to ensure SwiftUI can efficiently track changes.
                ForEach(model.heatCells) { cell in
                    MapPolygon(coordinates: cell.polygonPoints)
                        .foregroundStyle(cell.color.opacity(cell.opacity))
                }
            }
            .mapStyle(preferences.preferredMapStyle.isHybrid ? .hybrid : .standard)
            .ignoresSafeArea(edges: .top)
            .onMapCameraChange(frequency: .continuous) { context in
                // High-precision reactive updates:
                // When the user zooms, we re-calculate the binning at the new resolution.
                model.updateForRegion(context.region)
            }

            // Status indicator for background computation
            if model.isCalculating {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Optimizing heatmap…")
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
        .animation(.default, value: model.heatCells.count)
        .onAppear {
            if isFirstLoad {
                centerOnData()
                isFirstLoad = false
            }
        }
    }

    private func centerOnData() {
        // Initial positioning based on the most frequent cluster
        if let best = model.primaryCoordinate {
            mapPosition = .region(MKCoordinateRegion(
                center: best,
                span: MKCoordinateSpan(latitudeDelta: 1.5, longitudeDelta: 1.5)
            ))
        }
    }
}

// MARK: - ViewModel

@available(iOS 17.0, macOS 14.0, *)
@Observable
@MainActor
final class AppHeatmapModel {
    // Current visible result
    var heatCells: [HeatCell] = []
    var isCalculating = false
    var primaryCoordinate: CLLocationCoordinate2D?

    // Pre-processed data for fast iteration
    private let allPoints: [WeightedPoint]
    private var lastCalculationWorkItem: Task<Void, Never>?
    private var lastCalculatedSpan: Double = 0

    init(export: AppExport) {
        // Step 1: Pre-process the tree-like AppExport into a flat, weighted array.
        // This is done once at init to make subsequent binning O(N).
        var points: [WeightedPoint] = []
        for day in export.data.days {
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
        self.allPoints = points
        
        // Initial "dumb" average for centering
        if let first = points.first {
            self.primaryCoordinate = CLLocationCoordinate2D(latitude: first.lat, longitude: first.lon)
        }
    }

    func updateForRegion(_ region: MKCoordinateRegion) {
        // Debouncing / Thresholding:
        // Only re-calculate if the zoom level (span) changed significantly (e.g. > 20%).
        let spanDelta = abs(region.span.latitudeDelta - lastCalculatedSpan) / max(0.0001, lastCalculatedSpan)
        guard spanDelta > 0.2 || heatCells.isEmpty else { return }
        
        lastCalculationWorkItem?.cancel()
        lastCalculationWorkItem = Task {
            isCalculating = true
            
            // Adaptive Grid Size:
            // High zoom -> small cells (0.001°), Low zoom -> large cells (0.1°)
            let step = calculateOptimalStep(for: region.span.latitudeDelta)
            let result = await Task.detached(priority: .userInitiated) {
                Self.binPoints(self.allPoints, step: step)
            }.value
            
            if !Task.isCancelled {
                self.heatCells = result
                self.lastCalculatedSpan = region.span.latitudeDelta
                self.isCalculating = false
            }
        }
    }

    private func calculateOptimalStep(for span: Double) -> Double {
        // Heuristic: target ~100-500 cells on screen for perfect balance of detail vs performance
        if span < 0.05 { return 0.001 }  // High zoom: ~100m grid
        if span < 0.5  { return 0.005 }  // Med zoom: ~500m grid
        if span < 5.0  { return 0.02  }  // Low zoom: ~2km grid
        return 0.1                       // Bird's eye: ~10km grid
    }

    private static func binPoints(_ points: [WeightedPoint], step: Double) -> [HeatCell] {
        var grid: [Int64: Int] = [:]
        
        // Use an Int64 bit-packed key for maximum dictionary performance
        // (latBin in high 32 bits, lonBin in low 32 bits)
        for p in points {
            let latBin = Int32(floor(p.lat / step))
            let lonBin = Int32(floor(p.lon / step))
            let key = (Int64(latBin) << 32) | (Int64(UInt32(bitPattern: lonBin)))
            grid[key, default: 0] += p.weight
        }

        guard !grid.isEmpty else { return [] }
        let maxCount = Double(grid.values.max() ?? 1)
        
        return grid.map { key, count in
            let latBin = Int32(key >> 32)
            let lonBin = Int32(truncatingIfNeeded: key)
            
            let normalized = Double(count) / maxCount
            let color: Color
            switch normalized {
            case 0..<0.2: color = .blue
            case 0.2..<0.4: color = .cyan
            case 0.4..<0.6: color = .green
            case 0.6..<0.8: color = .yellow
            default: color = .red
            }
            
            let minLat = Double(latBin) * step
            let maxLat = minLat + step
            let minLon = Double(lonBin) * step
            let maxLon = minLon + step
            
            return HeatCell(
                id: key,
                polygonPoints: [
                    CLLocationCoordinate2D(latitude: minLat, longitude: minLon),
                    CLLocationCoordinate2D(latitude: maxLat, longitude: minLon),
                    CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon),
                    CLLocationCoordinate2D(latitude: minLat, longitude: maxLon),
                    CLLocationCoordinate2D(latitude: minLat, longitude: minLon)
                ],
                opacity: 0.3 + normalized * 0.5,
                color: color
            )
        }
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
    let polygonPoints: [CLLocationCoordinate2D]
    let opacity: Double
    let color: Color
}

#endif
