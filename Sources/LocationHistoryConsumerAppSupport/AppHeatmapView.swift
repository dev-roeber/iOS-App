#if canImport(SwiftUI) && canImport(MapKit)
import SwiftUI
import MapKit
import LocationHistoryConsumer

/// A professional-grade heatmap that uses Level-Of-Detail (LOD) pre-computation,
/// viewport-bounded bin selection, and smoothed raster cells instead of visible circle stamps.
@available(iOS 17.0, macOS 14.0, *)
public struct AppHeatmapView: View {
    private let export: AppExport
    @EnvironmentObject private var preferences: AppPreferences

    @State private var model: AppHeatmapModel
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var isFirstLoad = true
    @State private var overlayOpacity = 0.75
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
                MapPolygon(coordinates: scaledPolygonCoordinates(for: cell))
                    .foregroundStyle(cell.color.opacity(effectiveOpacity(for: cell)))
            }
        }
        .mapStyle(densityMapStyle)
        .ignoresSafeArea(edges: .top)
        .onMapCameraChange(frequency: .onEnd) { context in
            model.updateForRegion(context.region)
        }
        .onMapCameraChange(frequency: .continuous) { context in
            model.debounceUpdateForRegion(context.region)
        }
    }

    private var densityMapStyle: MapStyle {
        if preferences.preferredMapStyle.isHybrid { return .hybrid }
        return .standard()
    }

    @ViewBuilder
    private var calculatingOverlay: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(t("Computing heatmap…"))
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
        ScrollView(.vertical, showsIndicators: false) {
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
                Slider(value: $overlayOpacity, in: 0.15...1.0)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(t("Radius"))
                    .font(.caption.weight(.semibold))
                HStack(spacing: 8) {
                    ForEach(HeatmapRadiusPreset.allCases) { preset in
                        Button {
                            radiusPreset = preset
                        } label: {
                            Text(t(preset.labelKey))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(radiusPreset == preset ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.08))
                                .foregroundStyle(radiusPreset == preset ? Color.accentColor : Color.primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
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
        .frame(maxHeight: 260)
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
                    HeatmapPalette.color(for: 0.06).opacity(0.64),
                    HeatmapPalette.color(for: 0.18).opacity(0.74),
                    HeatmapPalette.color(for: 0.38).opacity(0.82),
                    HeatmapPalette.color(for: 0.66).opacity(0.90),
                    HeatmapPalette.color(for: 0.98).opacity(0.94),
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
        HeatmapVisualStyle.effectiveOpacity(
            cellOpacity: cell.opacity,
            normalizedIntensity: cell.normalizedIntensity,
            overlayOpacity: overlayOpacity,
            lod: cell.lod
        )
    }

    private func scaledPolygonCoordinates(for cell: HeatCell) -> [CLLocationCoordinate2D] {
        let stepLat = cell.cellSpan * radiusPreset.scale
        let latRad = cell.coordinate.latitude * .pi / 180.0
        let lonScale = max(cos(latRad), 0.05)
        let stepLon = stepLat / lonScale
        return HeatmapGridBuilder.polygonCoordinates(
            centerLat: cell.coordinate.latitude,
            centerLon: cell.coordinate.longitude,
            stepLat: stepLat,
            stepLon: stepLon
        )
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
        case .macro: return 2.5
        case .low: return 0.08
        case .medium: return 0.012
        case .high: return 0.001
        }
    }

    var overlayOpacityMultiplier: Double {
        switch self {
        case .macro: return 0.42
        case .low: return 0.54
        case .medium: return 0.82
        case .high: return 0.98
        }
    }

    var tileSpanMultiplier: Double {
        switch self {
        case .macro: return 1.75
        case .low: return 1.55
        case .medium: return 1.40
        case .high: return 1.25
        }
    }

    var selectionLimit: Int {
        switch self {
        case .macro: return 36
        case .low: return 72
        case .medium: return 280
        case .high: return 1200
        }
    }

    var minimumNormalizedIntensity: Double {
        switch self {
        case .macro: return 0.025
        case .low: return 0.032
        case .medium: return 0.010
        case .high: return 0.0045
        }
    }

    var viewportPaddingFactor: Double {
        switch self {
        case .macro: return 0.08
        case .low: return 0.12
        case .medium: return 0.16
        case .high: return 0.2
        }
    }

    var smoothingKernel: [HeatKernelOffset] {
        switch self {
        case .macro:
            return HeatKernelOffset.gaussian(center: 1.0, edge: 0.65, corner: 0.35)
        case .low:
            return HeatKernelOffset.gaussian(center: 1.0, edge: 0.62, corner: 0.28)
        case .medium:
            return HeatKernelOffset.gaussian(center: 1.0, edge: 0.48, corner: 0.15)
        case .high:
            return HeatKernelOffset.gaussian(center: 1.0, edge: 0.24, corner: 0.07)
        }
    }

    var precomputationVisibilityFactor: Double {
        switch self {
        case .macro: return 0.45
        case .low: return 0.40
        case .medium: return 0.28
        case .high: return 0.18
        }
    }

    static func optimalLOD(for spanDelta: Double) -> HeatmapLOD {
        if spanDelta > 12.0 { return .macro }
        if spanDelta > 1.0 { return .low }
        if spanDelta > 0.12 { return .medium }
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
    private(set) var lastRegion: MKCoordinateRegion?

    private let export: AppExport
    private var densityPoints: [WeightedPoint] = []
    private var lodGrids: [HeatmapLOD: [GridKey: HeatCell]] = [:]
    private var viewportCache: [HeatmapViewportKey: [HeatCell]] = [:]

    private var updateTask: Task<Void, Never>?
    private var densityPrecomputationTask: Task<Void, Never>?

    init(export: AppExport) {
        self.export = export
    }

    func startPrecomputation() {
        guard densityPoints.isEmpty, !isCalculating else { return }
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

            await MainActor.run {
                self.densityPoints = completedPoints
                self.lodGrids = [:]
                self.viewportCache = [:]
                self.initialCenter = centerCoord
                self.dataRegion = dataRegion
                self.isCalculating = false

                let region = self.lastRegion ?? dataRegion ?? fallbackRegion
                if let region {
                    self.ensureDensityPrecomputation(for: region)
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

        densityPrecomputationTask = Task.detached(priority: .utility) {
            var generatedGrids: [HeatmapLOD: [GridKey: HeatCell]] = [:]
            for lod in HeatmapLOD.allCases {
                generatedGrids[lod] = HeatmapGridBuilder.computeGrid(for: points, lod: lod)
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
    let count: Int
    let opacity: Double
    let color: Color
    let lod: HeatmapLOD
    let normalizedIntensity: Double
    let cellSpan: Double
}

private enum HeatmapRadiusPreset: String, CaseIterable, Identifiable {
    case compact
    case balanced
    case wide

    var id: String { rawValue }

    var scale: Double {
        switch self {
        case .compact: return 0.88
        case .balanced: return 1.0
        case .wide: return 1.14
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

struct HeatKernelOffset {
    let lat: Int32
    let lon: Int32
    let weight: Double

    static func gaussian(center: Double, edge: Double, corner: Double) -> [HeatKernelOffset] {
        [
            HeatKernelOffset(lat: -1, lon: -1, weight: corner),
            HeatKernelOffset(lat: -1, lon: 0, weight: edge),
            HeatKernelOffset(lat: -1, lon: 1, weight: corner),
            HeatKernelOffset(lat: 0, lon: -1, weight: edge),
            HeatKernelOffset(lat: 0, lon: 0, weight: center),
            HeatKernelOffset(lat: 0, lon: 1, weight: edge),
            HeatKernelOffset(lat: 1, lon: -1, weight: corner),
            HeatKernelOffset(lat: 1, lon: 0, weight: edge),
            HeatKernelOffset(lat: 1, lon: 1, weight: corner),
        ]
    }
}

struct HeatmapViewportKey: Hashable {
    let lod: HeatmapLOD
    let minLatBin: Int32
    let maxLatBin: Int32
    let minLonBin: Int32
    let maxLonBin: Int32

    init(region: MKCoordinateRegion, lod: HeatmapLOD) {
        self.lod = lod

        let latPadding = region.span.latitudeDelta * lod.viewportPaddingFactor
        let lonPadding = region.span.longitudeDelta * lod.viewportPaddingFactor
        let minLat = region.center.latitude - (region.span.latitudeDelta / 2.0) - latPadding
        let maxLat = region.center.latitude + (region.span.latitudeDelta / 2.0) + latPadding
        let minLon = region.center.longitude - (region.span.longitudeDelta / 2.0) - lonPadding
        let maxLon = region.center.longitude + (region.span.longitudeDelta / 2.0) + lonPadding

        let step = lod.step
        let centerLonScale = HeatmapGridBuilder.lonScale(forLatitude: region.center.latitude)
        self.minLatBin = Int32(floor(minLat / step))
        self.maxLatBin = Int32(floor(maxLat / step))
        self.minLonBin = Int32(floor(minLon * centerLonScale / step))
        self.maxLonBin = Int32(floor(maxLon * centerLonScale / step))
    }
}

enum HeatmapGridBuilder {
    nonisolated static func lonScale(forLatitude latitude: Double) -> Double {
        let latRad = latitude * .pi / 180.0
        return max(min(cos(latRad), 1.0), 0.05)
    }

    nonisolated static func computeGrid(for points: [WeightedPoint], lod: HeatmapLOD) -> [GridKey: HeatCell] {
        var grid: [GridKey: Double] = [:]
        let step = lod.step

        for point in points {
            let lonScale = lonScale(forLatitude: point.lat)
            let latBin = Int32(floor(point.lat / step))
            let lonBin = Int32(floor(point.lon * lonScale / step))
            let key = GridKey(lat: latBin, lon: lonBin)
            grid[key, default: 0] += Double(point.weight)
        }

        guard !grid.isEmpty else { return [:] }

        var smoothed: [GridKey: Double] = [:]
        smoothed.reserveCapacity(grid.count * 2)
        for (key, count) in grid {
            for offset in lod.smoothingKernel {
                let neighbor = GridKey(lat: key.lat + offset.lat, lon: key.lon + offset.lon)
                smoothed[neighbor, default: 0] += count * offset.weight
            }
        }

        guard let maxCount = smoothed.values.max(), maxCount > 0 else { return [:] }

        var result: [GridKey: HeatCell] = [:]
        result.reserveCapacity(smoothed.count)

        for (key, count) in smoothed {
            let normalized = count / maxCount
            guard normalized >= lod.minimumNormalizedIntensity * lod.precomputationVisibilityFactor else { continue }

            let cell = makeCell(for: key, count: count, normalized: normalized, lod: lod)
            result[key] = cell
        }

        return result
    }

    nonisolated static func visibleCells(in grid: [GridKey: HeatCell], viewportKey: HeatmapViewportKey) -> [HeatCell] {
        var visible: [HeatCell] = []
        visible.reserveCapacity(min(viewportKey.lod.selectionLimit * 2, 256))

        for lat in viewportKey.minLatBin...viewportKey.maxLatBin {
            for lon in viewportKey.minLonBin...viewportKey.maxLonBin {
                if let cell = grid[GridKey(lat: lat, lon: lon)],
                   cell.normalizedIntensity >= viewportKey.lod.minimumNormalizedIntensity {
                    visible.append(cell)
                }
            }
        }

        if visible.isEmpty {
            return []
        }

        visible.sort {
            if $0.normalizedIntensity == $1.normalizedIntensity {
                return $0.count > $1.count
            }
            return $0.normalizedIntensity > $1.normalizedIntensity
        }

        if visible.count > viewportKey.lod.selectionLimit {
            visible = Array(visible.prefix(viewportKey.lod.selectionLimit))
        }

        visible.sort { $0.normalizedIntensity < $1.normalizedIntensity }
        return visible
    }

    nonisolated private static func makeCell(for key: GridKey, count: Double, normalized: Double, lod: HeatmapLOD) -> HeatCell {
        let step = lod.step
        let centerLat = (Double(key.lat) * step) + (step / 2.0)
        let centerLonScale = lonScale(forLatitude: centerLat)
        let centerLonCorrected = (Double(key.lon) * step) + (step / 2.0)
        let centerLon = centerLonCorrected / centerLonScale
        let cellSpan = step * lod.tileSpanMultiplier
        let displayIntensity = HeatmapVisualStyle.displayIntensity(for: normalized)

        return HeatCell(
            gridKey: key,
            coordinate: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            count: max(Int(count.rounded()), 1),
            opacity: 0.24 + (displayIntensity * 0.72),
            color: HeatmapPalette.color(for: HeatmapVisualStyle.colorPosition(for: normalized, lod: lod)),
            lod: lod,
            normalizedIntensity: normalized,
            cellSpan: cellSpan
        )
    }

    /// Pointy-top regular hexagon centred at (centerLat, centerLon).
    /// `stepLat` is the vertical extent in degrees (top-vertex → bottom-vertex).
    /// `stepLon` is the horizontal extent across the hexagon's widest axis
    /// (between the two side vertices) in degrees.
    nonisolated static func polygonCoordinates(
        centerLat: Double,
        centerLon: Double,
        stepLat: Double,
        stepLon: Double
    ) -> [CLLocationCoordinate2D] {
        let halfHeightLat = stepLat / 2.0
        let quarterHeightLat = stepLat / 4.0
        let halfWidthLon = stepLon / 2.0
        return [
            CLLocationCoordinate2D(latitude: centerLat + halfHeightLat, longitude: centerLon),
            CLLocationCoordinate2D(latitude: centerLat + quarterHeightLat, longitude: centerLon + halfWidthLon),
            CLLocationCoordinate2D(latitude: centerLat - quarterHeightLat, longitude: centerLon + halfWidthLon),
            CLLocationCoordinate2D(latitude: centerLat - halfHeightLat, longitude: centerLon),
            CLLocationCoordinate2D(latitude: centerLat - quarterHeightLat, longitude: centerLon - halfWidthLon),
            CLLocationCoordinate2D(latitude: centerLat + quarterHeightLat, longitude: centerLon - halfWidthLon),
            CLLocationCoordinate2D(latitude: centerLat + halfHeightLat, longitude: centerLon),
        ]
    }

    /// Convenience overload preserving the original (degree-uniform) signature
    /// for tests that don't apply Mercator latitude correction.
    nonisolated static func polygonCoordinates(
        centerLat: Double,
        centerLon: Double,
        step: Double
    ) -> [CLLocationCoordinate2D] {
        polygonCoordinates(
            centerLat: centerLat,
            centerLon: centerLon,
            stepLat: step,
            stepLon: step * 0.8660254037844387
        )
    }
}

enum HeatmapPalette {
    static let gradientStops: [(position: Double, color: HeatmapRGB)] = [
        (0.00, HeatmapRGB(red: 0.16, green: 0.14, blue: 0.72)),
        (0.08, HeatmapRGB(red: 0.09, green: 0.31, blue: 0.90)),
        (0.18, HeatmapRGB(red: 0.02, green: 0.55, blue: 0.98)),
        (0.32, HeatmapRGB(red: 0.00, green: 0.78, blue: 0.96)),
        (0.46, HeatmapRGB(red: 0.00, green: 0.92, blue: 0.82)),
        (0.60, HeatmapRGB(red: 0.50, green: 0.96, blue: 0.34)),
        (0.74, HeatmapRGB(red: 0.98, green: 0.88, blue: 0.16)),
        (0.88, HeatmapRGB(red: 1.00, green: 0.52, blue: 0.10)),
        (1.00, HeatmapRGB(red: 0.96, green: 0.10, blue: 0.16)),
    ]

    nonisolated static func rgb(for normalized: Double) -> HeatmapRGB {
        let clamped = min(max(normalized, 0.0), 1.0)
        guard let first = gradientStops.first else {
            return HeatmapRGB(red: 0.0, green: 0.4, blue: 0.8)
        }

        if clamped <= first.position {
            return first.color
        }

        for index in 1..<gradientStops.count {
            let previous = gradientStops[index - 1]
            let current = gradientStops[index]
            guard clamped <= current.position else { continue }

            let distance = current.position - previous.position
            let fraction = distance > 0 ? (clamped - previous.position) / distance : 0
            return previous.color.interpolated(to: current.color, fraction: fraction)
        }

        return gradientStops.last?.color ?? first.color
    }

    nonisolated static func color(for normalized: Double) -> Color {
        rgb(for: normalized).color
    }
}

struct HeatmapRGB: Equatable {
    let red: Double
    let green: Double
    let blue: Double

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    func interpolated(to other: HeatmapRGB, fraction: Double) -> HeatmapRGB {
        let clamped = min(max(fraction, 0.0), 1.0)
        return HeatmapRGB(
            red: red + ((other.red - red) * clamped),
            green: green + ((other.green - green) * clamped),
            blue: blue + ((other.blue - blue) * clamped)
        )
    }
}

enum HeatmapVisualStyle {
    nonisolated static func displayIntensity(for normalized: Double) -> Double {
        let clamped = min(max(normalized, 0.0), 1.0)
        let liftedLow = pow(clamped, 0.50)
        let colorLift = pow(clamped, 0.72)
        let hotspotBoost = pow(clamped, 1.45)
        let value = (liftedLow * 0.50) + (colorLift * 0.30) + (hotspotBoost * 0.28) + (clamped * 0.10)
        return min(max(value, 0.0), 1.0)
    }

    nonisolated static func colorPosition(for normalized: Double, lod: HeatmapLOD) -> Double {
        let clamped = min(max(normalized, 0.0), 1.0)
        let display = displayIntensity(for: clamped)
        let lowHueLift = pow(clamped, 0.38)
        let midHueLift = pow(clamped, 0.62)
        let warmLift = pow(clamped, 1.2)
        let detailBias: Double
        switch lod {
        case .macro:
            detailBias = 0.0
        case .low:
            detailBias = 0.04
        case .medium:
            detailBias = 0.09
        case .high:
            detailBias = 0.14
        }
        let value = (lowHueLift * 0.42) + (midHueLift * 0.24) + (display * 0.24) + (warmLift * 0.14) + ((1.0 - clamped) * detailBias)
        return min(max(value, 0.0), 1.0)
    }

    nonisolated static func remappedControlOpacity(_ overlayOpacity: Double) -> Double {
        let clamped = min(max(overlayOpacity, 0.1), 1.0)
        return 0.20 + (clamped - 0.1) / 0.9 * 0.80
    }

    nonisolated static func effectiveOpacity(
        cellOpacity: Double,
        normalizedIntensity: Double,
        overlayOpacity: Double,
        lod: HeatmapLOD
    ) -> Double {
        let displayIntensity = displayIntensity(for: normalizedIntensity)
        let controlOpacity = remappedControlOpacity(overlayOpacity)
        let hotspotBoost = pow(displayIntensity, 1.45)
        let emphasis = 0.88 + (displayIntensity * 0.82) + (hotspotBoost * 0.26)
        let detailBoost: Double
        switch lod {
        case .macro:
            detailBoost = 0.98
        case .low:
            detailBoost = 1.06
        case .medium:
            detailBoost = 1.16 + ((1.0 - displayIntensity) * 0.08)
        case .high:
            detailBoost = 1.24 + ((1.0 - displayIntensity) * 0.14)
        }
        let value = cellOpacity * controlOpacity * lod.overlayOpacityMultiplier * emphasis * detailBoost
        let maxOpacity = 0.84 + (controlOpacity * 0.14)
        return min(max(value, 0.08), maxOpacity)
    }
}

#endif
