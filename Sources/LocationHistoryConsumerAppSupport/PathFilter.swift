import Foundation
import LocationHistoryConsumer

#if canImport(CoreLocation)
import CoreLocation
#endif

public enum PathFilter {
    /// Removes GPS outlier points where the Haversine jump to the next accepted point
    /// exceeds `maxJumpMeters`. If fewer than 2 points remain after filtering, the
    /// original sequence is returned unchanged.
    public static func removeOutliers(
        _ coords: [LocationCoordinate2D],
        maxJumpMeters: Double = 5000
    ) -> [LocationCoordinate2D] {
        guard coords.count >= 2 else { return coords }
        var result: [LocationCoordinate2D] = [coords[0]]
        for i in 1..<coords.count {
            // Compare against the last *accepted* point so a single outlier does not
            // cause the remainder of the track to be dropped.
            if result.last!.distance(to: coords[i]) <= maxJumpMeters {
                result.append(coords[i])
            }
        }
        return result.count >= 2 ? result : coords
    }
}

#if canImport(CoreLocation)
public extension PathFilter {
    static func removeOutliers(
        _ coords: [CLLocationCoordinate2D],
        maxJumpMeters: Double = 5000
    ) -> [CLLocationCoordinate2D] {
        let filtered = removeOutliers(
            coords.map { LocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) },
            maxJumpMeters: maxJumpMeters
        )
        return filtered.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }
}
#endif
