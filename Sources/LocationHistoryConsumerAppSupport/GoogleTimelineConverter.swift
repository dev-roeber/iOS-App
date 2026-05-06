import Foundation
import LocationHistoryConsumer

/// Detects and converts Google Location History Timeline JSON (array format)
/// to the LH2GPX AppExport JSON schema, which can then be decoded by AppExportDecoder.
///
/// Supported Google format: the modern Timeline export — an array of objects
/// with "visit", "activity", or "timelinePath" keys and ISO8601 "startTime"/"endTime".
enum GoogleTimelineConverter {

    // MARK: - Public API

    /// Returns true if the data looks like a Google Timeline export — a JSON
    /// top-level array. Cheap byte-sniffer: skips whitespace + UTF-8 BOM and
    /// checks whether the first non-whitespace byte is `[`.
    ///
    /// We deliberately do NOT call `JSONSerialization.jsonObject(with:)` here.
    /// On a 46 MB Google Timeline JSON the full parse allocates ~150–200 MB
    /// of transient Foundation objects just to answer "is this an array?",
    /// which on iOS pushes the wrapper into Jetsam territory before any
    /// actual import work happens.
    static func isGoogleTimeline(_ data: Data) -> Bool {
        firstStructuralByte(of: data) == UInt8(ascii: "[")
    }

    /// Returns true if the data starts with a JSON object (`{`). Used to
    /// distinguish LH2GPX `app_export.json` (object) from Google Timeline
    /// (array) without paying the cost of a full parse.
    static func isJSONObject(_ data: Data) -> Bool {
        firstStructuralByte(of: data) == UInt8(ascii: "{")
    }

    /// Returns the first byte of `data` that is not RFC-8259 JSON whitespace
    /// (space, tab, LF, CR) or a leading UTF-8 BOM. Looks at the first 1 KB
    /// only — sufficient to identify the top-level JSON kind.
    private static func firstStructuralByte(of data: Data) -> UInt8? {
        let head = data.prefix(1024)
        let bom: [UInt8] = [0xEF, 0xBB, 0xBF]
        let hasBOM = head.count >= 3 && Array(head.prefix(3)) == bom
        let scanStart = hasBOM ? head.index(head.startIndex, offsetBy: 3) : head.startIndex
        for index in scanStart..<head.endIndex {
            let byte = head[index]
            if byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D { continue }
            return byte
        }
        return nil
    }

    /// Converts Google Timeline JSON (already in memory) to AppExport.
    ///
    /// Even when the bytes are already on the heap (e.g. ZIP-extracted), we
    /// route through the element-streaming reader instead of doing a single
    /// `JSONSerialization.jsonObject(with: fullData)`. The streaming variant
    /// peaks at one element worth of Foundation objects (~few KB) instead of
    /// the full ~150–200 MB transient tree a 46 MB array produces.
    static func convert(data: Data) throws -> AppExport {
        var dayMap: DayMap = [:]
        var orderedDayKeys: [String] = []
        var sawValidEntry = false

        try GoogleTimelineStreamReader.forEachObjectElement(in: data) { raw in
            guard let entry = raw as? [String: Any] else { return }
            ingestEntry(entry, dayMap: &dayMap, orderedDayKeys: &orderedDayKeys, sawValidEntry: &sawValidEntry)
        }

        guard sawValidEntry else { throw ConversionError.notGoogleTimeline }
        return try finalizeAppExport(dayMap: dayMap, orderedDayKeys: orderedDayKeys)
    }

    /// Streams a Google Timeline JSON file from disk and converts it to
    /// AppExport. Reads the file in 64 KB chunks via `FileHandle`; per-element
    /// memory peaks at one object (~few KB). Suitable for large user imports
    /// (≥40 MB) where a full in-memory parse would Jetsam the wrapper.
    static func convertStreaming(contentsOf url: URL) throws -> AppExport {
        var dayMap: DayMap = [:]
        var orderedDayKeys: [String] = []
        var sawValidEntry = false

        try GoogleTimelineStreamReader.forEachObjectElement(contentsOf: url) { raw in
            guard let entry = raw as? [String: Any] else { return }
            ingestEntry(entry, dayMap: &dayMap, orderedDayKeys: &orderedDayKeys, sawValidEntry: &sawValidEntry)
        }

        guard sawValidEntry else { throw ConversionError.notGoogleTimeline }
        return try finalizeAppExport(dayMap: dayMap, orderedDayKeys: orderedDayKeys)
    }

    typealias DayMap = [String: (visits: [[String: Any]], activities: [[String: Any]], paths: [[String: Any]])]

    private static func finalizeAppExport(dayMap: DayMap, orderedDayKeys: [String]) throws -> AppExport {
        let exportDict = buildExportDict(dayMap: dayMap, orderedDayKeys: orderedDayKeys)
        let exportData = try JSONSerialization.data(withJSONObject: exportDict)
        return try AppExportDecoder.decode(data: exportData)
    }

    enum ConversionError: Error {
        case notGoogleTimeline
    }

    // MARK: - Date Parsing

    private static let isoWithMs: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoWithoutMs: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let isoOutput = ISO8601DateFormatter()

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private static func parseISO(_ str: String) -> Date? {
        isoWithMs.date(from: str) ?? isoWithoutMs.date(from: str)
    }

    // MARK: - Geo Parsing

    /// Parses "geo:lat,lon" or "geo:lat,lon,alt" strings.
    private static func parseGeo(_ geo: String?) -> (lat: Double, lon: Double)? {
        guard let geo, geo.hasPrefix("geo:") else { return nil }
        let parts = geo.dropFirst(4).split(separator: ",")
        guard parts.count >= 2,
              let lat = Double(parts[0].trimmingCharacters(in: .whitespaces)),
              let lon = Double(parts[1].trimmingCharacters(in: .whitespaces)) else { return nil }
        return (lat, lon)
    }

    // MARK: - Export Dict Builder

    /// Per-entry ingest used by both the in-memory (`convert(data:)`) and
    /// disk-streaming (`convertStreaming(contentsOf:)`) paths. Mutates the
    /// day map in place so we never hold the entire entry list.
    private static func ingestEntry(
        _ entry: [String: Any],
        dayMap: inout DayMap,
        orderedDayKeys: inout [String],
        sawValidEntry: inout Bool
    ) {
        guard let startTimeStr = entry["startTime"] as? String,
              let startDate = parseISO(startTimeStr) else { return }
        sawValidEntry = true

        let dayKey = dateFmt.string(from: startDate)
        let endTimeStr = entry["endTime"] as? String

        if dayMap[dayKey] == nil {
            dayMap[dayKey] = (visits: [], activities: [], paths: [])
            orderedDayKeys.append(dayKey)
        }

        if let visitData = entry["visit"] as? [String: Any] {
            if let v = convertVisit(visitData, startTime: startTimeStr, endTime: endTimeStr) {
                dayMap[dayKey]!.visits.append(v)
            }
        } else if let activityData = entry["activity"] as? [String: Any] {
            if let a = convertActivity(activityData, startTime: startTimeStr, endTime: endTimeStr) {
                dayMap[dayKey]!.activities.append(a)
            }
        } else if let pathData = entry["timelinePath"] as? [[String: Any]] {
            if let p = convertPath(pathData, startTime: startTimeStr, endTime: endTimeStr, startDate: startDate) {
                dayMap[dayKey]!.paths.append(p)
            }
        }
    }

    private static func buildExportDict(dayMap: DayMap, orderedDayKeys: [String]) -> [String: Any] {
        let days: [[String: Any]] = orderedDayKeys.sorted().map { key in
            let b = dayMap[key]!
            return ["date": key, "visits": b.visits, "activities": b.activities, "paths": b.paths]
        }

        return [
            "schema_version": "1.0",
            "meta": [
                "exported_at": isoOutput.string(from: Date()),
                "tool_version": "ios-app-converter/1.0",
                "source": ["input_format": "google_timeline"] as [String: Any],
                "output": [:] as [String: Any],
                "config": ["input_format": "google_timeline"] as [String: Any],
                "filters": [:] as [String: Any]
            ] as [String: Any],
            "data": ["days": days]
            // "stats" omitted → decoded as nil
        ]
    }

    // MARK: - Entry Converters

    private static func convertVisit(
        _ visitData: [String: Any],
        startTime: String,
        endTime: String?
    ) -> [String: Any]? {
        let candidate = visitData["topCandidate"] as? [String: Any]
        var dict: [String: Any] = ["start_time": startTime, "source_type": "google_timeline"]
        if let et = endTime { dict["end_time"] = et }
        if let (lat, lon) = parseGeo(candidate?["placeLocation"] as? String) {
            dict["lat"] = lat
            dict["lon"] = lon
        }
        if let st = candidate?["semanticType"] as? String { dict["semantic_type"] = st }
        if let pid = candidate?["placeID"] as? String { dict["place_id"] = pid }
        return dict
    }

    private static func convertActivity(
        _ activityData: [String: Any],
        startTime: String,
        endTime: String?
    ) -> [String: Any]? {
        let candidate = activityData["topCandidate"] as? [String: Any]
        var dict: [String: Any] = ["start_time": startTime, "source_type": "google_timeline"]
        if let et = endTime { dict["end_time"] = et }
        if let at = candidate?["type"] as? String { dict["activity_type"] = at }
        // Google exports distanceMeters as either a Number or a String — handle both.
        if let d = parseDouble(activityData["distanceMeters"]) { dict["distance_m"] = d }
        if let (lat, lon) = parseGeo(activityData["start"] as? String) {
            dict["start_lat"] = lat
            dict["start_lon"] = lon
        }
        if let (lat, lon) = parseGeo(activityData["end"] as? String) {
            dict["end_lat"] = lat
            dict["end_lon"] = lon
        }
        return dict
    }

    /// Handles numeric fields that Google may export as either a Number or a String.
    private static func parseDouble(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let s = value as? String { return Double(s) }
        return nil
    }

    private static func convertPath(
        _ pathData: [[String: Any]],
        startTime: String,
        endTime: String?,
        startDate: Date
    ) -> [String: Any]? {
        let points: [[String: Any]] = pathData.compactMap { pt in
            guard let pointGeo = pt["point"] as? String,
                  let (lat, lon) = parseGeo(pointGeo) else { return nil }
            var pointDict: [String: Any] = ["lat": lat, "lon": lon]
            if let offsetStr = pt["durationMinutesOffsetFromStartTime"] as? String,
               let offset = Double(offsetStr) {
                let pointDate = startDate.addingTimeInterval(offset * 60)
                pointDict["time"] = isoOutput.string(from: pointDate)
            }
            return pointDict
        }
        guard !points.isEmpty else { return nil }
        var dict: [String: Any] = ["start_time": startTime, "source_type": "google_timeline", "points": points]
        if let et = endTime { dict["end_time"] = et }
        return dict
    }
}
