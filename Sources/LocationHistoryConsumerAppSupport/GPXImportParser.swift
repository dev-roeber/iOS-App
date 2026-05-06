import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import LocationHistoryConsumer

/// Parses GPX 1.1 XML files and converts them to `AppExport`.
///
/// Supports `<trk>` / `<trkseg>` / `<trkpt>` track points and `<wpt>` waypoints.
/// Points are grouped into days by their local calendar date (`.autoupdatingCurrent` timezone).
public enum GPXImportParser {

    // MARK: - Public API

    /// Returns `true` if `data` looks like a GPX file by checking the XML root element.
    public static func isGPX(_ data: Data) -> Bool {
        guard let probe = String(data: data.prefix(2048), encoding: .utf8) ?? String(data: data.prefix(2048), encoding: .isoLatin1) else {
            return false
        }
        return probe.contains("<gpx")
    }

    /// Parses GPX data and returns an `AppExport`.
    /// Throws `AppContentLoaderError.decodeFailed` when the XML is invalid or contains no usable track points.
    public static func parse(_ data: Data, fileName: String) throws -> AppExport {
        let xmlParser = _GPXXMLParser(data: data)
        guard xmlParser.run() else {
            throw AppContentLoaderError.decodeFailed(fileName)
        }
        guard !xmlParser.trackPoints.isEmpty || !xmlParser.waypointVisits.isEmpty else {
            throw AppContentLoaderError.decodeFailed(fileName)
        }

        let daysDict = buildDaysDict(trackPoints: xmlParser.trackPoints, waypointVisits: xmlParser.waypointVisits)
        guard !daysDict.isEmpty else {
            throw AppContentLoaderError.decodeFailed(fileName)
        }

        return try makeExport(trackPoints: xmlParser.trackPoints, waypointVisits: xmlParser.waypointVisits, fileName: fileName, sourceFormat: "gpx")
    }

    // MARK: - Day grouping

    private static let localDateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .autoupdatingCurrent
        return f
    }()

    private static let isoParser: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoParserNoMs: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parseISO(_ str: String) -> Date? {
        isoParser.date(from: str) ?? isoParserNoMs.date(from: str)
    }

    private static func buildDaysDict(trackPoints: [_GPXTrackPoint], waypointVisits: [_GPXWaypoint]) -> [[String: Any]] {
        // Group track points by local date
        var dayPointsMap: [String: [_GPXTrackPoint]] = [:]
        var orderedDays: [String] = []

        for pt in trackPoints {
            let dayKey: String
            if let ts = pt.time, let date = parseISO(ts) {
                dayKey = localDateFmt.string(from: date)
            } else {
                dayKey = "no-timestamp"
            }
            if dayPointsMap[dayKey] == nil {
                dayPointsMap[dayKey] = []
                orderedDays.append(dayKey)
            }
            dayPointsMap[dayKey]!.append(pt)
        }

        // Group waypoints by local date
        var dayWaypointsMap: [String: [_GPXWaypoint]] = [:]
        for wpt in waypointVisits {
            let dayKey: String
            if let ts = wpt.time, let date = parseISO(ts) {
                dayKey = localDateFmt.string(from: date)
            } else {
                dayKey = "no-timestamp"
            }
            if dayWaypointsMap[dayKey] == nil { dayWaypointsMap[dayKey] = [] }
            if dayPointsMap[dayKey] == nil {
                dayPointsMap[dayKey] = []
                orderedDays.append(dayKey)
            }
            dayWaypointsMap[dayKey]!.append(wpt)
        }

        let isoOutput = ISO8601DateFormatter()
        var resultDays: [[String: Any]] = []

        for key in orderedDays {
            guard key != "no-timestamp" else { continue }

            let points = dayPointsMap[key] ?? []
            let waypoints = dayWaypointsMap[key] ?? []

            let pathPointDicts: [[String: Any]] = points.compactMap { pt in
                var dict: [String: Any] = ["lat": pt.lat, "lon": pt.lon]
                if let t = pt.time { dict["time"] = t }
                return dict
            }

            let pathsArray: [[String: Any]]
            if !pathPointDicts.isEmpty {
                let timestamps = points.compactMap { $0.time }.compactMap { parseISO($0) }.sorted()
                var pdict: [String: Any] = ["points": pathPointDicts, "source_type": "gpx"]
                if let first = timestamps.first { pdict["start_time"] = isoOutput.string(from: first) }
                if let last = timestamps.last { pdict["end_time"] = isoOutput.string(from: last) }
                pathsArray = [pdict]
            } else {
                pathsArray = []
            }

            let visitsArray: [[String: Any]] = waypoints.map { wpt in
                var vdict: [String: Any] = ["source_type": "gpx", "lat": wpt.lat, "lon": wpt.lon]
                if let name = wpt.name { vdict["semantic_type"] = name }
                if let t = wpt.time { vdict["start_time"] = t }
                return vdict
            }

            resultDays.append([
                "date": key,
                "visits": visitsArray,
                "activities": [] as [[String: Any]],
                "paths": pathsArray
            ])
        }

        return resultDays.sorted { lhs, rhs in
            // `date` is always written as a String by `buildDaysDict`. Defensive
            // optional cast keeps a malformed entry from crashing the import —
            // it sorts to the front of the list and would surface during decode
            // rather than via EXC_BAD_INSTRUCTION.
            let lhsDate = (lhs["date"] as? String) ?? ""
            let rhsDate = (rhs["date"] as? String) ?? ""
            return lhsDate < rhsDate
        }
    }

    private static func makeExport(
        trackPoints: [_GPXTrackPoint],
        waypointVisits: [_GPXWaypoint],
        fileName: String,
        sourceFormat: String
    ) throws -> AppExport {
        let isoOutput = ISO8601DateFormatter()
        let daysArray = buildDaysDict(trackPoints: trackPoints, waypointVisits: waypointVisits)

        let exportDict: [String: Any] = [
            "schema_version": "1.0",
            "meta": [
                "exported_at": isoOutput.string(from: Date()),
                "tool_version": "ios-app-importer/1.0",
                "source": ["input_format": sourceFormat] as [String: Any],
                "output": [:] as [String: Any],
                "config": ["input_format": sourceFormat] as [String: Any],
                "filters": [:] as [String: Any]
            ] as [String: Any],
            "data": ["days": daysArray]
        ]

        // Roundtrip via JSONSerialization + AppExportDecoder. Failures here
        // mean the GPX produced a structurally invalid export dict (e.g.
        // pathological coordinates, NaN). Surface that as a regular import
        // error instead of crashing the app via fatalError.
        do {
            let exportData = try JSONSerialization.data(withJSONObject: exportDict)
            return try AppExportDecoder.decode(data: exportData)
        } catch {
            throw AppContentLoaderError.decodeFailed(fileName)
        }
    }
}

// MARK: - Internal XML model types

struct _GPXTrackPoint {
    let lat: Double
    let lon: Double
    let time: String?
}

struct _GPXWaypoint {
    let lat: Double
    let lon: Double
    let time: String?
    let name: String?
}

// MARK: - XMLParser delegate

final class _GPXXMLParser: NSObject, XMLParserDelegate {
    private let data: Data

    var trackPoints: [_GPXTrackPoint] = []
    var waypointVisits: [_GPXWaypoint] = []
    private(set) var parseError: Bool = false

    // Parsing state
    private var currentElementStack: [String] = []
    private var currentLat: Double?
    private var currentLon: Double?
    private var currentTime: String?
    private var currentName: String?
    private var currentCharacters: String = ""
    private var insideTrkpt = false
    private var insideWpt = false
    private var insideName = false
    private var insideTime = false

    init(data: Data) {
        self.data = data
    }

    func run() -> Bool {
        let parser = XMLParser(data: data)
        parser.delegate = self
        return parser.parse()
    }

    // MARK: XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElementStack.append(elementName)
        currentCharacters = ""

        switch elementName {
        case "trkpt":
            insideTrkpt = true
            currentLat = attributeDict["lat"].flatMap(Double.init)
            currentLon = attributeDict["lon"].flatMap(Double.init)
            currentTime = nil
        case "wpt":
            insideWpt = true
            currentLat = attributeDict["lat"].flatMap(Double.init)
            currentLon = attributeDict["lon"].flatMap(Double.init)
            currentTime = nil
            currentName = nil
        case "time":
            insideTime = true
        case "name":
            if insideWpt { insideName = true }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentCharacters += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        currentElementStack.removeLast()

        switch elementName {
        case "time":
            if insideTrkpt || insideWpt {
                currentTime = currentCharacters.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            insideTime = false
        case "name":
            if insideWpt && insideName {
                currentName = currentCharacters.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            insideName = false
        case "trkpt":
            if let lat = currentLat, let lon = currentLon {
                trackPoints.append(_GPXTrackPoint(lat: lat, lon: lon, time: currentTime))
            }
            insideTrkpt = false
            currentLat = nil
            currentLon = nil
            currentTime = nil
        case "wpt":
            if let lat = currentLat, let lon = currentLon {
                waypointVisits.append(_GPXWaypoint(lat: lat, lon: lon, time: currentTime, name: currentName))
            }
            insideWpt = false
            currentLat = nil
            currentLon = nil
            currentTime = nil
            currentName = nil
        default:
            break
        }

        currentCharacters = ""
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = true
    }
}
