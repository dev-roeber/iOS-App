#if canImport(SwiftUI) && canImport(MapKit)
import SwiftUI
import MapKit
import LocationHistoryConsumer

@available(iOS 17.0, macOS 14.0, *)
struct AppExportPreviewMapView: View {
    @EnvironmentObject private var preferences: AppPreferences

    let previewData: ExportPreviewData
    let fillContainer: Bool
    let mapControlTopPadding: CGFloat
    /// When true, the built-in `MapLayerMenu` control overlay is omitted so the
    /// caller can render its own multi-layer overlays (Phase 3c multi-layer
    /// export hero). Defaults to false to preserve previous behavior.
    let hidesBuiltInControls: Bool
    @State private var renderData: ExportPreviewRenderData
    @State private var internalMapPosition: MapCameraPosition
    /// Optional external camera binding. When provided, the parent owns the
    /// camera state (e.g. for external zoom / locate controls). When nil, the
    /// view keeps its own `internalMapPosition` so the legacy preview keeps
    /// working unchanged.
    private let externalMapPosition: Binding<MapCameraPosition>?

    init(
        previewData: ExportPreviewData,
        fillContainer: Bool = false,
        mapControlTopPadding: CGFloat = 8,
        hidesBuiltInControls: Bool = false,
        mapPosition: Binding<MapCameraPosition>? = nil
    ) {
        self.previewData = previewData
        self.fillContainer = fillContainer
        self.mapControlTopPadding = mapControlTopPadding
        self.hidesBuiltInControls = hidesBuiltInControls
        self.externalMapPosition = mapPosition
        let initialRender = ExportPreviewRenderData(previewData: previewData)
        self._renderData = State(initialValue: initialRender)
        if let region = initialRender.region {
            self._internalMapPosition = State(initialValue: .region(region))
        } else {
            self._internalMapPosition = State(initialValue: .automatic)
        }
    }

    private var mapPositionBinding: Binding<MapCameraPosition> {
        externalMapPosition ?? $internalMapPosition
    }

    var body: some View {
        if renderData.hasMapContent, let region = renderData.region {
            mapContent(region: region)
                .overlay(alignment: .topTrailing) {
                    if !hidesBuiltInControls {
                        mapControls
                            .padding(.top, mapControlTopPadding)
                            .padding(.trailing, 8)
                            .padding(.leading, 8)
                            .padding(.bottom, 8)
                    }
                }
                .accessibilityLabel(mapAccessibilityLabel)
                .accessibilityIdentifier(AppAccessibilityID.Map.exportPreviewRoot)
                .onChange(of: previewData) { _, newValue in
                    let newRender = ExportPreviewRenderData(previewData: newValue)
                    renderData = newRender
                    if let region = newRender.region {
                        withAnimation {
                            if let binding = externalMapPosition {
                                binding.wrappedValue = .region(region)
                            } else {
                                internalMapPosition = .region(region)
                            }
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private func mapContent(region: MKCoordinateRegion) -> some View {
        let map = Map(position: mapPositionBinding) {
            let _ = region
            ForEach(Array(renderData.waypointAnnotations.enumerated()), id: \.offset) { _, annotation in
                Marker(annotation.semanticType ?? "Waypoint", coordinate: annotation.coordinate)
                .tint(MapPalette.visitColor(for: annotation.semanticType))
            }
            ForEach(Array(renderData.pathOverlays.enumerated()), id: \.offset) { _, path in
                MapPolyline(coordinates: path.coordinates)
                    .stroke(
                        Color.white.opacity(MapTrackStyle.haloOpacity),
                        style: MapTrackStyle.stroke(width: MapTrackStyle.Width.export * MapTrackStyle.haloMultiplier)
                    )
                if preferences.mapTrackColorMode == .speed,
                   let speeds = path.speedSamples,
                   speeds.count == path.coordinates.count {
                    ForEach(0..<(path.coordinates.count - 1), id: \.self) { i in
                        let avg = (speeds[i] + speeds[i + 1]) * 0.5
                        let normalized = min(max(avg / 16.7, 0.0), 1.0)
                        MapPolyline(coordinates: [path.coordinates[i], path.coordinates[i + 1]])
                            .stroke(
                                SpeedColors.color(for: normalized),
                                style: MapTrackStyle.stroke(width: MapTrackStyle.Width.export)
                            )
                    }
                } else {
                    MapPolyline(coordinates: path.coordinates)
                        .stroke(
                            exportStrokeColor(for: path.activityType),
                            style: MapTrackStyle.stroke(width: MapTrackStyle.Width.export)
                        )
                }
            }
        }
        .mapStyle(AppMapStyleResolver.mapStyle(for: preferences.preferredMapStyle, showsRealisticElevation: preferences.mapShowsRealisticElevation))

        if fillContainer {
            map
        } else {
            map
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    @ViewBuilder
    private var mapControls: some View {
        MapLayerMenu(configuration: MapLayerMenu.Configuration(
            fitToData: renderData.region == nil ? nil : {
                if let region = renderData.region {
                    withAnimation {
                        if let binding = externalMapPosition {
                            binding.wrappedValue = .region(region)
                        } else {
                            internalMapPosition = .region(region)
                        }
                    }
                }
            }
        ))
    }

    private var mapAccessibilityLabel: String {
        let routes = renderData.pathOverlays.count
        let waypoints = renderData.waypointAnnotations.count
        let points = renderData.pathOverlays.reduce(0) { partialResult, overlay in
            partialResult + overlay.coordinates.count
        }
        if preferences.appLanguage.isGerman {
            return "Vorschaukarte mit \(routes) \(routes == 1 ? "Route" : "Routen"), \(waypoints) \(waypoints == 1 ? "Wegpunkt" : "Wegpunkten") und \(points) eingezeichneten Routenpunkten"
        }
        return "Preview map with \(routes) \(routes == 1 ? "route" : "routes"), \(waypoints) \(waypoints == 1 ? "waypoint" : "waypoints"), and \(points) plotted route points"
    }

    /// Honors the global Layer-Panel selection on the export preview / hero
    /// map. Export-preview overlays do not carry per-segment speed samples, so
    /// the Tempo layer falls back to a uniform speed-warm tint, mirroring the
    /// Insights pipeline. Elevation / Weather prepared remain placeholder
    /// tints until their data layers ship (tracked as follow-up).
    private func exportStrokeColor(for activityType: String?) -> Color {
        switch preferences.mapTrackColorMode {
        case .activity:
            return MapPalette.routeColor(for: activityType)
        case .speed:
            return SpeedColors.color(for: 0.65)
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

struct ExportPreviewRenderData {
    struct WaypointAnnotation {
        let coordinate: CLLocationCoordinate2D
        let semanticType: String?
    }

    struct PathOverlay {
        let coordinates: [CLLocationCoordinate2D]
        let activityType: String?
        /// Per-coordinate speed in m/s, aligned to `coordinates`. Only
        /// populated when the source path carried per-point timestamps so
        /// the Tempo (per-segment) layer can colour-grade each segment.
        let speedSamples: [Double]?
    }

    let waypointAnnotations: [WaypointAnnotation]
    let pathOverlays: [PathOverlay]
    let region: MKCoordinateRegion?
    let hasMapContent: Bool

    init(previewData: ExportPreviewData) {
        self.waypointAnnotations = previewData.waypointAnnotations.map {
            WaypointAnnotation(
                coordinate: CLLocationCoordinate2D(
                    latitude: $0.coordinate.lat,
                    longitude: $0.coordinate.lon
                ),
                semanticType: $0.semanticType
            )
        }
        self.pathOverlays = previewData.pathOverlays.map { overlay in
            let coords = overlay.coordinates.map {
                CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
            }
            // Cap per-segment rendering at ≤500 coords (= ≤499 segments) so a
            // very dense recorded track does not flood MapKit with overlays.
            // Beyond the cap we fall back to the uniform Tempo tint.
            let speedSamples: [Double]? = {
                guard coords.count >= 2, coords.count <= 500 else { return nil }
                guard overlay.timestamps.count == overlay.coordinates.count,
                      !overlay.timestamps.isEmpty else { return nil }
                let times: [Date?] = overlay.timestamps.map {
                    ExportPreviewRenderData.parseISO($0)
                }
                guard times.contains(where: { $0 != nil }) else { return nil }
                // The export preview overlays carry the raw (unsimplified)
                // points, so we can derive a speed per coord directly using
                // the same SimplifiedSpeedSampler helper with `simplified ==
                // raw`. This keeps a single code path with the Insights
                // overview.
                return SimplifiedSpeedSampler.speedSamples(
                    rawCoords: coords,
                    rawTimestamps: times,
                    simplifiedCoords: coords
                )
            }()
            return PathOverlay(
                coordinates: coords,
                activityType: overlay.activityType,
                speedSamples: speedSamples
            )
        }
        self.region = previewData.fittedRegion.map {
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
        self.hasMapContent = previewData.hasMapContent
    }

    /// ISO-8601 parser shared between the export preview and overview
    /// render-data builders. Tries the fractional-seconds variant first
    /// (matches Google Timeline / Live recording shape), then falls back
    /// to the plain ISO formatter so legacy fixtures still parse.
    static func parseISO(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        if let d = Self.isoFractional.date(from: value) { return d }
        return Self.isoPlain.date(from: value)
    }

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain = ISO8601DateFormatter()
}
#endif
