import Foundation

/// Single source of truth for the "effective" distance of a path.
///
/// Several import sources (Google Timeline raw export in particular) emit
/// path geometry — i.e. `points` with valid `lat`/`lon` — but no explicit
/// `distanceM` value. Before this calculator existed, `AppExportQueries.summary`
/// already did its own fallback and reconstructed the distance from the
/// polyline; `DayDetailViewState.PathItem` and `DayDetailPresentation` did
/// **not** and therefore showed `Distance 0` on the day-detail screen even
/// when Insights/Overview reported the right total. That is exactly the
/// bug this calculator removes.
///
/// Semantics:
/// - `rawDistanceM` is honoured when finite and `> 0`. This preserves the
///   exporter's authoritative value when present.
/// - Otherwise the calculator walks `points` (preferred) or, as a last
///   resort, `flatCoordinates` (lat/lon pairs in a flat `[Double]`) and
///   sums consecutive haversine hops.
/// - With fewer than two valid coordinate pairs the result is `0`.
public enum PathDistanceCalculator {

    /// Returns the effective distance in metres for the given inputs.
    public static func effectiveDistance(
        rawDistanceM: Double?,
        points: [(lat: Double, lon: Double)],
        flatCoordinates: [Double]? = nil
    ) -> Double {
        if let raw = rawDistanceM, raw.isFinite, raw > 0 {
            return raw
        }

        if points.count >= 2 {
            return polylineDistanceMeters(points)
        }

        if let flat = flatCoordinates, flat.count >= 4 {
            let pairs: [(lat: Double, lon: Double)] = stride(from: 0, to: flat.count - 1, by: 2).map {
                (lat: flat[$0], lon: flat[$0 + 1])
            }
            if pairs.count >= 2 {
                return polylineDistanceMeters(pairs)
            }
        }

        return 0
    }

    /// Sum of great-circle distances along the given polyline. Uses an
    /// inline haversine so the calculator stays MapKit-/CoreLocation-free
    /// and works in any module that imports `LocationHistoryConsumer`.
    private static func polylineDistanceMeters(_ coords: [(lat: Double, lon: Double)]) -> Double {
        let earthRadiusMeters = 6_371_000.0
        var total = 0.0
        var iterator = coords.makeIterator()
        guard var previous = iterator.next() else { return 0 }
        while let current = iterator.next() {
            let lat1 = previous.lat * .pi / 180.0
            let lat2 = current.lat * .pi / 180.0
            let dLat = (current.lat - previous.lat) * .pi / 180.0
            let dLon = (current.lon - previous.lon) * .pi / 180.0
            let sinDLat = sin(dLat / 2)
            let sinDLon = sin(dLon / 2)
            let a = sinDLat * sinDLat + cos(lat1) * cos(lat2) * sinDLon * sinDLon
            let c = 2 * atan2(sqrt(a), sqrt(1 - a))
            total += earthRadiusMeters * c
            previous = current
        }
        return total
    }
}

// MARK: - Convenience wrappers for the canonical model types

public extension PathDistanceCalculator {
    /// Effective distance for an `AppExport`-side `Path`.
    static func effectiveDistance(for path: Path) -> Double {
        effectiveDistance(
            rawDistanceM: path.distanceM,
            points: path.points.map { (lat: $0.lat, lon: $0.lon) },
            flatCoordinates: path.flatCoordinates
        )
    }

    /// Effective distance for the projected day-detail `PathItem`. Mirrors
    /// the source-of-truth so summary and detail agree on every day.
    static func effectiveDistance(for pathItem: DayDetailViewState.PathItem) -> Double {
        effectiveDistance(
            rawDistanceM: pathItem.distanceM,
            points: pathItem.points.map { (lat: $0.lat, lon: $0.lon) },
            flatCoordinates: nil
        )
    }
}
