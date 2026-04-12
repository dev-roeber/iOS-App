import Foundation
import LocationHistoryConsumer

#if canImport(CoreLocation)
import CoreLocation
#endif

public enum PathSimplification {
    /// Douglas-Peucker line simplification.
    /// - Parameters:
    ///   - points: Input coordinates.
    ///   - epsilon: Tolerance in metres (default: 15 m).
    /// - Returns: Simplified coordinates. Original data is never mutated.
    public static func douglasPeucker(
        _ points: [LocationCoordinate2D],
        epsilon: Double = 15.0
    ) -> [LocationCoordinate2D] {
        guard points.count > 2 else { return points }

        var maxDist = 0.0
        var maxIndex = 0
        let last = points.count - 1

        for i in 1..<last {
            let d = perpendicularDistance(
                point: points[i],
                lineStart: points[0],
                lineEnd: points[last]
            )
            if d > maxDist {
                maxDist = d
                maxIndex = i
            }
        }

        if maxDist > epsilon {
            let left  = douglasPeucker(Array(points[0...maxIndex]), epsilon: epsilon)
            let right = douglasPeucker(Array(points[maxIndex...last]), epsilon: epsilon)
            return left.dropLast() + right
        } else {
            return [points[0], points[last]]
        }
    }

    // MARK: - Private

    private static func perpendicularDistance(
        point: LocationCoordinate2D,
        lineStart: LocationCoordinate2D,
        lineEnd: LocationCoordinate2D
    ) -> Double {
        let ab = lineStart.distance(to: lineEnd)
        guard ab > 0 else { return lineStart.distance(to: point) }

        let ap = lineStart.distance(to: point)
        let bp = lineEnd.distance(to: point)

        let s = (ap + bp + ab) / 2
        let area = max(0, s * (s - ap) * (s - bp) * (s - ab))
        return 2 * sqrt(area) / ab
    }
}

#if canImport(CoreLocation)
public extension PathSimplification {
    static func douglasPeucker(
        _ points: [CLLocationCoordinate2D],
        epsilon: Double = 15.0
    ) -> [CLLocationCoordinate2D] {
        let simplified = douglasPeucker(
            points.map { LocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) },
            epsilon: epsilon
        )
        return simplified.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }
}
#endif
