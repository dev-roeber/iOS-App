import Foundation

/// Builds simple KML documents from `Day` arrays.
///
public enum KMLBuilder {
    public static func build(from days: [Day], mode: ExportMode = .tracks) -> String {
        // Reserve a rough upper bound for the `lines` accumulator so multi-day
        // exports with many paths don't reallocate the backing buffer. Each
        // track placemark produces ~7 lines and each waypoint ~7 lines; add a
        // 16-line fixed-header allowance.
        var rowEstimate = 16
        for day in days {
            if mode.includesTracks { rowEstimate += day.paths.count * 7 }
            if mode.includesWaypoints { rowEstimate += day.visits.count * 7 }
        }
        var lines: [String] = []
        lines.reserveCapacity(rowEstimate)

        lines.append(#"<?xml version="1.0" encoding="UTF-8"?>"#)
        lines.append(#"<kml xmlns="http://www.opengis.net/kml/2.2">"#)
        lines.append("  <Document>")
        lines.append("    <name>LocationHistory2GPX Export</name>")

        if mode.includesWaypoints {
            for waypoint in ExportWaypointExtractor.waypoints(from: days) {
                lines.append("    <Placemark>")
                lines.append("      <name>\(ExportUtils.xmlEscape(waypoint.name))</name>")
                if let detail = waypoint.detail, !detail.isEmpty {
                    lines.append("      <description>\(ExportUtils.xmlEscape(detail))</description>")
                } else {
                    lines.append("      <description>\(ExportUtils.xmlEscape(waypoint.category))</description>")
                }
                lines.append("      <Point>")
                lines.append("        <coordinates>\(coordinateString(waypoint.longitude)),\(coordinateString(waypoint.latitude))</coordinates>")
                lines.append("      </Point>")
                lines.append("    </Placemark>")
            }
        }

        if mode.includesTracks {
            for day in days {
                for (pathIndex, path) in day.paths.enumerated() {
                    // Build the lon,lat string from whichever geometry shape
                    // is populated. Google-Timeline-imported paths (post
                    // 2026-05-08 refactor) carry geometry in `flatCoordinates`
                    // and have an empty `points` array.
                    let coordinates: String
                    if !path.points.isEmpty {
                        // Direct String-append loop avoids the intermediate
                        // `[String]` allocation of `map { … }.joined(...)`.
                        // Output is byte-identical: space-separated
                        // `lon,lat` triples in the same order as the source.
                        var built = ""
                        // Heuristic: ~26 chars per coordinate pair plus the
                        // separating space.
                        built.reserveCapacity(path.points.count * 27)
                        var isFirst = true
                        for point in path.points {
                            if isFirst {
                                isFirst = false
                            } else {
                                built.append(" ")
                            }
                            built.append(coordinateString(point.lon))
                            built.append(",")
                            built.append(coordinateString(point.lat))
                        }
                        coordinates = built
                    } else if let flat = path.flatCoordinates,
                              flat.count >= 2,
                              flat.count.isMultiple(of: 2) {
                        var pieces: [String] = []
                        pieces.reserveCapacity(flat.count / 2)
                        var i = 0
                        while i + 1 < flat.count {
                            pieces.append("\(coordinateString(flat[i + 1])),\(coordinateString(flat[i]))")
                            i += 2
                        }
                        coordinates = pieces.joined(separator: " ")
                    } else {
                        continue
                    }
                    guard !coordinates.isEmpty else { continue }

                    let trackName = ExportUtils.trackTitle(date: day.date, activityType: path.activityType, index: pathIndex)

                    lines.append("    <Placemark>")
                    lines.append("      <name>\(ExportUtils.xmlEscape(trackName))</name>")
                    if let type = path.activityType, !type.isEmpty {
                        lines.append("      <description>\(ExportUtils.xmlEscape(type))</description>")
                    }
                    lines.append("      <LineString>")
                    lines.append("        <tessellate>1</tessellate>")
                    lines.append("        <coordinates>\(coordinates)</coordinates>")
                    lines.append("      </LineString>")
                    lines.append("    </Placemark>")
                }
            }
        }

        lines.append("  </Document>")
        lines.append("</kml>")
        return lines.joined(separator: "\n")
    }

    private static func coordinateString(_ value: Double) -> String {
        String(format: "%.8f", value)
    }
}
