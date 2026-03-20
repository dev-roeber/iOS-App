import Foundation

/// Builds simple KML documents from `Day` arrays.
///
public enum KMLBuilder {
    public static func build(from days: [Day], mode: ExportMode = .tracks) -> String {
        var lines: [String] = []

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
                    let validPoints = path.points
                    guard !validPoints.isEmpty else { continue }

                    let trackName = ExportUtils.trackTitle(date: day.date, activityType: path.activityType, index: pathIndex)
                    let coordinates = validPoints
                        .map { "\(coordinateString($0.lon)),\(coordinateString($0.lat))" }
                        .joined(separator: " ")

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
