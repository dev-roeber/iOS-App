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
        let sanitizedPoints = deduplicatedPoints(path.points)
        guard sanitizedPoints.count >= 2 else { return nil }
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
