#if canImport(SwiftUI) && canImport(MapKit)
import SwiftUI
import MapKit
import LocationHistoryConsumer

/// Lightweight controller surfaced to parents of `AppDayMapView` (and
/// other map views, e.g. the Insights hero map) so they can drive the
/// map camera from external floating controls (compass / zoom / fit-to-
/// data). The closures are populated on `onAppear` and cleared on
/// `onDisappear`. Plain ObservableObject — no iOS-17-only API surface,
/// so callers on older deployments can instantiate it freely.
public final class AppDayMapCameraController: ObservableObject {
    public init() {}
    /// Recentres on the fitted region computed from the day's data.
    public var fitToData: (() -> Void)?
    /// Zooms the current map region by `factor` (0.5 = zoom in, 2.0 = zoom out).
    public var adjustZoom: ((Double) -> Void)?
}

@available(iOS 17.0, macOS 14.0, *)
public struct AppDayMapView: View {
    @EnvironmentObject private var preferences: AppPreferences
    let mapData: DayMapData
    /// When `true` the map fills available height (for landscape side-by-side layouts).
    /// When `false` (default) the map uses a fixed 280 pt portrait height.
    var fillHeight: Bool = false
    /// Top padding for the topTrailing map-control overlay. Defaults to 8 (legacy behavior).
    /// Hero-map callers pass a value combining the device safe-area inset and the
    /// shared `LHHeroMapLayout.mapControlTopOffset` so controls clear the chevron.
    var mapControlTopPadding: CGFloat = 8
    /// Hides the built-in topTrailing control stack (used when the parent
    /// provides its own floating controls, e.g. the multi-layer DayDetail).
    var hidesBuiltInControls: Bool = false
    /// Suppresses the rounded-clip + fixed-height treatment so the parent
    /// can place the map as a full-bleed background.
    var fullBleed: Bool = false
    /// Optional camera controller — when supplied, the view publishes its
    /// fit-to-data and zoom actions so the parent's controls can drive the
    /// camera.
    var cameraController: AppDayMapCameraController? = nil
    @State private var renderData: DayMapRenderData
    @State private var mapPosition: MapCameraPosition
    /// Shadow of the last-applied region so `currentRegion()` can read it.
    /// `MapCameraPosition` is an opaque struct (not an enum) — pattern-
    /// matching on it fails with stricter Swift versions / Xcode builds.
    @State private var currentMapRegion: MKCoordinateRegion?

    public init(
        mapData: DayMapData,
        fillHeight: Bool = false,
        mapControlTopPadding: CGFloat = 8,
        hidesBuiltInControls: Bool = false,
        fullBleed: Bool = false,
        cameraController: AppDayMapCameraController? = nil
    ) {
        self.mapData = mapData
        self.fillHeight = fillHeight
        self.mapControlTopPadding = mapControlTopPadding
        self.hidesBuiltInControls = hidesBuiltInControls
        self.fullBleed = fullBleed
        self.cameraController = cameraController
        let initialRender = DayMapRenderData(mapData: mapData)
        self._renderData = State(initialValue: initialRender)
        if let region = initialRender.region {
            self._mapPosition = State(initialValue: .region(region))
        } else {
            self._mapPosition = State(initialValue: .automatic)
        }
    }

    public var body: some View {
        if renderData.hasMapContent, let region = renderData.region {
            mapContent(region: region)
                .frame(height: (fillHeight || fullBleed) ? nil : 280)
                .frame(maxHeight: (fillHeight || fullBleed) ? .infinity : nil)
                .clipShape(RoundedRectangle(cornerRadius: (fillHeight || fullBleed) ? 0 : 12, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if !hidesBuiltInControls {
                        mapControlsStack
                            .padding(.top, mapControlTopPadding)
                            .padding(.trailing, 8)
                            .padding(.leading, 8)
                            .padding(.bottom, 8)
                    }
                }
                .accessibilityLabel(mapAccessibilityLabel)
                .accessibilityIdentifier(AppAccessibilityID.Map.dayDetailRoot)
                .onAppear { wireCameraController() }
                .onDisappear { unwireCameraController() }
                .onChange(of: mapData) { _, newValue in
                    let newRender = DayMapRenderData(mapData: newValue)
                    renderData = newRender
                    if let region = newRender.region {
                        setMapRegion(region)
                    }
                    wireCameraController()
                }
        }
    }

    private func wireCameraController() {
        guard let controller = cameraController else { return }
        controller.fitToData = {
            if let region = renderData.region {
                setMapRegion(region)
            }
        }
        controller.adjustZoom = { factor in
            // Mirrors AppLiveTrackingView.adjustMapZoom — clamp at sensible
            // bounds so users cannot zoom into a 0-span degenerate camera.
            guard let region = currentRegion() else { return }
            let newSpan = MKCoordinateSpan(
                latitudeDelta: max(0.0005, min(180, region.span.latitudeDelta * factor)),
                longitudeDelta: max(0.0005, min(360, region.span.longitudeDelta * factor))
            )
            setMapRegion(MKCoordinateRegion(center: region.center, span: newSpan))
        }
    }

    private func unwireCameraController() {
        cameraController?.fitToData = nil
        cameraController?.adjustZoom = nil
    }

    private func currentRegion() -> MKCoordinateRegion? {
        // MapCameraPosition is an opaque struct in SwiftUI; we cannot
        // pattern-match it. Read from the shadow state we maintain whenever
        // the position is explicitly set, and fall back to the fitted region
        // when the camera is in automatic mode and nothing has been set yet.
        currentMapRegion ?? renderData.region
    }

    private func setMapRegion(_ region: MKCoordinateRegion, animated: Bool = true) {
        currentMapRegion = region
        if animated {
            withAnimation { mapPosition = .region(region) }
        } else {
            mapPosition = .region(region)
        }
    }

    @ViewBuilder
    private var mapControlsStack: some View {
        let fitToData = renderData.region == nil ? nil : {
            if let region = renderData.region {
                setMapRegion(region)
            }
        }
        if #available(iOS 26.0, *) {
            VStack(alignment: .trailing, spacing: 10) {
                LGLayerToggleBar(selected: $preferences.mapTrackColorMode)
                MapLayerMenu(configuration: MapLayerMenu.Configuration(
                    showsTrackColor: false,
                    fitToData: fitToData
                ))
            }
        } else {
            MapLayerMenu(configuration: MapLayerMenu.Configuration(
                showsTrackColor: true,
                fitToData: fitToData
            ))
        }
    }

    private var mapAccessibilityLabel: String {
        let visits = renderData.visitAnnotations.count
        let paths = renderData.pathOverlays.count
        if preferences.appLanguage.isGerman {
            switch (visits, paths) {
            case (0, 0): return "Karte"
            case (_, 0): return "Karte mit \(visits) \(visits == 1 ? "Besuch" : "Besuchen")"
            case (0, _): return "Karte mit \(paths) \(paths == 1 ? "Route" : "Routen")"
            default: return "Karte mit \(visits) \(visits == 1 ? "Besuch" : "Besuchen") und \(paths) \(paths == 1 ? "Route" : "Routen")"
            }
        }
        switch (visits, paths) {
        case (0, 0): return "Map"
        case (_, 0): return "Map with \(visits) \(visits == 1 ? "visit" : "visits")"
        case (0, _): return "Map with \(paths) \(paths == 1 ? "route" : "routes")"
        default: return "Map with \(visits) \(visits == 1 ? "visit" : "visits") and \(paths) \(paths == 1 ? "route" : "routes")"
        }
    }

    @ViewBuilder
    private func mapContent(region: MKCoordinateRegion) -> some View {
        Map(position: $mapPosition) {
            // region parameter retained for legacy callers; mapPosition is the source of truth
            let _ = region
            // Halo underlayer for every path — improves contrast on hybrid maps.
            ForEach(renderData.pathOverlays) { path in
                MapPolyline(coordinates: displayCoords(for: path))
                    .stroke(
                        Color.white.opacity(MapTrackStyle.haloOpacity),
                        style: MapTrackStyle.stroke(width: MapTrackStyle.Width.day * MapTrackStyle.haloMultiplier)
                    )
            }
            // Core stroke — speed-coloured segments OR activity-coloured polyline.
            ForEach(renderData.pathOverlays) { path in
                if preferences.mapTrackColorMode == .speed, !path.speedSegments.isEmpty {
                    ForEach(path.speedSegments) { segment in
                        MapPolyline(coordinates: [segment.start, segment.end])
                            .stroke(
                                SpeedColors.color(for: segment.normalizedSpeed),
                                style: MapTrackStyle.stroke(width: MapTrackStyle.Width.day)
                            )
                    }
                } else {
                    MapPolyline(coordinates: displayCoords(for: path))
                        .stroke(
                            strokeColor(for: path),
                            style: MapTrackStyle.stroke(width: MapTrackStyle.Width.day)
                        )
                }
            }

            ForEach(renderData.visitAnnotations) { visit in
                Marker(
                    t(displayNameForVisitType(visit.semanticType, default: "Visit")),
                    coordinate: visit.coordinate
                )
                .tint(MapPalette.visitColor(for: visit.semanticType))
            }
        }
        .mapStyle(AppMapStyleResolver.mapStyle(for: preferences.preferredMapStyle, showsRealisticElevation: preferences.mapShowsRealisticElevation))
    }

    private func displayCoords(for path: DayMapRenderData.PathOverlay) -> [CLLocationCoordinate2D] {
        // Both branches return precomputed arrays. The simplified coords were
        // built once in `DayMapRenderData.init`, so the per-frame Map body —
        // which calls this for halo + core stroke = 2× per path per render —
        // does not re-run Douglas-Peucker + outlier filtering each frame.
        preferences.dayPathDisplayMode == .mapMatched
            ? path.simplifiedCoordinates
            : path.coordinates
    }

    private func strokeColor(for path: DayMapRenderData.PathOverlay) -> Color {
        switch preferences.mapTrackColorMode {
        case .activity:
            return MapPalette.routeColor(for: path.activityType)
        case .speed:
            return MapPalette.routeColor(for: path.activityType)
        case .elevation:
            return .green
        case .weather:
            return .blue
        }
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }
}

struct DayMapRenderData {
    struct VisitAnnotation: Identifiable {
        let id: Int
        let coordinate: CLLocationCoordinate2D
        let semanticType: String?
    }

    struct PathOverlay: Identifiable {
        let id: Int
        let coordinates: [CLLocationCoordinate2D]
        /// `coordinates` after `PathFilter.removeOutliers` + `PathSimplification.douglasPeucker`.
        /// Computed once at init so per-frame map rendering does not re-run
        /// the simplification pass on every body recomputation.
        let simplifiedCoordinates: [CLLocationCoordinate2D]
        let activityType: String?
        let speedSamples: [TrackSample]
        /// Pre-computed colour-graded segments for the speed layer. Cached
        /// once at init so the per-frame Map body does not re-run percentile
        /// + rolling-mean smoothing on every render pass.
        let speedSegments: [SpeedSegment]
    }

    let visitAnnotations: [VisitAnnotation]
    let pathOverlays: [PathOverlay]
    let region: MKCoordinateRegion?
    let hasMapContent: Bool

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFallback: ISO8601DateFormatter = ISO8601DateFormatter()

    init(mapData: DayMapData) {
        self.visitAnnotations = mapData.visitAnnotations.enumerated().compactMap { offset, visit in
            let coord = CLLocationCoordinate2D(
                latitude: visit.coordinate.lat,
                longitude: visit.coordinate.lon
            )
            // Skip invalid visit coordinates rather than handing NaN/Inf to MapKit.
            guard MapCoordinateGuard.isValid(coord) else { return nil }
            return VisitAnnotation(id: offset, coordinate: coord, semanticType: visit.semanticType)
        }
        self.pathOverlays = mapData.pathOverlays.enumerated().map { offset, overlay in
            // Sanitise once at init so neither the per-frame Map body nor the
            // simplification pipeline has to defend against NaN/Inf/sentinel
            // coordinates downstream. Applies to Day Detail; Live already
            // sanitises in its own pipeline.
            let rawCoords = overlay.coordinates.map {
                CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
            }
            let parsedTimes: [Date?] = overlay.timestamps.map { iso -> Date? in
                guard let iso else { return nil }
                return Self.isoFormatter.date(from: iso) ?? Self.isoFallback.date(from: iso)
            }
            // Filter coords + parallel timestamps together so sample alignment holds.
            var coords: [CLLocationCoordinate2D] = []
            coords.reserveCapacity(rawCoords.count)
            var alignedTimes: [Date?] = []
            alignedTimes.reserveCapacity(rawCoords.count)
            let hasAlignedTimes = parsedTimes.count == rawCoords.count
            for (i, c) in rawCoords.enumerated() {
                guard MapCoordinateGuard.isValid(c) else { continue }
                coords.append(c)
                alignedTimes.append(hasAlignedTimes ? parsedTimes[i] : nil)
            }
            let samples: [TrackSample]
            if hasAlignedTimes, alignedTimes.count == coords.count {
                samples = zip(coords, alignedTimes).map { TrackSample(coordinate: $0.0, timestamp: $0.1) }
            } else {
                samples = []
            }
            let simplified = PathSimplification.douglasPeucker(PathFilter.removeOutliers(coords))
            // Pre-compute speed segments once so the body doesn't re-run
            // smoothing + percentile bounds on every render.
            let speedSegments = samples.isEmpty ? [] : SpeedTrackBuilder.segments(from: samples)
            return PathOverlay(
                id: offset,
                coordinates: coords,
                simplifiedCoordinates: simplified,
                activityType: overlay.activityType,
                speedSamples: samples,
                speedSegments: speedSegments
            )
        }
        self.region = mapData.fittedRegion.map {
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: $0.centerLat,
                    longitude: $0.centerLon
                ),
                span: MKCoordinateSpan(
                    latitudeDelta: $0.spanLat,
                    longitudeDelta: $0.spanLon
                )
            )
        }
        self.hasMapContent = mapData.hasMapContent
    }
}
#endif
