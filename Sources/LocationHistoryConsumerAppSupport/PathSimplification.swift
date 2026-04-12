import Foundation
import CoreLocation

public enum PathSimplification {
    /// Douglas-Peucker line simplification.
    /// - Parameters:
    ///   - points: Input coordinates.
    ///   - epsilon: Tolerance in metres (default: 15 m).
    /// - Returns: Simplified coordinates. Original data is never mutated.
    public static func douglasPeucker(
        _ points: [CLLocationCoordinate2D],
        epsilon: Double = 15.0
    ) -> [CLLocationCoordinate2D] {
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
        point: CLLocationCoordinate2D,
        lineStart: CLLocationCoordinate2D,
        lineEnd: CLLocationCoordinate2D
    ) -> Double {
        let p = CLLocation(latitude: point.latitude, longitude: point.longitude)
        let a = CLLocation(latitude: lineStart.latitude, longitude: lineStart.longitude)
        let b = CLLocation(latitude: lineEnd.latitude, longitude: lineEnd.longitude)

        let ab = a.distance(from: b)
        guard ab > 0 else { return a.distance(from: p) }

        let ap = a.distance(from: p)
        let bp = b.distance(from: p)

        let s = (ap + bp + ab) / 2
        let area = max(0, s * (s - ap) * (s - bp) * (s - ab))
        return 2 * sqrt(area) / ab
    }
}
