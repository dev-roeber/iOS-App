import Foundation
import LocationHistoryConsumer

public enum TCXImportError: LocalizedError, Equatable {
    case invalidXML(String)
    case noTrackPoints(String)
    case missingRequiredTrackpointData(String)
    case exportRoundTripFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidXML(fileName):
            return "'\(fileName)' is not valid TCX XML."
        case let .noTrackPoints(fileName):
            return "'\(fileName)' does not contain any TCX track points."
        case let .missingRequiredTrackpointData(fileName):
            return "'\(fileName)' contains TCX track points with missing required position data."
        case let .exportRoundTripFailed(fileName):
            return "'\(fileName)' could not be converted into an app export."
        }
    }
}

/// Parses TCX 2.0 XML files (Garmin Training Center XML) and converts them to `AppExport`.
///
/// Traverses `<TrainingCenterDatabase>` → `<Activity>` → `<Lap>` → `<Track>` → `<Trackpoint>`.
/// Each `<Trackpoint>` with a `<Position>` is converted to a `PathPoint`.
/// Points are grouped into days by their local calendar date (`.autoupdatingCurrent` timezone).
public enum TCXImportParser {

    // MARK: - Public API

    /// Returns `true` if `data` looks like a TCX file by checking the XML root element.
    public static func isTCX(_ data: Data) -> Bool {
        guard let probe = String(data: data.prefix(2048), encoding: .utf8) ?? String(data: data.prefix(2048), encoding: .isoLatin1) else {
            return false
        }
        return probe.contains("<TrainingCenterDatabase")
    }

    /// Parses TCX data and returns an `AppExport`.
    /// Throws `TCXImportError` when the XML is invalid or contains no usable track points.
    public static func parse(_ data: Data, fileName: String) throws -> AppExport {
        let parser = _TCXXMLParser(data: data)
        guard parser.run() else {
            throw TCXImportError.invalidXML(fileName)
        }
        guard !parser.trackPoints.isEmpty else {
            if parser.sawIncompleteTrackPoint {
                throw TCXImportError.missingRequiredTrackpointData(fileName)
            }
            throw TCXImportError.noTrackPoints(fileName)
        }

        let days = buildDays(trackPoints: parser.trackPoints)

        guard !days.isEmpty else {
            throw TCXImportError.noTrackPoints(fileName)
        }

        return try makeExport(days: days, fileName: fileName, sourceFormat: "tcx")
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

    private static func buildDays(trackPoints: [_TCXTrackPoint]) -> [Day] {
        var dayPointsMap: [String: [_TCXTrackPoint]] = [:]
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

        let isoOutput = ISO8601DateFormatter()
        var resultDays: [Day] = []

        for key in orderedDays {
            guard key != "no-timestamp" else { continue }

            let points = dayPointsMap[key] ?? []
            let pathPoints: [PathPoint] = points.map { pt in
                PathPoint(lat: pt.lat, lon: pt.lon, time: pt.time, accuracyM: nil)
            }

            let timestamps = pathPoints.compactMap { $0.time }.compactMap { parseISO($0) }.sorted()
            let startTime = timestamps.first.map { isoOutput.string(from: $0) }
            let endTime = timestamps.last.map { isoOutput.string(from: $0) }

            let path = Path(
                startTime: startTime,
                endTime: endTime,
                activityType: nil,
                distanceM: nil,
                sourceType: "tcx",
                points: pathPoints,
                flatCoordinates: nil
            )

            resultDays.append(Day(date: key, visits: [], activities: [], paths: [path]))
        }

        return resultDays.sorted { $0.date < $1.date }
    }

    private static func makeExport(days: [Day], fileName: String, sourceFormat: String) throws -> AppExport {
        let isoOutput = ISO8601DateFormatter()

        let daysArray: [[String: Any]] = days.map { day in
            let pathsArray: [[String: Any]] = day.paths.map { path in
                let pointsArray: [[String: Any]] = path.points.map { pt in
                    var dict: [String: Any] = ["lat": pt.lat, "lon": pt.lon]
                    if let t = pt.time { dict["time"] = t }
                    return dict
                }
                var pdict: [String: Any] = ["points": pointsArray, "source_type": "tcx"]
                if let s = path.startTime { pdict["start_time"] = s }
                if let e = path.endTime { pdict["end_time"] = e }
                return pdict
            }
            return [
                "date": day.date,
                "visits": [] as [[String: Any]],
                "activities": [] as [[String: Any]],
                "paths": pathsArray
            ]
        }

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

        guard let exportData = try? JSONSerialization.data(withJSONObject: exportDict),
              let export = try? AppExportDecoder.decode(data: exportData) else {
            throw TCXImportError.exportRoundTripFailed(fileName)
        }
        return export
    }
}

// MARK: - Internal XML model types

struct _TCXTrackPoint {
    let lat: Double
    let lon: Double
    let time: String?
}

// MARK: - XMLParser delegate

final class _TCXXMLParser: NSObject, XMLParserDelegate {
    private let data: Data

    var trackPoints: [_TCXTrackPoint] = []
    private(set) var parseError: Bool = false
    private(set) var sawIncompleteTrackPoint = false

    // Parsing state
    private var insideTrackpoint = false
    private var insidePosition = false
    private var insideTime = false
    private var insideLatitude = false
    private var insideLongitude = false

    private var currentLat: Double?
    private var currentLon: Double?
    private var currentTime: String?
    private var currentCharacters: String = ""

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
        currentCharacters = ""

        switch elementName {
        case "Trackpoint":
            insideTrackpoint = true
            currentLat = nil
            currentLon = nil
            currentTime = nil
        case "Position":
            if insideTrackpoint { insidePosition = true }
        case "Time":
            if insideTrackpoint { insideTime = true }
        case "LatitudeDegrees":
            if insidePosition { insideLatitude = true }
        case "LongitudeDegrees":
            if insidePosition { insideLongitude = true }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentCharacters += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "Time":
            if insideTrackpoint && insideTime {
                currentTime = currentCharacters.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            insideTime = false
        case "LatitudeDegrees":
            if insidePosition && insideLatitude {
                currentLat = Double(currentCharacters.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            insideLatitude = false
        case "LongitudeDegrees":
            if insidePosition && insideLongitude {
                currentLon = Double(currentCharacters.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            insideLongitude = false
        case "Position":
            insidePosition = false
        case "Trackpoint":
            if let lat = currentLat, let lon = currentLon {
                trackPoints.append(_TCXTrackPoint(lat: lat, lon: lon, time: currentTime))
            } else if currentLat != nil || currentLon != nil || currentTime != nil {
                sawIncompleteTrackPoint = true
            }
            insideTrackpoint = false
            currentLat = nil
            currentLon = nil
            currentTime = nil
        default:
            break
        }

        currentCharacters = ""
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = true
    }
}
