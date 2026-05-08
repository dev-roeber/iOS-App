import Foundation
import LocationHistoryConsumer

/// Phase-8B — Foundation-only Heatmap-Path-Sampler.
///
/// Kanonische Priorität für die Heatmap-Aggregation eines `Path`:
/// 1. `flatCoordinates`, wenn vorhanden **und** valide (gerade Element-Anzahl).
/// 2. `points` als Fallback.
///
/// Damit wird der Doppelbug aus `AppHeatmapModel.swift:55-77` zentral
/// verhindert: wenn beide Geometrien gleichzeitig gefüllt sind (Hybrid-Test-
/// daten oder Legacy-Konversion), zählt **nur eine**. Ungerade
/// `flatCoordinates`-Längen gelten als malformed; in diesem Fall fällt der
/// Sampler auf `points` zurück. Ist auch `points` leer, liefert der Sampler
/// keinen Punkt — kein silent-zero und kein Crash.
public enum AppHeatmapPathSampler {

    /// Liefert die Lat/Lon-Paare, die in die Heatmap-Aggregation einfließen.
    /// Foundation-only — kein CoreLocation-Typ, damit Linux-testbar.
    public static func samples(forPath path: Path) -> [(lat: Double, lon: Double)] {
        if let flats = path.flatCoordinates, !flats.isEmpty, flats.count % 2 == 0 {
            var out: [(Double, Double)] = []
            out.reserveCapacity(flats.count / 2)
            for i in stride(from: 0, to: flats.count - 1, by: 2) {
                out.append((flats[i], flats[i + 1]))
            }
            return out
        }
        if !path.points.isEmpty {
            return path.points.map { ($0.lat, $0.lon) }
        }
        return []
    }

    /// Liefert die zusätzlichen Lat/Lon-Paare einer Activity. Start-/End-Marker
    /// werden bewusst getrennt von `flatCoordinates` zurückgegeben — sie sind
    /// keine Geometrie-Vertizes, sondern Endpunkte der Activity. Konsumenten
    /// mischen Marker und Geometrie selbst.
    public static func samples(forActivity activity: Activity) -> (
        markers: [(lat: Double, lon: Double)],
        geometry: [(lat: Double, lon: Double)]
    ) {
        var markers: [(Double, Double)] = []
        if let lat = activity.startLat, let lon = activity.startLon {
            markers.append((lat, lon))
        }
        if let lat = activity.endLat, let lon = activity.endLon {
            markers.append((lat, lon))
        }
        var geometry: [(Double, Double)] = []
        if let flats = activity.flatCoordinates, !flats.isEmpty, flats.count % 2 == 0 {
            geometry.reserveCapacity(flats.count / 2)
            for i in stride(from: 0, to: flats.count - 1, by: 2) {
                geometry.append((flats[i], flats[i + 1]))
            }
        }
        return (markers, geometry)
    }
}
