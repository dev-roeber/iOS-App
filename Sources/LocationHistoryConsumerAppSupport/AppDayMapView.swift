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
    /// When `false` the built-in style-toggle button is hidden so the caller can
    /// place it inline in its own control row.
    var showStyleToggle: Bool = true
    /// Top padding for the topTrailing map-control overlay. Defaults to 8 (legacy behavior).
    /// Hero-map callers pass a value combining the device safe-area inset and the
    /// shared `LHHeroMapLayout.mapControlTopOffset` so controls clear the chevron.
    var mapControlTopPadding: CGFloat = 8
    /// When `true` the topTrailing controls are stacked vertically (VStack), preparing for
    /// additional buttons in the future. Default `false` keeps the legacy horizontal layout.
    var verticalMapControls: Bool = false
    @State private var renderData: DayMapRenderData

    public init(
        mapData: DayMapData,
        fillHeight: Bool = false,
        showStyleToggle: Bool = true,
        mapControlTopPadding: CGFloat = 8,
        verticalMapControls: Bool = false
    ) {
        self.mapData = mapData
        self.fillHeight = fillHeight
        self.showStyleToggle = showStyleToggle
        self.mapControlTopPadding = mapControlTopPadding
        self.verticalMapControls = verticalMapControls
        self._renderData = State(initialValue: DayMapRenderData(mapData: mapData))
    }

    public var body: some View {
        if renderData.hasMapContent, let region = renderData.region {
            mapContent(region: region)
                .frame(height: fillHeight ? nil : 280)
                .frame(maxHeight: fillHeight ? .infinity : nil)
                .clipShape(RoundedRectangle(cornerRadius: fillHeight ? 0 : 12, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if showStyleToggle {
                        mapControlsStack
                            .padding(.top, mapControlTopPadding)
                            .padding(.trailing, 8)
                            .padding(.leading, 8)
                            .padding(.bottom, 8)
                    }
                }
                .accessibilityLabel(mapAccessibilityLabel)
                .onChange(of: mapData) { _, newValue in
                    renderData = DayMapRenderData(mapData: newValue)
                }
        }
    }

    @ViewBuilder
    private var mapControlsStack: some View {
        MapLayerMenu(configuration: MapLayerMenu.Configuration(
            showsTrackColor: true
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
        Map(initialPosition: .region(MKCoordinateRegion(
            center: region.center,
            span: region.span
        ))) {
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
        preferences.dayPathDisplayMode == .mapMatched
            ? PathSimplification.douglasPeucker(PathFilter.removeOutliers(path.coordinates))
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
        let activityType: String?
        let speedSamples: [TrackSample]
    }

    let visitAnnotations: [VisitAnnotation]
    let pathOverlays: [PathOverlay]
    let region: MKCoordinateRegion?
    let hasMapContent: Bool

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
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoFallback = ISO8601DateFormatter()
        self.pathOverlays = mapData.pathOverlays.map { overlay in
            let coords = overlay.coordinates.map {
                CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
            }
            let parsedTimes: [Date?] = overlay.timestamps.map { iso -> Date? in
                guard let iso else { return nil }
                return isoFormatter.date(from: iso) ?? isoFallback.date(from: iso)
            }
            let samples: [TrackSample]
            if parsedTimes.count == coords.count {
                samples = zip(coords, parsedTimes).map { TrackSample(coordinate: $0.0, timestamp: $0.1) }
            } else {
                samples = []
            }
            return PathOverlay(
                coordinates: coords,
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
