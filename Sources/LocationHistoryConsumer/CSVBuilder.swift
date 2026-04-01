import Foundation

/// Builds CSV exports from location history days.
///
/// Each row represents one visit, activity, or route for a given day.
/// The CSV is UTF-8 encoded with a standard header row.
/// Dates use ISO 8601; empty fields use "" (never "N/A" or synthetic values).
public enum CSVBuilder {

    // MARK: - Header

    public static let header = [
        "date",
        "dayIdentifier",
        "entryType",
        "startTime",
        "endTime",
        "visitName",
        "visitAddress",
        "activityType",
        "routeIndex",
        "routeDistance",
        "distanceM",
        "startLat",
        "startLon",
        "endLat",
        "endLon",
        "pointCount",
    ]

    // MARK: - Build

    /// Builds a complete CSV string from the provided days.
    ///
    /// - Parameter days: Export days (from `ExportSelectionContent.exportDays` or similar).
    /// - Returns: UTF-8 CSV string including header and all rows.
    public static func build(from days: [Day]) -> String {
        var lines: [String] = [header.map(csvEscape).joined(separator: ",")]

        for day in days {
            for visit in day.visits {
                lines.append(visitRow(day: day, visit: visit))
            }
            for activity in day.activities {
                lines.append(activityRow(day: day, activity: activity))
            }
            for (index, path) in day.paths.enumerated() {
                lines.append(routeRow(day: day, path: path, routeIndex: index))
            }
            // If the day has no content, emit a placeholder row so the day is represented
            if day.visits.isEmpty && day.activities.isEmpty && day.paths.isEmpty {
                lines.append(emptyDayRow(day: day))
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Row builders

    private static func visitRow(day: Day, visit: Visit) -> String {
        let cols: [String?] = [
            day.date,
            day.date,
            "visit",
            visit.startTime,
            visit.endTime,
            visit.semanticType,
            nil, // visitAddress — not in contract
            nil, // activityType
            nil, // routeIndex
            nil, // routeDistance
            nil, // distanceM
            optionalDouble(visit.lat),
            optionalDouble(visit.lon),
            nil, // endLat
            nil, // endLon
            nil, // pointCount
        ]
        return cols.map { csvEscape($0 ?? "") }.joined(separator: ",")
    }

    private static func activityRow(day: Day, activity: Activity) -> String {
        let cols: [String?] = [
            day.date,
            day.date,
            "activity",
            activity.startTime,
            activity.endTime,
            nil, // visitName
            nil, // visitAddress
            activity.activityType,
            nil, // routeIndex
            nil, // routeDistance
            activity.distanceM.map { String(format: "%.2f", $0) },
            optionalDouble(activity.startLat),
            optionalDouble(activity.startLon),
            optionalDouble(activity.endLat),
            optionalDouble(activity.endLon),
            nil, // pointCount
        ]
        return cols.map { csvEscape($0 ?? "") }.joined(separator: ",")
    }

    private static func routeRow(day: Day, path: Path, routeIndex: Int) -> String {
        let firstPoint = path.points.first
        let lastPoint = path.points.last
        let cols: [String?] = [
            day.date,
            day.date,
            "route",
            path.startTime,
            path.endTime,
            nil, // visitName
            nil, // visitAddress
            path.activityType,
            String(routeIndex),
            path.distanceM.map { String(format: "%.2f", $0) },
            path.distanceM.map { String(format: "%.2f", $0) },
            optionalDouble(firstPoint?.lat),
            optionalDouble(firstPoint?.lon),
            optionalDouble(lastPoint?.lat),
            optionalDouble(lastPoint?.lon),
            String(path.points.count),
        ]
        return cols.map { csvEscape($0 ?? "") }.joined(separator: ",")
    }

    private static func emptyDayRow(day: Day) -> String {
        let cols: [String?] = [
            day.date,
            day.date,
            "empty",
            nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
        ]
        return cols.map { csvEscape($0 ?? "") }.joined(separator: ",")
    }

    // MARK: - Helpers

    private static func optionalDouble(_ value: Double?) -> String? {
        guard let value else { return nil }
        return String(format: "%.6f", value)
    }

    /// RFC 4180 CSV escaping: wrap in double-quotes if the value contains
    /// commas, double-quotes, or newlines; escape embedded double-quotes by doubling them.
    public static func csvEscape(_ value: String) -> String {
        let needsQuoting = value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r")
        guard needsQuoting else { return value }
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
