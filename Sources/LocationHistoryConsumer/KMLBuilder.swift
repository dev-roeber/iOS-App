import Foundation

/// Builds simple KML documents from `Day` arrays.
///
/// Each exportable path becomes one `<Placemark>` with a `<LineString>`.
public enum KMLBuilder {
    public static func build(from days: [Day]) -> String {
        var lines: [String] = []

        lines.append(#"<?xml version="1.0" encoding="UTF-8"?>"#)
        lines.append(#"<kml xmlns="http://www.opengis.net/kml/2.2">"#)
        lines.append("  <Document>")
        lines.append("    <name>LocationHistory2GPX Export</name>")

        for day in days {
            for (pathIndex, path) in day.paths.enumerated() {
                let validPoints = path.points.filter { _ in true }
                guard !validPoints.isEmpty else { continue }

                let trackName = trackTitle(date: day.date, activityType: path.activityType, index: pathIndex)
                let coordinates = validPoints
                    .map { "\(coordinateString($0.lon)),\(coordinateString($0.lat))" }
                    .joined(separator: " ")

                lines.append("    <Placemark>")
                lines.append("      <name>\(xmlEscape(trackName))</name>")
                if let type = path.activityType, !type.isEmpty {
                    lines.append("      <description>\(xmlEscape(type))</description>")
                }
                lines.append("      <LineString>")
                lines.append("        <tessellate>1</tessellate>")
                lines.append("        <coordinates>\(coordinates)</coordinates>")
                lines.append("      </LineString>")
                lines.append("    </Placemark>")
            }
        }

        lines.append("  </Document>")
        lines.append("</kml>")
        return lines.joined(separator: "\n")
    }

    private static func trackTitle(date: String, activityType: String?, index: Int) -> String {
        let typePart = activityType.map { " – \($0.capitalized)" } ?? ""
        let indexSuffix = index > 0 ? " (\(index + 1))" : ""
        return "\(date)\(typePart)\(indexSuffix)"
    }

    private static func coordinateString(_ value: Double) -> String {
        String(format: "%.8f", value)
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
