#if canImport(SwiftUI) && canImport(MapKit)
import SwiftUI
import MapKit

// MARK: - Track styling constants

/// Shared visual constants for polyline rendering across all map views.
/// Centralised so a future tweak (e.g. nudging line widths or halo alpha) is
/// a one-file change, and all maps stay visually consistent.
public enum MapTrackStyle {
    /// Recommended core stroke widths by context. Round-capped on every
    /// view — square caps look brittle on every bend.
    public enum Width {
        public static let overview: Double  = 3.0
        public static let day: Double       = 4.0
        public static let export: Double    = 5.0
        public static let live: Double      = 5.5
        public static let editor: Double    = 4.5
    }

    /// Halo underlayer multiplier on top of the core width. The halo is
    /// drawn translucent white (or near-white on hybrid) below the colour
    /// stroke so the track stays legible on busy basemaps and especially
    /// on satellite imagery.
    public static let haloMultiplier: Double = 1.85
    public static let haloOpacity: Double = 0.28

    public static let standardStroke = StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)

    public static func stroke(width: Double) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }
}

// MARK: - Speed colour palette

/// Palette identifier for the speed-colour layer. Adapted from Strava's
/// public colour ramp — perceptually monotonic from cool→warm with a clear
/// luminance gradient so the layer remains readable in B&W printouts and
/// for users with red-green colour blindness.
public enum MapSpeedPalette: String, CaseIterable, Sendable {
    case strava
    case viridis

    public var labelKey: String {
        switch self {
        case .strava:  return "Speed colours"
        case .viridis: return "Viridis"
        }
    }
}

enum SpeedColors {
    /// Strava-like ramp: deep purple → blue → cyan → green → yellow → orange → red.
    /// Values must be sorted by `position` in 0…1 range.
    static let strava: [(position: Double, color: HeatmapRGB)] = [
        (0.00, HeatmapRGB(red: 0.180, green: 0.102, blue: 0.278)), // deep purple
        (0.18, HeatmapRGB(red: 0.122, green: 0.306, blue: 0.616)), // navy
        (0.38, HeatmapRGB(red: 0.000, green: 0.690, blue: 1.000)), // cyan
        (0.55, HeatmapRGB(red: 0.000, green: 0.902, blue: 0.463)), // green
        (0.72, HeatmapRGB(red: 1.000, green: 0.922, blue: 0.231)), // yellow
        (0.86, HeatmapRGB(red: 1.000, green: 0.569, blue: 0.000)), // orange
        (1.00, HeatmapRGB(red: 1.000, green: 0.090, blue: 0.267)), // red
    ]

    /// Viridis fallback (matplotlib reference): colour-blind-safe.
    static let viridis: [(position: Double, color: HeatmapRGB)] = [
        (0.00, HeatmapRGB(red: 0.267, green: 0.005, blue: 0.329)),
        (0.25, HeatmapRGB(red: 0.231, green: 0.318, blue: 0.546)),
        (0.50, HeatmapRGB(red: 0.129, green: 0.566, blue: 0.551)),
        (0.75, HeatmapRGB(red: 0.369, green: 0.788, blue: 0.382)),
        (1.00, HeatmapRGB(red: 0.992, green: 0.906, blue: 0.144)),
    ]

    static func stops(for palette: MapSpeedPalette) -> [(position: Double, color: HeatmapRGB)] {
        switch palette {
        case .strava:  return strava
        case .viridis: return viridis
        }
    }

    static func color(for normalized: Double, palette: MapSpeedPalette = .strava) -> Color {
        rgb(for: normalized, palette: palette).color
    }

    static func rgb(for normalized: Double, palette: MapSpeedPalette = .strava) -> HeatmapRGB {
        let stops = stops(for: palette)
        let clamped = min(max(normalized, 0.0), 1.0)
        guard let first = stops.first else {
            return HeatmapRGB(red: 0.5, green: 0.5, blue: 0.5)
        }
        if clamped <= first.position { return first.color }
        for index in 1..<stops.count {
            let previous = stops[index - 1]
            let current = stops[index]
            guard clamped <= current.position else { continue }
            let distance = current.position - previous.position
            let fraction = distance > 0 ? (clamped - previous.position) / distance : 0
            return previous.color.interpolated(to: current.color, fraction: fraction)
        }
        return stops.last?.color ?? first.color
    }
}

// MARK: - Speed computation

/// One coordinate sample with optional timestamp. Speed is derived from
/// (lat, lon, time) over consecutive samples; missing timestamps result
/// in a zero-speed segment (rendered at the cool palette end).
public struct TrackSample: Equatable {
    public let coordinate: CLLocationCoordinate2D
    public let timestamp: Date?

    public init(coordinate: CLLocationCoordinate2D, timestamp: Date?) {
        self.coordinate = coordinate
        self.timestamp = timestamp
    }
}

/// One coloured segment between two consecutive samples.
public struct SpeedSegment: Identifiable {
    public let id: Int
    public let start: CLLocationCoordinate2D
    public let end: CLLocationCoordinate2D
    public let speedMS: Double
    public let normalizedSpeed: Double
}

public enum SpeedTrackBuilder {
    /// Maximum reasonable Δt between two samples treated as a continuous
    /// segment for speed purposes. A larger gap is treated as a recording
    /// pause and the segment colour is anchored at the bottom of the ramp.
    private static let maxRealisticDt: TimeInterval = 30.0
    /// Maximum jump (degrees) between consecutive samples that we still
    /// treat as a real movement. Beyond this we assume a GPS spike and the
    /// segment is dropped.
    private static let maxRealisticJumpDegrees: Double = 1.0
    /// Rolling-mean window — research-recommended 5–9 samples (≈ 5–9 s at
    /// 1 Hz). 7 is the sweet spot: smooths jitter without lagging real
    /// changes (e.g. a cyclist accelerating from a stop).
    private static let smoothingWindow = 7

    /// Build coloured segments for the given samples.
    /// - Parameter adaptive: when true, the speed range is normalised
    ///   against the track's own P5–P95 percentiles so a slow walking
    ///   track and a fast cycling track both use the full colour range.
    ///   When false, fixed bands are applied (0…16.7 m/s / 60 km/h).
    nonisolated public static func segments(
        from samples: [TrackSample],
        adaptive: Bool = true
    ) -> [SpeedSegment] {
        guard samples.count >= 2 else { return [] }

        var rawSpeeds: [Double] = []
        rawSpeeds.reserveCapacity(samples.count - 1)
        var validIndexes: [Int] = []
        validIndexes.reserveCapacity(samples.count - 1)

        for index in 0..<(samples.count - 1) {
            let a = samples[index]
            let b = samples[index + 1]
            let speed = instantaneousSpeed(from: a, to: b)
            if let speed {
                rawSpeeds.append(speed)
                validIndexes.append(index)
            } else {
                rawSpeeds.append(0)
                validIndexes.append(index)
            }
        }

        let smoothed = rollingMean(rawSpeeds, window: smoothingWindow)

        let (low, high): (Double, Double)
        if adaptive {
            (low, high) = percentileBounds(smoothed, lower: 0.05, upper: 0.95)
        } else {
            (low, high) = (0.0, 16.7)
        }
        let span = max(high - low, 0.001)

        var result: [SpeedSegment] = []
        result.reserveCapacity(samples.count - 1)
        for (offset, segmentIndex) in validIndexes.enumerated() {
            let speed = smoothed[offset]
            let dLat = abs(samples[segmentIndex + 1].coordinate.latitude - samples[segmentIndex].coordinate.latitude)
            let dLon = abs(samples[segmentIndex + 1].coordinate.longitude - samples[segmentIndex].coordinate.longitude)
            if dLat > maxRealisticJumpDegrees || dLon > maxRealisticJumpDegrees {
                continue
            }
            let normalized = min(max((speed - low) / span, 0.0), 1.0)
            result.append(
                SpeedSegment(
                    id: segmentIndex,
                    start: samples[segmentIndex].coordinate,
                    end: samples[segmentIndex + 1].coordinate,
                    speedMS: speed,
                    normalizedSpeed: normalized
                )
            )
        }
        return result
    }

    /// Haversine distance / Δt. Returns nil if either timestamp is missing
    /// or the gap is too large to read as continuous motion.
    nonisolated public static func instantaneousSpeed(from a: TrackSample, to b: TrackSample) -> Double? {
        guard let ta = a.timestamp, let tb = b.timestamp else { return nil }
        let dt = tb.timeIntervalSince(ta)
        guard dt > 0.5, dt < maxRealisticDt else { return nil }
        let distance = haversine(a.coordinate, b.coordinate)
        return distance / dt
    }

    nonisolated static func haversine(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let earthRadiusM = 6_371_000.0
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadiusM * atan2(sqrt(h), sqrt(1 - h))
    }

    nonisolated static func rollingMean(_ values: [Double], window: Int) -> [Double] {
        guard values.count > 0, window > 1 else { return values }
        var result: [Double] = []
        result.reserveCapacity(values.count)
        let half = window / 2
        for i in 0..<values.count {
            let lower = max(0, i - half)
            let upper = min(values.count - 1, i + half)
            var sum = 0.0
            for j in lower...upper { sum += values[j] }
            let count = upper - lower + 1
            result.append(sum / Double(count))
        }
        return result
    }

    nonisolated static func percentileBounds(
        _ values: [Double],
        lower: Double,
        upper: Double
    ) -> (Double, Double) {
        guard !values.isEmpty else { return (0, 1) }
        let sorted = values.sorted()
        let lowerIndex = max(0, min(sorted.count - 1, Int(Double(sorted.count - 1) * lower)))
        let upperIndex = max(0, min(sorted.count - 1, Int(Double(sorted.count - 1) * upper)))
        let lowerValue = sorted[lowerIndex]
        let upperValue = sorted[upperIndex]
        if upperValue - lowerValue < 0.5 {
            // All values in a tight band — expand to keep the colour range usable.
            return (lowerValue, lowerValue + 1.0)
        }
        return (lowerValue, upperValue)
    }
}

// MARK: - Breadcrumb fade buckets

/// Splits a trail into 3 buckets with progressive alpha so the oldest part
/// of the live trail fades away while the freshest segment stays solid.
/// Returns coordinate arrays of (oldThird, midThird, newestThird) along
/// with their suggested alpha values. The buckets overlap by one point so
/// adjacent segments connect without a visible gap.
public enum LiveBreadcrumbFade {
    public struct Bucket {
        public let coordinates: [CLLocationCoordinate2D]
        public let alpha: Double
    }

    public static func buckets(from coordinates: [CLLocationCoordinate2D]) -> [Bucket] {
        guard coordinates.count >= 2 else { return [] }
        if coordinates.count < 6 {
            return [Bucket(coordinates: coordinates, alpha: 0.95)]
        }
        let third = coordinates.count / 3
        let oldEnd = third + 1
        let midEnd = (third * 2) + 1
        let oldChunk = Array(coordinates[0..<min(oldEnd, coordinates.count)])
        let midChunk = Array(coordinates[max(0, oldEnd - 1)..<min(midEnd, coordinates.count)])
        let newChunk = Array(coordinates[max(0, midEnd - 1)..<coordinates.count])
        return [
            Bucket(coordinates: oldChunk, alpha: 0.30),
            Bucket(coordinates: midChunk, alpha: 0.60),
            Bucket(coordinates: newChunk, alpha: 0.95),
        ]
    }
}

// MARK: - User preference

/// Determines whether tracks render in their semantic activity-type colour
/// or in a speed-coloured gradient ("Tempolayer").
public enum AppMapTrackColorMode: String, CaseIterable, Identifiable, Sendable {
    case activity
    case speed

    public var id: String { rawValue }

    public var labelKey: String {
        switch self {
        case .activity: return "Activity"
        case .speed:    return "Speed"
        }
    }
}
#endif
