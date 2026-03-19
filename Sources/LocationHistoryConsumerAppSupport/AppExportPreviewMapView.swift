#if canImport(SwiftUI) && canImport(MapKit)
import SwiftUI
import MapKit
import LocationHistoryConsumer

@available(iOS 17.0, macOS 14.0, *)
struct AppExportPreviewMapView: View {
    @EnvironmentObject private var preferences: AppPreferences

    let previewData: ExportPreviewData

    var body: some View {
        if previewData.hasMapContent, let region = previewData.fittedRegion {
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
                ForEach(Array(previewData.pathOverlays.enumerated()), id: \.offset) { _, path in
                    MapPolyline(coordinates: path.coordinates.map {
                        CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
                    })
                    .stroke(MapPalette.routeColor(for: path.activityType), lineWidth: 4)
                }
            }
            .mapStyle(preferences.preferredMapStyle.isHybrid ? .hybrid : .standard)
            .frame(height: 220)
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
                .accessibilityLabel(preferences.preferredMapStyle.isHybrid ? "Switch to standard map" : "Switch to satellite map")
            }
            .accessibilityLabel(mapAccessibilityLabel)
        }
    }

    private var mapAccessibilityLabel: String {
        let routes = previewData.pathOverlays.count
        let points = previewData.pathOverlays.reduce(0) { partialResult, overlay in
            partialResult + overlay.coordinates.count
        }
        return "Preview map with \(routes) \(routes == 1 ? "route" : "routes") and \(points) plotted points"
    }
}
#endif
