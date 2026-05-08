import Foundation

public enum ExportRouteSanitizer {
    public static func exportablePathCount(in day: Day) -> Int {
        day.paths.compactMap(sanitizedPath).count
    }

    public static func sanitizedDay(_ day: Day) -> Day? {
        let sanitizedPaths = day.paths.compactMap(sanitizedPath)
        guard !sanitizedPaths.isEmpty else { return nil }
        return Day(
            date: day.date,
            visits: day.visits,
            activities: day.activities,
            paths: sanitizedPaths
        )
    }

    public static func sanitizedPath(_ path: Path) -> Path? {
        // Two geometry shapes are now allowed:
        // 1. points-shaped paths (legacy) → dedupe consecutive duplicates.
        // 2. flat-shaped paths (Google Timeline post 2026-05-08 refactor)
        //    → require an even-count, ≥ 4-element `flatCoordinates`. Without
        //    this branch every Google-Timeline-imported route would be
        //    discarded by `exportablePathCount`, breaking GPX/KML/GeoJSON/CSV
        //    export of Google-Timeline imports.
        let sanitizedPoints = deduplicatedPoints(path.points)
        if sanitizedPoints.count >= 2 {
            return Path(
                startTime: path.startTime,
                endTime: path.endTime,
                activityType: path.activityType,
                distanceM: path.distanceM,
                sourceType: path.sourceType,
                points: sanitizedPoints,
                flatCoordinates: path.flatCoordinates
            )
        }
        if let flat = path.flatCoordinates,
           flat.count >= 4,
           flat.count.isMultiple(of: 2) {
            return Path(
                startTime: path.startTime,
                endTime: path.endTime,
                activityType: path.activityType,
                distanceM: path.distanceM,
                sourceType: path.sourceType,
                points: [],
                flatCoordinates: flat
            )
        }
        return nil
    }

    public static func deduplicatedPoints(_ points: [PathPoint]) -> [PathPoint] {
        var deduplicated: [PathPoint] = []
        deduplicated.reserveCapacity(points.count)

        for point in points {
            guard let previous = deduplicated.last else {
                deduplicated.append(point)
                continue
            }

            if pointsEqual(previous, point) {
                continue
            }

            deduplicated.append(point)
        }

        return deduplicated
    }

    private static func pointsEqual(_ lhs: PathPoint, _ rhs: PathPoint) -> Bool {
        lhs.lat == rhs.lat &&
        lhs.lon == rhs.lon &&
        lhs.time == rhs.time
    }
}
