import Foundation

/// Pure helper that decides whether the live-tracking map camera should follow
/// the latest GPS fix or skip this tick. Train I, Phase 1 (2026-05-16).
///
/// Follow-mode updates `mapPosition = .region(...)` on every GPS sample. On a
/// dense live recording (one sample every 8 s / 15 m by default) that produces
/// a stream of MapKit camera changes; SwiftUI's `MapCameraPosition` binding
/// observably re-evaluates the map on each one. This helper folds two cheap
/// thresholds — a minimum elapsed time *and* a minimum distance from the last
/// applied camera centre — together with a "follow off → never auto-update"
/// rule.
///
/// Pure: no state, no timers, no MapKit/CoreLocation imports. Deterministic
/// for the same inputs, Linux-testable.
public enum LiveCameraUpdateThrottle {

    /// Decision returned by `shouldUpdate`.
    public enum Decision: Equatable {
        /// Skip this tick — follow is off, or both thresholds were below limit.
        case skip
        /// Apply the camera update *and* commit the current sample as the new
        /// baseline (the caller stores `now` + `coordinate` for the next call).
        case update
    }

    /// Decide whether the camera should be re-centered on `coordinate`.
    ///
    /// - Parameters:
    ///   - isFollowing: Current follow-location state. When `false`, returns
    ///     `.skip` unconditionally — the user controls the camera.
    ///   - coordinate: The candidate target coordinate.
    ///   - now: Current timestamp.
    ///   - lastUpdate: Timestamp + coordinate of the most recently applied
    ///     camera update. `nil` means "no previous update" — always update.
    ///   - minInterval: Minimum elapsed time before the next update can fire.
    ///     Defaults to 0.5 s (sub-second updates are visually noisy and burn
    ///     frame time without adding information).
    ///   - minDistanceMeters: Minimum distance from the previous centre before
    ///     the next update can fire. Defaults to 25 m (roughly two GPS-recorder
    ///     samples at the default 15 m distanceFilter).
    /// - Returns: `.update` when the camera should re-center, `.skip` otherwise.
    public static func shouldUpdate(
        isFollowing: Bool,
        coordinate: Coordinate,
        now: Date,
        lastUpdate: (timestamp: Date, coordinate: Coordinate)?,
        minInterval: TimeInterval = 0.5,
        minDistanceMeters: Double = 25.0
    ) -> Decision {
        guard isFollowing else { return .skip }
        guard let last = lastUpdate else { return .update }
        let elapsed = now.timeIntervalSince(last.timestamp)
        let distance = Coordinate.distanceMeters(last.coordinate, coordinate)
        if elapsed >= minInterval && distance >= minDistanceMeters {
            return .update
        }
        return .skip
    }

    /// Foundation-only coordinate value used by the throttle. The view layer
    /// converts to/from `CLLocationCoordinate2D` at the boundary.
    public struct Coordinate: Equatable, Hashable {
        public let latitude: Double
        public let longitude: Double

        public init(latitude: Double, longitude: Double) {
            self.latitude = latitude
            self.longitude = longitude
        }

        /// Approximate great-circle distance in meters using the equirectangular
        /// projection. Accurate enough for sub-kilometer camera-throttle
        /// decisions; not intended for navigation-grade distance computation.
        public static func distanceMeters(_ a: Coordinate, _ b: Coordinate) -> Double {
            let earthRadiusM = 6_371_000.0
            let lat1 = a.latitude * .pi / 180
            let lat2 = b.latitude * .pi / 180
            let dLat = (b.latitude - a.latitude) * .pi / 180
            let dLon = (b.longitude - a.longitude) * .pi / 180
            let x = dLon * cos((lat1 + lat2) / 2)
            let y = dLat
            return sqrt(x * x + y * y) * earthRadiusM
        }
    }
}
