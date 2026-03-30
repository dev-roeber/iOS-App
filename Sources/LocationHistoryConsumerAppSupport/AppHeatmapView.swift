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

    @State private var model: AppHeatmapModel
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var isFirstLoad = true
    @State private var overlayOpacity = 0.7
    @State private var radiusPreset: HeatmapRadiusPreset = .balanced

    public init(export: AppExport) {
        self.export = export
        self._model = State(initialValue: AppHeatmapModel(export: export))
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }

    public var body: some View {
        ZStack {
            mapView
            if model.isCalculating {
                calculatingOverlay
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if model.hasData {
                controlsOverlay
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.visibleCells.count)
        .onAppear {
            if isFirstLoad {
                model.startPrecomputation()
                isFirstLoad = false
            }
        }
        .onChange(of: model.initialCenter) { _, newCenter in
            if let center = newCenter {
                seedInitialViewport(center: center)
            }
        }
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    @ViewBuilder
    private var mapView: some View {
        Map(position: $mapPosition) {
            ForEach(model.visibleCells) { cell in
                MapCircle(center: cell.coordinate, radius: effectiveRadius(for: cell))
                    .foregroundStyle(cell.color.opacity(effectiveOpacity(for: cell)))
            }
        }
        .mapStyle(preferences.preferredMapStyle.isHybrid ? .hybrid : .standard)
        .ignoresSafeArea(edges: .top)
        .onMapCameraChange(frequency: .onEnd) { context in
            model.updateForRegion(context.region)
        }
        .onMapCameraChange(frequency: .continuous) { context in
            model.debounceUpdateForRegion(context.region)
        }
    }

    @ViewBuilder
    private var calculatingOverlay: some View {
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

    @ViewBuilder
    private var controlsOverlay: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button(action: fitToData) {
                    Label(t("Fit to data"), systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.dataRegion == nil)

                Spacer(minLength: 12)

                Text(t("Controls affect display only."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(t("Opacity"))
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text("\(Int((overlayOpacity * 100).rounded()))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $overlayOpacity, in: 0.35...1.0)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(t("Radius"))
                    .font(.caption.weight(.semibold))
                Picker(t("Radius"), selection: $radiusPreset) {
                    ForEach(HeatmapRadiusPreset.allCases) { preset in
                        Text(t(preset.labelKey)).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            densityLegend
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal)
        .padding(.bottom, 8)
        .controlSize(.small)
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
    }

    @ViewBuilder
    private var densityLegend: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(t("Low density"))
                Spacer()
                Text(t("High density"))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            LinearGradient(
                colors: [
                    Color(red: 0.0, green: 0.2, blue: 0.8).opacity(0.35),
                    Color(red: 0.0, green: 0.8, blue: 0.8).opacity(0.45),
                    Color(red: 0.2, green: 0.8, blue: 0.2).opacity(0.55),
                    Color(red: 1.0, green: 0.8, blue: 0.0).opacity(0.65),
                    Color(red: 1.0, green: 0.2, blue: 0.2).opacity(0.75),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 7)
            .clipShape(Capsule())
        }
    }

    private func seedInitialViewport(center: CLLocationCoordinate2D) {
        if let region = model.dataRegion {
            mapPosition = .region(region)
            model.updateForRegion(region)
            return
        }

        let fallback = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
        mapPosition = .region(fallback)
        model.updateForRegion(fallback)
    }

    private func fitToData() {
        guard let region = model.dataRegion else { return }
        mapPosition = .region(region)
        model.updateForRegion(region)
    }

    private func effectiveOpacity(for cell: HeatCell) -> Double {
        let emphasis = 0.6 + (cell.normalizedIntensity * 0.5)
        let value = cell.opacity * overlayOpacity * cell.lod.overlayOpacityMultiplier * emphasis
        return min(max(value, 0.08), 0.72)
    }

    private func effectiveRadius(for cell: HeatCell) -> Double {
        let value = cell.radius * radiusPreset.scale * cell.lod.overlayRadiusMultiplier
        return max(value, cell.lod.baseRadius * 0.45)
    }
}

// MARK: - Level of Detail (LOD)

enum HeatmapLOD: CaseIterable {
    case macro
    case low
    case medium
    case high

    var step: Double {
        switch self {
        case .macro: return 0.25
        case .low: return 0.05
        case .medium: return 0.01
        case .high: return 0.002
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

    var overlayOpacityMultiplier: Double {
        switch self {
        case .macro: return 0.45
        case .low: return 0.6
        case .medium: return 0.78
        case .high: return 0.95
        }
    }

    var overlayRadiusMultiplier: Double {
        switch self {
        case .macro: return 0.55
        case .low: return 0.72
        case .medium: return 0.9
        case .high: return 1.0
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
    var visibleCells: [HeatCell] = []
    var isCalculating = false
    var initialCenter: CLLocationCoordinate2D?
    var dataRegion: MKCoordinateRegion?
    var hasData: Bool { dataRegion != nil }

    private let export: AppExport
    private var lodGrids: [HeatmapLOD: [GridKey: HeatCell]] = [:]

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
            var points: [WeightedPoint] = []
            for day in snapshot.data.days {
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

            var generatedGrids: [HeatmapLOD: [GridKey: HeatCell]] = [:]
            for lod in HeatmapLOD.allCases {
                generatedGrids[lod] = Self.computeGrid(for: points, lod: lod)
            }

            let centerCoord: CLLocationCoordinate2D?
            if let mediumGrid = generatedGrids[.medium],
               let denseCell = mediumGrid.values.max(by: { $0.count < $1.count }) {
                centerCoord = denseCell.coordinate
            } else if let first = points.first {
                centerCoord = CLLocationCoordinate2D(latitude: first.lat, longitude: first.lon)
            } else {
                centerCoord = nil
            }

            let dataRegion = Self.regionThatFits(points: points)
            let completedGrids = generatedGrids
            let fallbackRegion = centerCoord.map {
                MKCoordinateRegion(
                    center: $0,
                    span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                )
            }

            await MainActor.run {
                self.lodGrids = completedGrids
                self.initialCenter = centerCoord
                self.dataRegion = dataRegion
                self.isCalculating = false

                let region = self.lastRegion ?? dataRegion ?? fallbackRegion

                if let region {
                    self.performCulling(region: region)
                }
            }
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
        guard !lodGrids.isEmpty else { return }
        let lod = HeatmapLOD.optimalLOD(for: region.span.latitudeDelta)
        guard let fullGrid = lodGrids[lod] else { return }

        let marginLat = region.span.latitudeDelta * 0.2
        let marginLon = region.span.longitudeDelta * 0.2
        let minLat = region.center.latitude - (region.span.latitudeDelta / 2) - marginLat
        let maxLat = region.center.latitude + (region.span.latitudeDelta / 2) + marginLat
        let minLon = region.center.longitude - (region.span.longitudeDelta / 2) - marginLon
        let maxLon = region.center.longitude + (region.span.longitudeDelta / 2) + marginLon

        var culled: [HeatCell] = []
        for cell in fullGrid.values {
            if cell.coordinate.latitude >= minLat && cell.coordinate.latitude <= maxLat &&
                cell.coordinate.longitude >= minLon && cell.coordinate.longitude <= maxLon {
                culled.append(cell)
            }
        }

        culled.sort { $0.count < $1.count }
        visibleCells = culled
    }

    nonisolated private static func computeGrid(for points: [WeightedPoint], lod: HeatmapLOD) -> [GridKey: HeatCell] {
        var grid: [GridKey: Int] = [:]
        let step = lod.step

        for point in points {
            let latBin = Int32(floor(point.lat / step))
            let lonBin = Int32(floor(point.lon / step))
            let key = GridKey(lat: latBin, lon: lonBin)
            grid[key, default: 0] += point.weight
        }

        guard !grid.isEmpty else { return [:] }
        let maxCount = Double(grid.values.max() ?? 1)

        var result: [GridKey: HeatCell] = [:]
        result.reserveCapacity(grid.count)

        for (key, count) in grid {
            let normalized = Double(count) / maxCount

            let color: Color
            switch normalized {
            case 0..<0.15:
                color = Color(red: 0.0, green: 0.2, blue: 0.8)
            case 0.15..<0.35:
                color = Color(red: 0.0, green: 0.8, blue: 0.8)
            case 0.35..<0.6:
                color = Color(red: 0.2, green: 0.8, blue: 0.2)
            case 0.6..<0.85:
                color = Color(red: 1.0, green: 0.8, blue: 0.0)
            default:
                color = Color(red: 1.0, green: 0.2, blue: 0.2)
            }

            let centerLat = (Double(key.lat) * step) + (step / 2.0)
            let centerLon = (Double(key.lon) * step) + (step / 2.0)
            let radiusMultiplier = 1.2 + (normalized * 0.5)

            result[key] = HeatCell(
                gridKey: key,
                coordinate: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                radius: lod.baseRadius * radiusMultiplier,
                count: count,
                opacity: 0.35 + (normalized * 0.5),
                color: color,
                lod: lod,
                normalizedIntensity: normalized
            )
        }

        return result
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

// MARK: - Supporting Types

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

struct GridKey: Hashable, Equatable {
    let lat: Int32
    let lon: Int32
}

struct WeightedPoint {
    let lat: Double
    let lon: Double
    let weight: Int
}

struct HeatCell: Identifiable {
    var id: GridKey { gridKey }
    let gridKey: GridKey
    let coordinate: CLLocationCoordinate2D
    let radius: Double
    let count: Int
    let opacity: Double
    let color: Color
    let lod: HeatmapLOD
    let normalizedIntensity: Double
}

private enum HeatmapRadiusPreset: String, CaseIterable, Identifiable {
    case compact
    case balanced
    case wide

    var id: String { rawValue }

    var scale: Double {
        switch self {
        case .compact: return 0.72
        case .balanced: return 0.9
        case .wide: return 1.12
        }
    }

    var labelKey: String {
        switch self {
        case .compact: return "Compact"
        case .balanced: return "Standard"
        case .wide: return "Wide"
        }
    }
}

#endif
