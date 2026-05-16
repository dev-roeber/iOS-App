import Foundation

/// Pure helper that limits how many `RecordedTrackPoint`s a live-recording map
/// surface has to render in one frame. Train H, Phase 2 (2026-05-16).
///
/// Live-recording sessions can grow well past 10 000 points on long activities.
/// SwiftUI/MapKit `MapPolyline(coordinates:)` re-evaluates the full coordinate
/// array on each tick, so unbounded growth ties render cost to session length.
/// This helper produces a render-only subset of points: the *raw*
/// `liveTrackPoints` (and the persisted/uploaded data) stay untouched — only
/// what the view sends into the polyline is shaped.
///
/// Strategy when `cap > 0` and `points.count > cap`:
///   - The most recent half of the budget (`cap / 2`) is kept verbatim so the
///     leading edge of the live track stays at full GPS resolution.
///   - The older portion is stride-decimated to fill the remaining budget.
///   - The very first point is always preserved (track start).
///   - The very last point is always preserved (current position).
///
/// When `cap <= 0` or `points.count <= cap`, the original sequence is returned
/// and `wasCapped == false`. The helper is intentionally pure: no state, no
/// timers, no MapKit/CoreLocation imports — Linux-testable.
public enum LiveTrackRenderCap {

    public struct Result: Equatable {
        public let points: [RecordedTrackPoint]
        public let wasCapped: Bool
        public let originalCount: Int

        public var renderedCount: Int { points.count }

        public init(points: [RecordedTrackPoint], wasCapped: Bool, originalCount: Int) {
            self.points = points
            self.wasCapped = wasCapped
            self.originalCount = originalCount
        }
    }

    public static func apply(points: [RecordedTrackPoint], cap: Int) -> Result {
        let total = points.count
        if cap <= 0 || total <= cap {
            return Result(points: points, wasCapped: false, originalCount: total)
        }

        // Guard against degenerate cap values that would collapse the tail.
        let effectiveCap = max(2, cap)
        let tailCount = max(1, effectiveCap / 2)
        let headBudget = effectiveCap - tailCount
        let headSourceCount = total - tailCount
        guard headSourceCount > 0, headBudget > 0 else {
            return Result(
                points: Array(points.suffix(effectiveCap)),
                wasCapped: true,
                originalCount: total
            )
        }

        var rendered: [RecordedTrackPoint] = []
        rendered.reserveCapacity(effectiveCap)

        // Always preserve the very first sample (track start).
        rendered.append(points[0])

        // Stride-decimate the remaining head budget across indices 1..<headSourceCount.
        let remainingHeadBudget = headBudget - 1
        if remainingHeadBudget > 0 {
            let range = headSourceCount - 1
            if range > 0 {
                // Use integer arithmetic that distributes picks roughly evenly.
                for slot in 1...remainingHeadBudget {
                    let idx = 1 + (slot * range) / (remainingHeadBudget + 1)
                    if idx < headSourceCount {
                        rendered.append(points[idx])
                    }
                }
            }
        }

        // Keep the tail verbatim (current edge of the recording).
        rendered.append(contentsOf: points.suffix(tailCount))

        return Result(points: rendered, wasCapped: true, originalCount: total)
    }
}
