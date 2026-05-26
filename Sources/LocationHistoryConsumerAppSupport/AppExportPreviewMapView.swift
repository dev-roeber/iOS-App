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
                MapPolyline(coordinates: path.coordinates)
                    .stroke(
                        MapPalette.routeColor(for: path.activityType),
                        style: MapTrackStyle.stroke(width: MapTrackStyle.Width.export)
                    )
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
        self.pathOverlays = previewData.pathOverlays.map {
            PathOverlay(
                coordinates: $0.coordinates.map {
                    CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
                },
                activityType: $0.activityType
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
}
#endif
