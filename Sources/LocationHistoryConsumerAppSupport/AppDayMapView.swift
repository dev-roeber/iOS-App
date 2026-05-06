#if canImport(SwiftUI) && canImport(MapKit)
import SwiftUI
import MapKit
import LocationHistoryConsumer

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
    @State private var renderData: DayMapRenderData
    @State private var mapPosition: MapCameraPosition

    public init(
        mapData: DayMapData,
        fillHeight: Bool = false,
        mapControlTopPadding: CGFloat = 8
    ) {
        self.mapData = mapData
        self.fillHeight = fillHeight
        self.mapControlTopPadding = mapControlTopPadding
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
                .frame(height: fillHeight ? nil : 280)
                .frame(maxHeight: fillHeight ? .infinity : nil)
                .clipShape(RoundedRectangle(cornerRadius: fillHeight ? 0 : 12, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    mapControlsStack
                        .padding(.top, mapControlTopPadding)
                        .padding(.trailing, 8)
                        .padding(.leading, 8)
                        .padding(.bottom, 8)
                }
                .accessibilityLabel(mapAccessibilityLabel)
                .onChange(of: mapData) { _, newValue in
                    let newRender = DayMapRenderData(mapData: newValue)
                    renderData = newRender
                    if let region = newRender.region {
                        withAnimation { mapPosition = .region(region) }
                    }
                }
        }
    }

    @ViewBuilder
    private var mapControlsStack: some View {
        MapLayerMenu(configuration: MapLayerMenu.Configuration(
            showsTrackColor: true,
            fitToData: renderData.region == nil ? nil : {
                if let region = renderData.region {
                    withAnimation { mapPosition = .region(region) }
                }
            }
        ))
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
        let useSpeed = preferences.mapTrackColorMode == .speed
        Map(position: $mapPosition) {
            // region parameter retained for legacy callers; mapPosition is the source of truth
            let _ = region
            // Halo underlayer for every path — improves contrast on hybrid maps.
            ForEach(Array(renderData.pathOverlays.enumerated()), id: \.offset) { _, path in
                MapPolyline(coordinates: displayCoords(for: path))
                    .stroke(
                        Color.white.opacity(MapTrackStyle.haloOpacity),
                        style: MapTrackStyle.stroke(width: MapTrackStyle.Width.day * MapTrackStyle.haloMultiplier)
                    )
            }
            // Core stroke — speed-coloured segments OR activity-coloured polyline.
            ForEach(Array(renderData.pathOverlays.enumerated()), id: \.offset) { _, path in
                if useSpeed, !path.speedSamples.isEmpty {
                    ForEach(SpeedTrackBuilder.segments(from: path.speedSamples)) { segment in
                        MapPolyline(coordinates: [segment.start, segment.end])
                            .stroke(
                                SpeedColors.color(for: segment.normalizedSpeed),
                                style: MapTrackStyle.stroke(width: MapTrackStyle.Width.day)
                            )
                    }
                } else {
                    MapPolyline(coordinates: displayCoords(for: path))
                        .stroke(
                            MapPalette.routeColor(for: path.activityType),
                            style: MapTrackStyle.stroke(width: MapTrackStyle.Width.day)
                        )
                }
            }

            ForEach(Array(renderData.visitAnnotations.enumerated()), id: \.offset) { _, visit in
                Marker(
                    t(displayNameForVisitType(visit.semanticType, default: "Visit")),
                    coordinate: visit.coordinate
                )
                .tint(MapPalette.visitColor(for: visit.semanticType))
            }
        }
        .mapStyle(preferences.preferredMapStyle.isHybrid ? .hybrid : .standard)
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

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }
}

private struct DayMapRenderData {
    struct VisitAnnotation {
        let coordinate: CLLocationCoordinate2D
        let semanticType: String?
    }

    struct PathOverlay {
        let coordinates: [CLLocationCoordinate2D]
        /// `coordinates` after `PathFilter.removeOutliers` + `PathSimplification.douglasPeucker`.
        /// Computed once at init so per-frame map rendering does not re-run
        /// the simplification pass on every body recomputation.
        let simplifiedCoordinates: [CLLocationCoordinate2D]
        let activityType: String?
        let speedSamples: [TrackSample]
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
        self.visitAnnotations = mapData.visitAnnotations.map {
            VisitAnnotation(
                coordinate: CLLocationCoordinate2D(
                    latitude: $0.coordinate.lat,
                    longitude: $0.coordinate.lon
                ),
                semanticType: $0.semanticType
            )
        }
        self.pathOverlays = mapData.pathOverlays.map { overlay in
            let coords = overlay.coordinates.map {
                CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
            }
            let parsedTimes: [Date?] = overlay.timestamps.map { iso -> Date? in
                guard let iso else { return nil }
                return Self.isoFormatter.date(from: iso) ?? Self.isoFallback.date(from: iso)
            }
            let samples: [TrackSample]
            if parsedTimes.count == coords.count {
                samples = zip(coords, parsedTimes).map { TrackSample(coordinate: $0.0, timestamp: $0.1) }
            } else {
                samples = []
            }
            let simplified = PathSimplification.douglasPeucker(PathFilter.removeOutliers(coords))
            return PathOverlay(
                coordinates: coords,
                simplifiedCoordinates: simplified,
                activityType: overlay.activityType,
                speedSamples: samples
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
