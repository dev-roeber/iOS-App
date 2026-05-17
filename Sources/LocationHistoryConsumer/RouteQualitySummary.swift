import Foundation

/// Train O, Phase 3 — Foundation-only route-quality assessment. Given
/// an ordered sequence of `(lat, lon)` pairs, returns a small summary
/// the UI can surface as a hint ("Looks sparse" / "Contains gaps")
/// without exposing the underlying coordinates.
///
/// **Not a guarantee.** This is a heuristic indicator, not a medical
/// or navigational accuracy claim. The UI should phrase results as
/// hints, not errors.
///
/// **Privacy:** the summary carries no coordinates — only counts and
/// distances in metres.
public struct RouteQualitySummary: Equatable, Sendable {

    public let pointCount: Int
    /// Mean spacing between consecutive points, in metres. `nil` for
    /// fewer than two points.
    public let averageSpacingM: Double?
    /// Distance between the two consecutive points that are furthest
    /// apart, in metres. `nil` for fewer than two points.
    public let largestGapM: Double?
    public let level: Level

    public enum Level: String, Equatable, Sendable, CaseIterable {
        case empty
        case sparse
        case containsGaps
        case good
    }

    public init(
        pointCount: Int,
        averageSpacingM: Double?,
        largestGapM: Double?,
        level: Level
    ) {
        self.pointCount = pointCount
        self.averageSpacingM = averageSpacingM
        self.largestGapM = largestGapM
        self.level = level
    }

    public static let empty = RouteQualitySummary(
        pointCount: 0,
        averageSpacingM: nil,
        largestGapM: nil,
        level: .empty
    )

    // MARK: - Thresholds (tunable, documented)

    /// Routes shorter than this point count fall into `.sparse`
    /// regardless of spacing. Chosen so a 10-sample minimum
    /// (≈ ten GPS fixes) is enough to escape the sparse bucket.
    public static let sparsePointCountThreshold = 10

    /// `.containsGaps` triggers when the largest gap is at least
    /// `gapMultiplier × average spacing` AND the largest gap exceeds
    /// `gapAbsoluteFloorM`. The double guard avoids false-positive
    /// gaps on stationary or very-short tracks.
    public static let gapMultiplier: Double = 5.0
    public static let gapAbsoluteFloorM: Double = 250.0

    // MARK: - Public evaluator

    public static func evaluate(points: [(lat: Double, lon: Double)]) -> RouteQualitySummary {
        guard !points.isEmpty else { return .empty }

        let count = points.count

        guard count >= 2 else {
            // A single point has no spacing — sparse but not empty.
            return RouteQualitySummary(
                pointCount: count,
                averageSpacingM: nil,
                largestGapM: nil,
                level: .sparse
            )
        }

        var totalM = 0.0
        var largest = 0.0
        for i in 1..<count {
            let d = haversineMetres(points[i - 1], points[i])
            totalM += d
            if d > largest { largest = d }
        }
        let segments = Double(count - 1)
        let avg = segments > 0 ? totalM / segments : nil

        let level: Level
        if count < sparsePointCountThreshold {
            level = .sparse
        } else if let avg, largest >= max(gapAbsoluteFloorM, gapMultiplier * avg) {
            level = .containsGaps
        } else {
            level = .good
        }

        return RouteQualitySummary(
            pointCount: count,
            averageSpacingM: avg,
            largestGapM: largest,
            level: level
        )
    }

    // MARK: - Internal geometry (Foundation-only)

    /// Haversine distance in metres between two `(lat, lon)` pairs in
    /// degrees. Earth radius is the canonical WGS-84 mean of 6 371 000 m.
    internal static func haversineMetres(_ a: (lat: Double, lon: Double),
                                         _ b: (lat: Double, lon: Double)) -> Double {
        let earthRadiusM = 6_371_000.0
        let lat1 = a.lat * .pi / 180.0
        let lat2 = b.lat * .pi / 180.0
        let deltaLat = (b.lat - a.lat) * .pi / 180.0
        let deltaLon = (b.lon - a.lon) * .pi / 180.0
        let sinHalfLat = sin(deltaLat / 2.0)
        let sinHalfLon = sin(deltaLon / 2.0)
        let h = sinHalfLat * sinHalfLat
            + cos(lat1) * cos(lat2) * sinHalfLon * sinHalfLon
        return 2.0 * earthRadiusM * asin(min(1.0, sqrt(h)))
    }
}
