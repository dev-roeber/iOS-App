#if canImport(SwiftUI) && canImport(MapKit)
import SwiftUI
import MapKit
import LocationHistoryConsumer

@available(iOS 17.0, macOS 14.0, *)
public struct AppHeatmapView: View {
    private let export: AppExport
    @EnvironmentObject private var preferences: AppPreferences
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var heatCells: [HeatCell] = []
    @State private var isBuilding = false

    public init(export: AppExport) {
        self.export = export
    }

    public var body: some View {
        ZStack {
            Map(position: $mapPosition) {
                ForEach(heatCells) { cell in
                    MapPolygon(coordinates: cell.polygonPoints)
                        .foregroundStyle(cell.color.opacity(cell.opacity))
                }
            }
            .mapStyle(preferences.preferredMapStyle.isHybrid ? .hybrid : .standard)
            .ignoresSafeArea(edges: .top)

            if isBuilding {
                VStack {
                    Spacer()
                    HStack {
                        ProgressView()
                        Text("Building heatmap…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding()
                }
            }
        }
        .navigationTitle("Heatmap")
        .task {
            await buildHeatmap()
        }
    }

    private func buildHeatmap() async {
        isBuilding = true
        let snapshot = export
        let cells = await Task.detached(priority: .userInitiated) {
            Self.computeHeatCells(from: snapshot)
        }.value
        heatCells = cells
        if let first = cells.max(by: { $0.count < $1.count }) {
            mapPosition = .region(MKCoordinateRegion(
                center: first.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 1.5, longitudeDelta: 1.5)
            ))
        }
        isBuilding = false
    }

    // Gittergrösse: ~0.005° ≈ 500m — Konstante liegt als fileprivate heatmapGridStep auf File-Ebene

    private static func computeHeatCells(from export: AppExport) -> [HeatCell] {
        var grid: [GridKey: Int] = [:]

        for day in export.data.days {
            // Visits
            for visit in day.visits {
                guard let lat = visit.lat, let lon = visit.lon else { continue }
                let key = GridKey(lat: lat, lon: lon)
                grid[key, default: 0] += 3  // Visits höher gewichten
            }
            // Path points
            for path in day.paths {
                for point in path.points {
                    let key = GridKey(lat: point.lat, lon: point.lon)
                    grid[key, default: 0] += 1
                }
                // Flat coordinates fallback
                if path.points.isEmpty, let flat = path.flatCoordinates, flat.count >= 2 {
                    var i = 0
                    while i + 1 < flat.count {
                        let key = GridKey(lat: flat[i], lon: flat[i + 1])
                        grid[key, default: 0] += 1
                        i += 2
                    }
                }
            }
            // Activities
            for activity in day.activities {
                if let lat = activity.startLat, let lon = activity.startLon {
                    let key = GridKey(lat: lat, lon: lon)
                    grid[key, default: 0] += 1
                }
                if let flat = activity.flatCoordinates, flat.count >= 2 {
                    var i = 0
                    while i + 1 < flat.count {
                        let key = GridKey(lat: flat[i], lon: flat[i + 1])
                        grid[key, default: 0] += 1
                        i += 2
                    }
                }
            }
        }

        guard !grid.isEmpty else { return [] }
        let maxCount = Double(grid.values.max() ?? 1)

        let step = heatmapGridStep
        var cells: [HeatCell] = []
        cells.reserveCapacity(grid.count)
        for (key, count) in grid {
            let normalized = Double(count) / maxCount
            let color: Color
            switch normalized {
            case 0..<0.2: color = .blue
            case 0.2..<0.4: color = .cyan
            case 0.4..<0.6: color = .green
            case 0.6..<0.8: color = .yellow
            default: color = .red
            }
            
            let minLat = Double(key.latBin) * step
            let maxLat = minLat + step
            let minLon = Double(key.lonBin) * step
            let maxLon = minLon + step
            
            let polygonPoints = [
                CLLocationCoordinate2D(latitude: minLat, longitude: minLon),
                CLLocationCoordinate2D(latitude: maxLat, longitude: minLon),
                CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon),
                CLLocationCoordinate2D(latitude: minLat, longitude: maxLon),
                CLLocationCoordinate2D(latitude: minLat, longitude: minLon)
            ]
            
            let cell = HeatCell(
                id: key,
                coordinate: CLLocationCoordinate2D(latitude: minLat + step / 2, longitude: minLon + step / 2),
                polygonPoints: polygonPoints,
                count: count,
                opacity: min(0.25 + normalized * 0.55, 0.8),
                color: color
            )
            cells.append(cell)
        }
        return cells
    }
}

// MARK: - Supporting Types

fileprivate let heatmapGridStep = 0.01

fileprivate struct GridKey: Hashable, Equatable {
    let latBin: Int
    let lonBin: Int

    init(lat: Double, lon: Double) {
        self.latBin = Int(floor(lat / heatmapGridStep))
        self.lonBin = Int(floor(lon / heatmapGridStep))
    }
}

fileprivate struct HeatCell: Identifiable {
    let id: GridKey
    let coordinate: CLLocationCoordinate2D
    let polygonPoints: [CLLocationCoordinate2D]
    let count: Int
    let opacity: Double
    let color: Color
}

#endif
