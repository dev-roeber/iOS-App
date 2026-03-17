#if canImport(SwiftUI) && canImport(MapKit)
import SwiftUI
import MapKit
import LocationHistoryConsumer

@available(iOS 17.0, macOS 14.0, *)
public struct AppDayMapView: View {
    let mapData: DayMapData

    public init(mapData: DayMapData) {
        self.mapData = mapData
    }

    public var body: some View {
        if mapData.hasMapContent, let region = mapData.fittedRegion {
            mapContent(region: region)
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                .stroke(.blue, lineWidth: 3)
            }

            ForEach(Array(mapData.visitAnnotations.enumerated()), id: \.offset) { _, visit in
                Marker(
                    visit.semanticType ?? "Visit",
                    coordinate: CLLocationCoordinate2D(
                        latitude: visit.coordinate.lat,
                        longitude: visit.coordinate.lon
                    )
                )
                .tint(.red)
            }
        }
        .mapStyle(.standard)
    }
}
#endif
