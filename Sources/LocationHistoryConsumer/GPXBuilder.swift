import Foundation

public struct GPXTrackPoint: Equatable {
    public let latitude: Double
    public let longitude: Double
    public let time: String?

    public init(latitude: Double, longitude: Double, time: String?) {
        self.latitude = latitude
        self.longitude = longitude
        self.time = time
    }
}

public struct GPXTrack: Equatable {
    public let name: String
    public let type: String?
    public let points: [GPXTrackPoint]

    public init(name: String, type: String? = nil, points: [GPXTrackPoint]) {
        self.name = name
        self.type = type
        self.points = points
    }
}

/// Builds GPX 1.1 documents from `Day` arrays.
///
/// Only `Path` entries that carry at least one `PathPoint` are exported as GPX tracks.
/// Activities (start/end coords only) and Visits are omitted in this version;
/// they can be added as `<wpt>` elements in a future iteration.
public enum GPXBuilder {

    // MARK: - Public API

    /// Builds a GPX 1.1 string from the supplied days.
    ///
    /// - Parameter days: One or more `Day` values from the app export.
    ///   Days are output in the order supplied; sort before calling if needed.
    /// - Returns: A well-formed GPX 1.1 XML string (UTF-8).
    public static func build(from days: [Day]) -> String {
        build(from: days, additionalTracks: [])
    }

    public static func build(from days: [Day], additionalTracks: [GPXTrack]) -> String {
        var lines: [String] = []

        lines.append(#"<?xml version="1.0" encoding="UTF-8"?>"#)
        lines.append("""
            <gpx version="1.1" creator="LocationHistory2GPX iOS" \
            xmlns="http://www.topografix.com/GPX/1/1" \
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" \
            xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
            """)

        for day in days {
            for (pathIndex, path) in day.paths.enumerated() {
                let validPoints = path.points.filter { _ in true } // all points included
                guard !validPoints.isEmpty else { continue }

                let trackName = trackTitle(date: day.date, activityType: path.activityType, index: pathIndex)
                appendTrack(
                    GPXTrack(
                        name: trackName,
                        type: path.activityType,
                        points: validPoints.map {
                            GPXTrackPoint(latitude: $0.lat, longitude: $0.lon, time: $0.time)
                        }
                    ),
                    to: &lines
                )
            }
        }

        for track in additionalTracks where !track.points.isEmpty {
            appendTrack(track, to: &lines)
        }

        lines.append("</gpx>")
        return lines.joined(separator: "\n")
    }

    private static func appendTrack(_ track: GPXTrack, to lines: inout [String]) {
        guard !track.points.isEmpty else { return }

        lines.append("  <trk>")
        lines.append("    <name>\(xmlEscape(track.name))</name>")
        if let type = track.type, !type.isEmpty {
            lines.append("    <type>\(xmlEscape(type))</type>")
        }
        lines.append("    <trkseg>")
        for point in track.points {
            let latStr = String(format: "%.8f", point.latitude)
            let lonStr = String(format: "%.8f", point.longitude)
            if let time = point.time {
                lines.append("""
                        <trkpt lat="\(latStr)" lon="\(lonStr)">
                          <time>\(xmlEscape(time))</time>
                        </trkpt>
                    """)
            } else {
                lines.append(#"      <trkpt lat="\#(latStr)" lon="\#(lonStr)"/>"#)
            }
        }
        lines.append("    </trkseg>")
        lines.append("  </trk>")
    }

    /// Suggests a GPX filename for the given set of export dates.
    ///
    /// - Parameter dates: ISO-8601 date strings ("yyyy-MM-dd"). Need not be sorted.
    /// - Returns: A filename such as `lh2gpx-2024-01-15.gpx`,
    ///   `lh2gpx-2024-01-10_to_2024-01-20.gpx`, or `lh2gpx-export.gpx`.
    public static func suggestedFilename(for dates: [String]) -> String {
        let sorted = dates.sorted()
        switch sorted.count {
        case 0:
            return "lh2gpx-export.gpx"
        case 1:
            return "lh2gpx-\(sorted[0]).gpx"
        default:
            guard let first = sorted.first, let last = sorted.last else {
                return "lh2gpx-export.gpx"
            }
            return "lh2gpx-\(first)_to_\(last).gpx"
        }
    }

    // MARK: - Private Helpers

    private static func trackTitle(date: String, activityType: String?, index: Int) -> String {
        let typePart = activityType.map { " – \($0.capitalized)" } ?? ""
        let indexSuffix = index > 0 ? " (\(index + 1))" : ""
        return "\(date)\(typePart)\(indexSuffix)"
    }

    private static func xmlEscape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
