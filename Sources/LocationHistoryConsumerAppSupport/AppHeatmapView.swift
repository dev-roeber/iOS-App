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
    @State private var overlayOpacity = 0.84
    @State private var radiusPreset: HeatmapRadiusPreset = .balanced
    @State private var heatmapMode: HeatmapMode = .route

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
        .animation(.easeInOut(duration: 0.25), value: model.visibleRouteSegments.count)
        .animation(.easeInOut(duration: 0.25), value: model.visibleRoutePaths.count)
        .onAppear {
            if isFirstLoad {
                model.updateMode(heatmapMode)
                model.startPrecomputation()
                isFirstLoad = false
            }
        }
        .onChange(of: model.initialCenter) { _, newCenter in
            if let center = newCenter {
                seedInitialViewport(center: center)
            }
        }
        .onChange(of: heatmapMode) { _, _ in
            model.updateMode(heatmapMode)
        }
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    @ViewBuilder
    private var mapView: some View {
        Map(position: $mapPosition) {
            if heatmapMode == .density {
                ForEach(model.visibleCells) { cell in
                    MapPolygon(coordinates: scaledPolygonCoordinates(for: cell))
                        .foregroundStyle(cell.color.opacity(effectiveOpacity(for: cell)))
                }
            } else {
                // Glow underlayer: wide, semi-transparent bloom
                ForEach(model.visibleRoutePaths) { path in
                    MapPolyline(coordinates: path.coordinates)
                        .stroke(
                            path.color.opacity(routeGlowOpacity(for: path)),
                            lineWidth: path.glowLineWidth
                        )
                }
                // Core layer: bright, narrower line on top
                ForEach(model.visibleRoutePaths) { path in
                    MapPolyline(coordinates: path.coordinates)
                        .stroke(
                            path.color.opacity(routeCoreOpacity(for: path)),
                            lineWidth: path.coreLineWidth
                        )
                }
            }
        }
        .mapStyle(routeMapStyle)
        .ignoresSafeArea(edges: .top)
        .onMapCameraChange(frequency: .onEnd) { context in
            model.updateForRegion(context.region)
        }
        .onMapCameraChange(frequency: .continuous) { context in
            model.debounceUpdateForRegion(context.region)
        }
    }

    /// Dark map style for route mode (satellite imagery gives best contrast for glowing lines).
    /// Standard map for density mode; hybrid if user prefers hybrid.
    private var routeMapStyle: MapStyle {
        if preferences.preferredMapStyle.isHybrid { return .hybrid }
        return heatmapMode == .route ? .imagery() : .standard()
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

            // Mode picker — chip style matching the filter chips in other views.
            VStack(alignment: .leading, spacing: 6) {
                Text(t("Mode"))
                    .font(.caption.weight(.semibold))
                HStack(spacing: 8) {
                    ForEach(HeatmapMode.allCases) { mode in
                        Button {
                            heatmapMode = mode
                        } label: {
                            Text(t(mode.labelKey))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(heatmapMode == mode ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.08))
                                .foregroundStyle(heatmapMode == mode ? Color.accentColor : Color.primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
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

            if heatmapMode == .density {
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
            } else {
                routeLegend
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal)
        .padding(.bottom, 8)
        .controlSize(.small)
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
        } // end ScrollView inner VStack
        .frame(maxHeight: 260) // cap height in landscape; scrollable beyond that
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

    @ViewBuilder
    private var routeLegend: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(t("Rare"))
                Spacer()
                Text(t("Frequent"))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            LinearGradient(
                colors: [
                    RoutePalette.color(for: 0.04).opacity(0.5),
                    RoutePalette.color(for: 0.25).opacity(0.65),
                    RoutePalette.color(for: 0.55).opacity(0.78),
                    RoutePalette.color(for: 0.80).opacity(0.88),
                    RoutePalette.color(for: 1.0).opacity(0.95),
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

    /// Glow (underlayer): wide, low opacity bloom for luminous halo effect.
    private func routeGlowOpacity(for path: RoutePath) -> Double {
        let control = HeatmapVisualStyle.remappedControlOpacity(overlayOpacity)
        let base = 0.20 + path.normalizedIntensity * 0.15
        return min(max(base * control, 0.08), 0.38)
    }

    /// Core (top layer): bright narrow line at higher opacity.
    private func routeCoreOpacity(for path: RoutePath) -> Double {
        let control = HeatmapVisualStyle.remappedControlOpacity(overlayOpacity)
        let base = 0.62 + path.normalizedIntensity * 0.34
        return min(max(base * control, 0.22), 0.96)
    }

    private func scaledPolygonCoordinates(for cell: HeatCell) -> [CLLocationCoordinate2D] {
        HeatmapGridBuilder.polygonCoordinates(
            centerLat: cell.coordinate.latitude,
            centerLon: cell.coordinate.longitude,
            step: cell.cellSpan * radiusPreset.scale
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
        case .macro: return 0.32
        case .low: return 0.08
        case .medium: return 0.012
        case .high: return 0.003
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
        // Increased to 1.25–1.75 so adjacent density cells overlap noticeably,
        // softening the previously visible Minecraft-block edges. Each LOD's
        // overlap stays proportional (more at coarse zoom, less at fine zoom).
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
        case .high: return 460
        }
    }

    var minimumNormalizedIntensity: Double {
        switch self {
        case .macro: return 0.09
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
        if spanDelta > 7.5 { return .macro }
        if spanDelta > 1.0 { return .low }
        if spanDelta > 0.12 { return .medium }
        return .high
    }

    // Route-specific: segment step (degrees) for binning
    var routeSegmentStep: Double {
        switch self {
        case .macro: return 0.08
        case .low: return 0.025
        case .medium: return 0.006
        case .high: return 0.0018
        }
    }

    var routeSelectionLimit: Int {
        // Halved at macro/low so zoomed-out hotspots no longer stack 60 overlapping
        // glow polylines into a single white lens-flare star artefact. Medium/high
        // unchanged because at those zooms tracks are spatially separated.
        switch self {
        case .macro: return 30
        case .low: return 75
        case .medium: return 300
        case .high: return 500
        }
    }
}

// MARK: - Route Palette

enum RoutePalette {
    // Deep indigo/blue → cyan → bright white/warm-yellow
    // Designed for dark-map rendering: luminous, high-contrast, Strava-style
    static let gradientStops: [(position: Double, color: HeatmapRGB)] = [
        (0.00, HeatmapRGB(red: 0.18, green: 0.12, blue: 0.72)),  // deep indigo
        (0.20, HeatmapRGB(red: 0.0,  green: 0.48, blue: 0.95)),  // vivid blue
        (0.42, HeatmapRGB(red: 0.0,  green: 0.85, blue: 0.95)),  // bright cyan
        (0.65, HeatmapRGB(red: 0.72, green: 0.96, blue: 1.00)),  // ice/light cyan
        (0.82, HeatmapRGB(red: 1.00, green: 0.94, blue: 0.70)),  // warm white/yellow
        // Hotspot top-stop capped below pure white. Multiple stacked glow polylines
        // were saturating to (1,1,1) at hotspots and producing a lens-flare star
        // artefact on zoom-out (visible on screenshots 2026-05-06 21:18). A warm
        // bright cap retains the "luminous" look without the white burnout.
        (1.00, HeatmapRGB(red: 0.96, green: 0.92, blue: 0.78)),
    ]

    nonisolated static func rgb(for normalized: Double) -> HeatmapRGB {
        let clamped = min(max(normalized, 0.0), 1.0)
        guard let first = gradientStops.first else {
            return HeatmapRGB(red: 0.0, green: 0.7, blue: 0.85)
        }
        if clamped <= first.position { return first.color }
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

// MARK: - Route Segment

struct RouteSegment: Identifiable {
    let id: Int
    let coordinates: [CLLocationCoordinate2D]
    let normalizedIntensity: Double
    let color: Color
    let lineWidth: Double
}

// MARK: - Route Path (connected polyline for glow rendering)

/// A connected coordinate sequence extracted directly from path/activity data.
/// Each RoutePath carries an intensity derived from the RouteGrid corridor frequency.
struct RoutePath: Identifiable {
    let id: Int
    /// Core coordinates for the route line.
    let coordinates: [CLLocationCoordinate2D]
    /// 0…1 corridor frequency from the route grid.
    let normalizedIntensity: Double
    /// Rendered line width for the core layer (1–8 pt).
    let coreLineWidth: Double
    /// Rendered line width for the glow underlayer (2× core).
    /// Reduced from 3× — the wider halo plus stacked overlapping tracks at
    /// hotspots was the dominant contributor to the lens-flare star artefact.
    var glowLineWidth: Double { coreLineWidth * 2.0 }
    /// Core colour (fully saturated).
    let color: Color
}

struct PreparedRouteTrack {
    struct BoundingBox {
        let minLat: Double
        let maxLat: Double
        let minLon: Double
        let maxLon: Double

        func intersects(
            minLat viewportMinLat: Double,
            maxLat viewportMaxLat: Double,
            minLon viewportMinLon: Double,
            maxLon viewportMaxLon: Double
        ) -> Bool {
            maxLat >= viewportMinLat &&
            minLat <= viewportMaxLat &&
            maxLon >= viewportMinLon &&
            minLon <= viewportMaxLon
        }
    }

    let renderCoordinates: [CLLocationCoordinate2D]
    let sampleMidpoints: [CLLocationCoordinate2D]
    let boundingBox: BoundingBox
}

enum PreparedRouteTrackBuilder {
    private static let maxPolylinePoints = 500

    nonisolated static func build(from export: AppExport) -> [PreparedRouteTrack] {
        var tracks: [PreparedRouteTrack] = []

        func appendTrack(from coordinates: [CLLocationCoordinate2D]) {
            guard let track = makeTrack(from: coordinates) else {
                return
            }
            tracks.append(track)
        }

        for day in export.data.days {
            for path in day.paths {
                if let flats = path.flatCoordinates, flats.count >= 4 {
                    appendTrack(from: flatToCoords(flats))
                } else if path.points.count >= 2 {
                    appendTrack(from: path.points.map {
                        CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
                    })
                }
            }
            for activity in day.activities {
                if let flats = activity.flatCoordinates, flats.count >= 4 {
                    appendTrack(from: flatToCoords(flats))
                }
            }
        }

        return tracks
    }

    nonisolated private static func makeTrack(from coordinates: [CLLocationCoordinate2D]) -> PreparedRouteTrack? {
        guard coordinates.count >= 2 else {
            return nil
        }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coordinate in coordinates.dropFirst() {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        let segmentCount = coordinates.count - 1
        let sampleStep = max(1, segmentCount / 30)
        var sampleMidpoints: [CLLocationCoordinate2D] = []
        sampleMidpoints.reserveCapacity(min(segmentCount, 31))

        var index = 0
        while index < segmentCount {
            let first = coordinates[index]
            let second = coordinates[index + 1]
            sampleMidpoints.append(
                CLLocationCoordinate2D(
                    latitude: (first.latitude + second.latitude) / 2.0,
                    longitude: (first.longitude + second.longitude) / 2.0
                )
            )
            index += sampleStep
        }

        let renderCoordinates: [CLLocationCoordinate2D]
        if coordinates.count > maxPolylinePoints {
            let decimation = max(1, coordinates.count / maxPolylinePoints)
            var sampled: [CLLocationCoordinate2D] = []
            sampled.reserveCapacity(maxPolylinePoints + 2)
            var renderIndex = 0
            while renderIndex < coordinates.count - 1 {
                sampled.append(coordinates[renderIndex])
                renderIndex += decimation
            }
            sampled.append(coordinates[coordinates.count - 1])
            renderCoordinates = sampled
        } else {
            renderCoordinates = coordinates
        }

        return PreparedRouteTrack(
            renderCoordinates: renderCoordinates,
            sampleMidpoints: sampleMidpoints,
            boundingBox: PreparedRouteTrack.BoundingBox(
                minLat: minLat,
                maxLat: maxLat,
                minLon: minLon,
                maxLon: maxLon
            )
        )
    }

    nonisolated private static func flatToCoords(_ flats: [Double]) -> [CLLocationCoordinate2D] {
        var coords: [CLLocationCoordinate2D] = []
        coords.reserveCapacity(flats.count / 2)
        var index = 0
        while index + 1 < flats.count {
            coords.append(CLLocationCoordinate2D(latitude: flats[index], longitude: flats[index + 1]))
            index += 2
        }
        return coords
    }
}

// MARK: - Route Path Extractor

/// Reconstructs connected polyline sequences from AppExport path/activity data.
/// Each GPS track is processed as a whole (no chunking) and scored by sampling
/// multiple grid bins along the track. Frequent routes appear brighter and wider.
enum RoutePathExtractor {
    /// Extract RoutePaths from prepared tracks using the provided intensity grid for scoring.
    nonisolated static func extract(
        from tracks: [PreparedRouteTrack],
        grid: [RouteGridBuilder.SegBin: Int],
        step: Double,
        lod: HeatmapLOD,
        viewportKey: RouteViewportKey
    ) -> [RoutePath] {
        guard let maxCount = grid.values.max(), maxCount > 0 else { return [] }

        let minLat = Double(viewportKey.minLatBin) * step
        let maxLat = Double(viewportKey.maxLatBin + 1) * step
        let minLon = Double(viewportKey.minLonBin) * step
        let maxLon = Double(viewportKey.maxLonBin + 1) * step

        var result: [RoutePath] = []
        var pathID = 0

        func processTrack(_ track: PreparedRouteTrack) {
            guard track.boundingBox.intersects(
                minLat: minLat,
                maxLat: maxLat,
                minLon: minLon,
                maxLon: maxLon
            ) else { return }

            // Score the whole track by sampling precomputed midpoints along its length.
            // Blend max and average to reward frequently-used corridors robustly.
            var maxBinCount = 0
            var totalBinCount = 0
            for sample in track.sampleMidpoints {
                let bin = RouteGridBuilder.SegBin(
                    lat: Int32(floor(sample.latitude / step)),
                    lon: Int32(floor(sample.longitude / step))
                )
                let count = grid[bin] ?? 0
                if count > maxBinCount { maxBinCount = count }
                totalBinCount += count
            }
            let samplesTaken = track.sampleMidpoints.count
            let avgCount = samplesTaken > 0 ? Double(totalBinCount) / Double(samplesTaken) : 0
            let blended = Double(maxBinCount) * 0.6 + avgCount * 0.4
            let normalized = min(blended / Double(maxCount), 1.0)
            guard normalized >= 0.02 else { return }

            let displayI = pow(normalized, 0.50)
            let lineWidth = 1.5 + displayI * 6.5
            result.append(RoutePath(
                id: pathID,
                coordinates: track.renderCoordinates,
                normalizedIntensity: normalized,
                coreLineWidth: lineWidth,
                color: RoutePalette.color(for: displayI)
            ))
            pathID += 1
        }

        for track in tracks {
            processTrack(track)
        }

        // Keep the most-frequent tracks; render low-to-high so frequent routes draw on top
        result.sort { $0.normalizedIntensity > $1.normalizedIntensity }
        if result.count > lod.routeSelectionLimit {
            result = Array(result.prefix(lod.routeSelectionLimit))
        }
        result.sort { $0.normalizedIntensity < $1.normalizedIntensity }

        return result
    }
}

// MARK: - Route Grid Builder

// MARK: - RouteGridBuilder (MapKit-dependent extension)
// The core enum with SegBin + computeGrid lives in AppRouteGridBuilder.swift (no SwiftUI/MapKit needed).

extension RouteGridBuilder {
    nonisolated static func visibleSegments(
        in grid: [SegBin: Int],
        viewportKey: RouteViewportKey,
        step: Double,
        lod: HeatmapLOD
    ) -> [RouteSegment] {
        guard let maxCount = grid.values.max(), maxCount > 0 else { return [] }

        var segments: [RouteSegment] = []
        segments.reserveCapacity(min(lod.routeSelectionLimit, 512))

        for lat in viewportKey.minLatBin...viewportKey.maxLatBin {
            for lon in viewportKey.minLonBin...viewportKey.maxLonBin {
                let bin = SegBin(lat: lat, lon: lon)
                guard let count = grid[bin] else { continue }
                let normalized = Double(count) / Double(maxCount)
                guard normalized >= 0.012 else { continue }

                let centerLat = (Double(lat) * step) + (step / 2.0)
                let centerLon = (Double(lon) * step) + (step / 2.0)
                let half = step * 0.42

                let coords: [CLLocationCoordinate2D] = [
                    CLLocationCoordinate2D(latitude: centerLat - half, longitude: centerLon - half),
                    CLLocationCoordinate2D(latitude: centerLat + half, longitude: centerLon + half),
                ]

                let displayI = pow(normalized, 0.55)
                let lineWidth = 1.5 + displayI * 5.5

                segments.append(RouteSegment(
                    id: Int(lat) &* 100_003 &+ Int(lon),
                    coordinates: coords,
                    normalizedIntensity: normalized,
                    color: RoutePalette.color(for: displayI),
                    lineWidth: lineWidth
                ))
            }
        }

        segments.sort { $0.normalizedIntensity < $1.normalizedIntensity }

        if segments.count > lod.routeSelectionLimit {
            // Keep the most intense segments
            segments.sort { $0.normalizedIntensity > $1.normalizedIntensity }
            segments = Array(segments.prefix(lod.routeSelectionLimit))
            segments.sort { $0.normalizedIntensity < $1.normalizedIntensity }
        }

        return segments
    }
}

struct RouteViewportKey: Hashable {
    let lod: HeatmapLOD
    let minLatBin: Int32
    let maxLatBin: Int32
    let minLonBin: Int32
    let maxLonBin: Int32

    init(region: MKCoordinateRegion, lod: HeatmapLOD) {
        self.lod = lod
        let step = lod.routeSegmentStep
        let pad = 0.12
        let minLat = region.center.latitude  - (region.span.latitudeDelta  / 2.0) * (1 + pad)
        let maxLat = region.center.latitude  + (region.span.latitudeDelta  / 2.0) * (1 + pad)
        let minLon = region.center.longitude - (region.span.longitudeDelta / 2.0) * (1 + pad)
        let maxLon = region.center.longitude + (region.span.longitudeDelta / 2.0) * (1 + pad)
        self.minLatBin = Int32(floor(minLat / step))
        self.maxLatBin = Int32(floor(maxLat / step))
        self.minLonBin = Int32(floor(minLon / step))
        self.maxLonBin = Int32(floor(maxLon / step))
    }
}

// MARK: - ViewModel

@available(iOS 17.0, macOS 14.0, *)
@Observable @MainActor
final class AppHeatmapModel {
    var visibleCells: [HeatCell] = []
    var visibleRouteSegments: [RouteSegment] = []
    var visibleRoutePaths: [RoutePath] = []
    var isCalculating = false
    var initialCenter: CLLocationCoordinate2D?
    var dataRegion: MKCoordinateRegion?
    var hasData: Bool { dataRegion != nil }
    private(set) var lastRegion: MKCoordinateRegion?

    private let export: AppExport
    private var activeMode: HeatmapMode = .route
    private var densityPoints: [WeightedPoint] = []
    private var preparedRouteTracks: [PreparedRouteTrack] = []
    private var lodGrids: [HeatmapLOD: [GridKey: HeatCell]] = [:]
    private var routeGrids: [HeatmapLOD: [RouteGridBuilder.SegBin: Int]] = [:]
    private var viewportCache: [HeatmapViewportKey: [HeatCell]] = [:]
    private var routeViewportCache: [RouteViewportKey: [RouteSegment]] = [:]
    private var routePathCache: [RouteViewportKey: [RoutePath]] = [:]

    private var updateTask: Task<Void, Never>?
    private var densityPrecomputationTask: Task<Void, Never>?

    init(export: AppExport) {
        self.export = export
    }

    func startPrecomputation() {
        guard routeGrids.isEmpty, !isCalculating else { return }
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

            let preparedRouteTracks = PreparedRouteTrackBuilder.build(from: snapshot)
            var generatedRouteGrids: [HeatmapLOD: [RouteGridBuilder.SegBin: Int]] = [:]
            for lod in HeatmapLOD.allCases {
                generatedRouteGrids[lod] = RouteGridBuilder.computeGrid(
                    for: snapshot,
                    step: lod.routeSegmentStep
                )
            }

            let dataRegion = Self.regionThatFits(points: points)
            let completedRouteGrids = generatedRouteGrids
            let completedPoints = points
            let completedRouteTracks = preparedRouteTracks
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
                self.preparedRouteTracks = completedRouteTracks
                self.lodGrids = [:]
                self.routeGrids = completedRouteGrids
                self.viewportCache = [:]
                self.routeViewportCache = [:]
                self.routePathCache = [:]
                self.initialCenter = centerCoord
                self.dataRegion = dataRegion
                self.isCalculating = false

                let region = self.lastRegion ?? dataRegion ?? fallbackRegion

                if let region {
                    if self.activeMode == .density {
                        self.ensureDensityPrecomputation(for: region)
                    } else {
                        self.performCulling(region: region)
                    }
                }
            }
        }
    }

    func updateMode(_ mode: HeatmapMode) {
        guard activeMode != mode else { return }
        activeMode = mode

        guard let region = lastRegion ?? dataRegion else { return }
        switch mode {
        case .route:
            performCulling(region: region)
        case .density:
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
        guard !routeGrids.isEmpty || !lodGrids.isEmpty else { return }
        let lod = HeatmapLOD.optimalLOD(for: region.span.latitudeDelta)

        switch activeMode {
        case .density:
            visibleRouteSegments = []
            visibleRoutePaths = []

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
        case .route:
            visibleCells = []

            guard let routeGrid = routeGrids[lod] else {
                visibleRouteSegments = []
                visibleRoutePaths = []
                return
            }

            let routeKey = RouteViewportKey(region: region, lod: lod)

            if let cached = routeViewportCache[routeKey] {
                visibleRouteSegments = cached
            } else {
                let segs = RouteGridBuilder.visibleSegments(
                    in: routeGrid,
                    viewportKey: routeKey,
                    step: lod.routeSegmentStep,
                    lod: lod
                )
                routeViewportCache[routeKey] = segs
                visibleRouteSegments = segs
            }

            if let cachedPaths = routePathCache[routeKey] {
                visibleRoutePaths = cachedPaths
            } else {
                let paths = RoutePathExtractor.extract(
                    from: preparedRouteTracks,
                    grid: routeGrid,
                    step: lod.routeSegmentStep,
                    lod: lod,
                    viewportKey: routeKey
                )
                routePathCache[routeKey] = paths
                visibleRoutePaths = paths
            }
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

                if self.activeMode == .density {
                    self.performCulling(region: self.lastRegion ?? region)
                }
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
        self.minLatBin = Int32(floor(minLat / step))
        self.maxLatBin = Int32(floor(maxLat / step))
        self.minLonBin = Int32(floor(minLon / step))
        self.maxLonBin = Int32(floor(maxLon / step))
    }
}

enum HeatmapGridBuilder {
    nonisolated static func computeGrid(for points: [WeightedPoint], lod: HeatmapLOD) -> [GridKey: HeatCell] {
        var grid: [GridKey: Double] = [:]
        let step = lod.step

        for point in points {
            let latBin = Int32(floor(point.lat / step))
            let lonBin = Int32(floor(point.lon / step))
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
        let centerLon = (Double(key.lon) * step) + (step / 2.0)
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
    /// `step` is the vertical extent (top-vertex → bottom-vertex);
    /// horizontal extent equals `step * sqrt(3)/2 ≈ 0.866 * step`.
    ///
    /// Hex shape replaces the previous square polygon to soften the
    /// "Minecraft" tile look visible on the 2026-05-06 21:18 screenshots
    /// and aligns the renderer with established density-map conventions
    /// (Strava / Mapbox / Foursquare). The aggregation pipeline still
    /// bins by lat/lon grid for now — true axial-coord hex aggregation
    /// is a follow-up (Tier 2 PR-A part 2).
    nonisolated static func polygonCoordinates(centerLat: Double, centerLon: Double, step: Double) -> [CLLocationCoordinate2D] {
        // Normal pointy-top hexagon: 6 vertices + closing copy of the first.
        // Vertex angles measured from north (0°) clockwise:
        //   0°, 60°, 120°, 180°, 240°, 300°
        // For a pointy-top hex this places vertex 0 directly above the centre.
        let halfHeight = step / 2.0                     // 1/2 of vertical diameter
        let halfWidth = step * 0.4330127018922193       // 1/2 of horizontal extent (= cos 30° * halfHeight*2)
        let quarterHeight = step / 4.0                  // 1/4 of vertical diameter
        return [
            // top
            CLLocationCoordinate2D(latitude: centerLat + halfHeight, longitude: centerLon),
            // upper-right
            CLLocationCoordinate2D(latitude: centerLat + quarterHeight, longitude: centerLon + halfWidth),
            // lower-right
            CLLocationCoordinate2D(latitude: centerLat - quarterHeight, longitude: centerLon + halfWidth),
            // bottom
            CLLocationCoordinate2D(latitude: centerLat - halfHeight, longitude: centerLon),
            // lower-left
            CLLocationCoordinate2D(latitude: centerLat - quarterHeight, longitude: centerLon - halfWidth),
            // upper-left
            CLLocationCoordinate2D(latitude: centerLat + quarterHeight, longitude: centerLon - halfWidth),
            // close
            CLLocationCoordinate2D(latitude: centerLat + halfHeight, longitude: centerLon),
        ]
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
        // Detail view should feel alive even with sparse tracks, so low and mid
        // intensities are lifted earlier while hotspots still separate cleanly.
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
        // Linear: 15% slider → ~0.24 effective, 100% slider → 1.0 effective
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
