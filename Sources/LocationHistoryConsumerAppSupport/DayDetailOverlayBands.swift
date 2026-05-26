// DayDetailOverlayBands
//
// Adapters that turn a `DayDetailViewState` into the input shape expected by
// the reusable speed-band / elevation-profile components introduced in
// PR #38. Speed is reconstructed from consecutive `PathPointItem`s using
// `SpeedTrackBuilder.instantaneousSpeed` (the same primitive that powers
// the Tempo map layer), so the day-detail band stays in sync with what the
// map shows when `mapTrackColorMode == .speed`.
//
// Elevation: `DayDetailViewState.PathPointItem` does not yet carry an
// `elevationM` value (the importer drops it at the day-summary layer). The
// helper therefore returns an empty array for the elevation samples until
// the consumer model is extended. The `AppElevationProfileView` renders
// its own empty-state placeholder in that case, which is fine for a v1
// shipping with Tempo as the primary band.

#if canImport(SwiftUI)
import Foundation
import LocationHistoryConsumer
#if canImport(CoreLocation)
import CoreLocation
#endif

enum DayDetailOverlayBands {
    /// Cached parsers. `DayMapData` already parses ISO strings inside the
    /// renderer; we do the same here so the band stays consistent.
    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoFallback: ISO8601DateFormatter = ISO8601DateFormatter()

    private static func parse(_ iso: String?) -> Date? {
        guard let iso else { return nil }
        return isoFractional.date(from: iso) ?? isoFallback.date(from: iso)
    }

    /// Concatenates all path geometries chronologically and converts each
    /// consecutive pair to an `AppSpeedBandSample`. Pairs that fail the
    /// `SpeedTrackBuilder` sanity checks (missing timestamps, gaps > 30s,
    /// implausible jumps) are skipped. Empty result → empty-state band.
    @MainActor
    static func speedSamples(from detail: DayDetailViewState) -> [AppSpeedBandSample] {
        #if canImport(CoreLocation)
        struct Sample { let coord: CLLocationCoordinate2D; let time: Date }

        var ordered: [Sample] = []
        for path in detail.paths {
            for point in path.points {
                guard let time = parse(point.time) else { continue }
                ordered.append(
                    Sample(
                        coord: CLLocationCoordinate2D(latitude: point.lat, longitude: point.lon),
                        time: time
                    )
                )
            }
        }
        ordered.sort { $0.time < $1.time }
        guard ordered.count >= 2 else { return [] }

        var samples: [AppSpeedBandSample] = []
        samples.reserveCapacity(ordered.count - 1)
        for index in 0 ..< (ordered.count - 1) {
            let a = TrackSample(coordinate: ordered[index].coord, timestamp: ordered[index].time)
            let b = TrackSample(coordinate: ordered[index + 1].coord, timestamp: ordered[index + 1].time)
            guard let speed = SpeedTrackBuilder.instantaneousSpeed(from: a, to: b) else { continue }
            // Use the later sample's timestamp so the highlight marker can
            // line up with the recording-position concept used elsewhere.
            samples.append(AppSpeedBandSample(timestamp: ordered[index + 1].time, speed: speed))
        }
        return samples
        #else
        return []
        #endif
    }

    /// Returns an empty array until `DayDetailViewState.PathPointItem`
    /// gains an `elevationM` field. The component renders its own
    /// "Keine Höhendaten" placeholder, keeping the layout stable.
    @MainActor
    static func elevationSamples(from detail: DayDetailViewState) -> [AppElevationProfileSample] {
        _ = detail
        return []
    }
}

#endif
