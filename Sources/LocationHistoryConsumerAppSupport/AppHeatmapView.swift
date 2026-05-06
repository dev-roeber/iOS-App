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
    // P0 follow-up 2026-05-06 #2: 0.84 was too high (everything saturated),
    // 0.60 was too low (user slid to 100% throughout the verification
    // recording). Settled at 0.75 — a clear primary surface without
    // burying basemap detail.
    @State private var overlayOpacity = 0.75
    @State private var radiusPreset: HeatmapRadiusPreset = .balanced
    // P0 video-audit fix 2026-05-06: density is now default mode. The
    // routes mode produced an over-saturated white-yellow burst on city
    // zoom in the recording; density is the more legible default.
    @State private var heatmapMode: HeatmapMode = .density

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
        // P0 video-audit fix 2026-05-06: soft cross-fade between modes so
        // the previously hard "old overlay disappears, blank pause, new
        // overlay snaps in" recompute transition reads as a smooth swap.
        .animation(.easeInOut(duration: 0.40), value: heatmapMode)
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
    /// P0 video-audit fix 2026-05-06: max alpha lowered 0.38 → 0.24 so
    /// stacked glow halos at hotspots stop summing into a saturated burst.
    private func routeGlowOpacity(for path: RoutePath) -> Double {
        let control = HeatmapVisualStyle.remappedControlOpacity(overlayOpacity)
        let base = 0.14 + path.normalizedIntensity * 0.10
        return min(max(base * control, 0.05), 0.24)
    }

    /// Core (top layer): bright narrow line at higher opacity.
    /// P0 video-audit fix 2026-05-06: cap lowered 0.96 → 0.70 and base
    /// reduced so the brightest visible track at hotspots no longer
    /// fully blocks the basemap underneath.
    private func routeCoreOpacity(for path: RoutePath) -> Double {
        let control = HeatmapVisualStyle.remappedControlOpacity(overlayOpacity)
        let base = 0.42 + path.normalizedIntensity * 0.24
        return min(max(base * control, 0.16), 0.70)
    }

    private func scaledPolygonCoordinates(for cell: HeatCell) -> [CLLocationCoordinate2D] {
        let stepLat = cell.cellSpan * radiusPreset.scale
        // Web-Mercator longitude scale: a degree of longitude shrinks with cos(lat).
        // To keep the hexagon visually round at any latitude (Oldenburg 53° N
        // → cos ≈ 0.60, polar regions much smaller), the longitudinal extent
        // must compensate for that. Clamp the divisor at 0.05 so polar bins
        // don't blow up to absurd widths.
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
        // High-LOD step (~110 m at 53° N): so each hex hits roughly one
        // city block at the deepest zoom; was 333 m before P0 #1.
        // Macro-LOD step grown 1.0° → 2.5° in P0 follow-up #3 because
        // verification 14:07 showed even 1.0° (~110 km) cells were
        // sub-pixel on a 1290 px world map. 2.5° (~280 km) is reliably
        // multi-pixel visible at world zoom while still aggregating a
        // typical 50–500 k point import into a few dozen macro cells.
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
        // High-LOD raised to 1200 because the step shrunk 3× in PR-A.4 —
        // the same area now contains roughly 9× as many bins, so the
        // selection cap must keep up to avoid a sparse rendering on
        // city/street zoom.
        switch self {
        case .macro: return 36
        case .low: return 72
        case .medium: return 280
        case .high: return 1200
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
        // Sweet-spot found across three verification iterations:
        // - Tier 1 dropped macro 60 → 30 (lens-flare star).
        // - P0 #2 dropped to 15/40/150/250 (creamy burst at city zoom).
        // - P0 #3 raises medium 150 → 250 because verification 14:07 showed
        //   the medium-zoom routes mode rendering empty over Europe — the
        //   prior cap was too aggressive for that band. Macro/low stay
        //   tight (15/40) because that's where the burst-prone overlap
        //   happens. High raises 250 → 350 to keep enough detail at the
        //   deepest zoom where tracks are spatially separated anyway.
        switch self {
        case .macro: return 15
        case .low: return 40
        case .medium: return 250
        case .high: return 350
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
        (0.78, HeatmapRGB(red: 0.98, green: 0.85, blue: 0.42)),  // golden yellow
        // Hotspot top-stop pulled further back from cream toward saturated
        // amber. Verification 2026-05-06 #2 showed the previous (0.96,
        // 0.92, 0.78) cream still summing to a perceived white burst when
        // multiple overlapping tracks pile up. Amber summed-with-amber
        // remains amber instead of going white-cream.
        (1.00, HeatmapRGB(red: 0.92, green: 0.62, blue: 0.18)),
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
    /// Maximum step between two consecutive coordinates in a single track,
    /// in degrees — about 100 km. A jump larger than this is treated as a
    /// GPS spike / teleport and splits the track at that point so the
    /// resulting MapPolyline doesn't draw a phantom line straight across
    /// the Atlantic. Verification 14:07 frame F03 surfaced exactly such
    /// a phantom line in routes mode.
    private static let phantomJumpThresholdDegrees = 1.0

    nonisolated static func build(from export: AppExport) -> [PreparedRouteTrack] {
        var tracks: [PreparedRouteTrack] = []

        func appendSegments(from coordinates: [CLLocationCoordinate2D]) {
            for segment in splitOnPhantomJumps(coordinates) {
                if let track = makeTrack(from: segment) {
                    tracks.append(track)
                }
            }
        }

        for day in export.data.days {
            for path in day.paths {
                if let flats = path.flatCoordinates, flats.count >= 4 {
                    appendSegments(from: flatToCoords(flats))
                } else if path.points.count >= 2 {
                    appendSegments(from: path.points.map {
                        CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
                    })
                }
            }
            for activity in day.activities {
                if let flats = activity.flatCoordinates, flats.count >= 4 {
                    appendSegments(from: flatToCoords(flats))
                }
            }
        }

        return tracks
    }

    /// Splits the coordinate sequence wherever two consecutive points are
    /// further apart than `phantomJumpThresholdDegrees`. Each resulting
    /// segment with ≥ 2 points becomes its own track; very short tail
    /// fragments are dropped automatically by `makeTrack`'s minimum check.
    nonisolated private static func splitOnPhantomJumps(
        _ coordinates: [CLLocationCoordinate2D]
    ) -> [[CLLocationCoordinate2D]] {
        guard coordinates.count >= 2 else { return [coordinates] }
        let threshold = phantomJumpThresholdDegrees
        var segments: [[CLLocationCoordinate2D]] = []
        var current: [CLLocationCoordinate2D] = [coordinates[0]]
        for i in 1..<coordinates.count {
            let prev = coordinates[i - 1]
            let now = coordinates[i]
            let dLat = abs(now.latitude - prev.latitude)
            let dLon = abs(now.longitude - prev.longitude)
            if dLat > threshold || dLon > threshold {
                if current.count >= 2 { segments.append(current) }
                current = [now]
            } else {
                current.append(now)
            }
        }
        if current.count >= 2 { segments.append(current) }
        return segments
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
        // Tier 2 PR-A.3: longitude bins are computed in cos(lat)-corrected
        // coordinates so that a single bin covers approximately the same
        // metric distance regardless of latitude. The viewport's lon-bin
        // range therefore needs the same correction.
        let centerLonScale = HeatmapGridBuilder.lonScale(forLatitude: region.center.latitude)
        self.minLatBin = Int32(floor(minLat / step))
        self.maxLatBin = Int32(floor(maxLat / step))
        self.minLonBin = Int32(floor(minLon * centerLonScale / step))
        self.maxLonBin = Int32(floor(maxLon * centerLonScale / step))
    }
}

enum HeatmapGridBuilder {
    /// Cosine-of-latitude longitude scale, clamped 0.05–1.0 so polar bins
    /// stay sane (cos(±90°) = 0 would otherwise blow lon bins to infinity).
    /// Tier 2 PR-A.3: callers multiply lon by this factor before bucketing
    /// so each bin covers approximately the same metric width as the lat
    /// step, eliminating the previous Web-Mercator latitude distortion in
    /// the aggregation grid (not just the rendering).
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
        // Tier 2 PR-A.3: lon-bin keys live in cos(lat)-corrected coordinates;
        // back out to true longitude by dividing the corrected centre value
        // by the lon scale at the cell's centre latitude. lonScale is clamped
        // ≥ 0.05 so polar cells don't produce extreme back-projections.
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
    ///
    /// Callers must supply a `stepLon` that is cosine-corrected for the
    /// current centre latitude (`stepLat / cos(latRad)`) so the rendered
    /// hexagon appears geometrically regular on screen — Web Mercator
    /// shrinks longitude with latitude, so equal degree extents would
    /// render as a horizontally-flattened hexagon at higher latitudes.
    /// At the Oldenburg latitude (~53° N) the correction is ~1.66×,
    /// near the poles much larger; callers must clamp the divisor.
    ///
    /// Hex shape replaced the previous square polygon to soften the
    /// "Minecraft" tile look visible on the 2026-05-06 21:18 screenshots
    /// and aligns the renderer with established density-map conventions
    /// (Strava / Mapbox / Foursquare). The aggregation pipeline still
    /// bins by lat/lon grid; true axial-coord hex aggregation is the
    /// next sub-step (Tier 2 PR-A.3).
    nonisolated static func polygonCoordinates(
        centerLat: Double,
        centerLon: Double,
        stepLat: Double,
        stepLon: Double
    ) -> [CLLocationCoordinate2D] {
        // Pointy-top hexagon: 6 vertices + closing copy of the first.
        let halfHeightLat = stepLat / 2.0               // top↔bottom vertices
        let quarterHeightLat = stepLat / 4.0            // side vertex Y offset
        // Horizontal half-axis = (sqrt(3)/2) × radius. With stepLon being the
        // full horizontal extent, the side vertex sits at stepLon/2 from centre.
        let halfWidthLon = stepLon / 2.0
        return [
            // top
            CLLocationCoordinate2D(latitude: centerLat + halfHeightLat, longitude: centerLon),
            // upper-right
            CLLocationCoordinate2D(latitude: centerLat + quarterHeightLat, longitude: centerLon + halfWidthLon),
            // lower-right
            CLLocationCoordinate2D(latitude: centerLat - quarterHeightLat, longitude: centerLon + halfWidthLon),
            // bottom
            CLLocationCoordinate2D(latitude: centerLat - halfHeightLat, longitude: centerLon),
            // lower-left
            CLLocationCoordinate2D(latitude: centerLat - quarterHeightLat, longitude: centerLon - halfWidthLon),
            // upper-left
            CLLocationCoordinate2D(latitude: centerLat + quarterHeightLat, longitude: centerLon - halfWidthLon),
            // close
            CLLocationCoordinate2D(latitude: centerLat + halfHeightLat, longitude: centerLon),
        ]
    }

    /// Convenience overload preserving the original (degree-uniform) signature
    /// for tests and callers that don't yet apply Mercator latitude correction.
    /// Internally treats `step` as both stepLat and stepLon — the rendered
    /// hexagon will appear horizontally compressed at non-equatorial latitudes.
    /// Prefer the (stepLat, stepLon) variant in production code.
    nonisolated static func polygonCoordinates(
        centerLat: Double,
        centerLon: Double,
        step: Double
    ) -> [CLLocationCoordinate2D] {
        // Equatorial hex: stepLon equals stepLat * cos 30° = stepLat * 0.866 to
        // keep the legacy pointy-top regular hex when no latitude correction
        // is supplied. Tests verify exactly this geometry.
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
