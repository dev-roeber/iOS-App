#if canImport(SwiftUI) && canImport(MapKit)
import SwiftUI
import MapKit
import LocationHistoryConsumer

@available(iOS 17.0, macOS 14.0, *)
public struct AppDayMapView: View {
    @EnvironmentObject private var preferences: AppPreferences
    let mapData: DayMapData
    @State private var renderData: DayMapRenderData

    public init(mapData: DayMapData) {
        self.mapData = mapData
        self._renderData = State(initialValue: DayMapRenderData(mapData: mapData))
    }

    public var body: some View {
        if renderData.hasMapContent, let region = renderData.region {
            mapContent(region: region)
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    Button {
                        preferences.preferredMapStyle.toggle()
                    } label: {
                        Image(systemName: preferences.preferredMapStyle.isHybrid ? "map" : "globe")
                            .font(.caption)
                            .padding(7)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding(8)
                .accessibilityLabel(t(preferences.preferredMapStyle.isHybrid ? "Switch to standard map" : "Switch to satellite map"))
                }
                .accessibilityLabel(mapAccessibilityLabel)
                .onChange(of: mapData) { _, newValue in
                    renderData = DayMapRenderData(mapData: newValue)
                }
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
        Map(initialPosition: .region(MKCoordinateRegion(
            center: region.center,
            span: region.span
        ))) {
            ForEach(Array(renderData.pathOverlays.enumerated()), id: \.offset) { _, path in
                let coords: [CLLocationCoordinate2D] = preferences.dayPathDisplayMode == .mapMatched
                    ? PathSimplification.douglasPeucker(path.coordinates)
                    : path.coordinates
                MapPolyline(coordinates: coords)
                .stroke(MapPalette.routeColor(for: path.activityType), lineWidth: 3)
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
        self.pathOverlays = mapData.pathOverlays.map {
            PathOverlay(
                coordinates: $0.coordinates.map {
                    CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
                },
                activityType: $0.activityType
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
