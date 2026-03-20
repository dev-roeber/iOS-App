#if canImport(SwiftUI) && canImport(MapKit)
import SwiftUI
import MapKit
import LocationHistoryConsumer

@available(iOS 17.0, macOS 14.0, *)
public struct AppDayMapView: View {
    @EnvironmentObject private var preferences: AppPreferences
    let mapData: DayMapData

    public init(mapData: DayMapData) {
        self.mapData = mapData
    }

    public var body: some View {
        if mapData.hasMapContent, let region = mapData.fittedRegion {
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
        }
    }

    private var mapAccessibilityLabel: String {
        let visits = mapData.visitAnnotations.count
        let paths = mapData.pathOverlays.count
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
    private func mapContent(region: DayMapRegion) -> some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: region.centerLat,
                longitude: region.centerLon
            ),
            span: MKCoordinateSpan(
                latitudeDelta: region.spanLat,
                longitudeDelta: region.spanLon
            )
        ))) {
            ForEach(Array(mapData.pathOverlays.enumerated()), id: \.offset) { _, path in
                MapPolyline(coordinates: path.coordinates.map {
                    CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
                })
                .stroke(MapPalette.routeColor(for: path.activityType), lineWidth: 3)
            }

            ForEach(Array(mapData.visitAnnotations.enumerated()), id: \.offset) { _, visit in
                Marker(
                    t(displayNameForVisitType(visit.semanticType, default: "Visit")),
                    coordinate: CLLocationCoordinate2D(
                        latitude: visit.coordinate.lat,
                        longitude: visit.coordinate.lon
                    )
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
#endif
