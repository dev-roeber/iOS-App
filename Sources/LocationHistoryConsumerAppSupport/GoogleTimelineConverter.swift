import Foundation
import LocationHistoryConsumer

/// Detects and converts Google Location History Timeline JSON (array format)
/// to the LH2GPX `AppExport` model.
///
/// Supported Google format: the modern Timeline export — an array of objects
/// with "visit", "activity", or "timelinePath" keys and ISO8601 "startTime"/"endTime".
///
/// Both entry points (`convert(data:)` and `convertStreaming(contentsOf:)`)
/// route through `GoogleTimelineStreamReader` and build `AppExport`'s
/// `Day`/`Visit`/`Activity`/`Path` model objects directly — no intermediate
/// `[String: Any]` export tree, no `JSONSerialization.data → AppExportDecoder.decode`
/// roundtrip on the output side. That roundtrip used to dominate import time
/// for 50k-element files (one full Foundation tree alloc + JSON encode + JSON
/// parse + Codable decode pass on tens of MB).
enum GoogleTimelineConverter {

    // MARK: - Public API

    /// Returns true if the data looks like a Google Timeline export — a JSON
    /// top-level array. Cheap byte-sniffer: skips whitespace + UTF-8 BOM and
    /// checks whether the first non-whitespace byte is `[`.
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

    /// Converts Google Timeline JSON (already in memory) to `AppExport`.
    static func convert(data: Data) throws -> AppExport {
        var builder = ExportBuilder()
        try GoogleTimelineStreamReader.forEachObjectElement(in: data) { raw in
            guard let entry = raw as? [String: Any] else { return }
            builder.ingest(entry)
        }
        return try builder.finalize()
    }

    /// Streams a Google Timeline JSON file from disk and converts it to
    /// `AppExport`. Reads the file in 256 KB chunks via `FileHandle`;
    /// per-element memory peaks at one object (~few KB).
    static func convertStreaming(contentsOf url: URL) throws -> AppExport {
        var builder = ExportBuilder()
        try GoogleTimelineStreamReader.forEachObjectElement(contentsOf: url) { raw in
            guard let entry = raw as? [String: Any] else { return }
            builder.ingest(entry)
        }
        return try builder.finalize()
    }

    enum ConversionError: Error {
        case notGoogleTimeline
    }

    // MARK: - Builder

    /// Accumulates `Visit`/`Activity`/`Path` model objects per day key as
    /// entries stream in, then materialises the final `AppExport`.
    private struct ExportBuilder {
        private struct DayBucket {
            var visits: [Visit] = []
            var activities: [Activity] = []
            var paths: [Path] = []
        }

        private var dayMap: [String: DayBucket] = [:]
        private var orderedDayKeys: [String] = []
        private var sawValidEntry = false

        mutating func ingest(_ entry: [String: Any]) {
            guard let startTimeStr = entry["startTime"] as? String,
                  let startDate = parseISO(startTimeStr) else { return }
            sawValidEntry = true

            let dayKey = dateFmt.string(from: startDate)
            let endTimeStr = entry["endTime"] as? String

            if dayMap[dayKey] == nil {
                dayMap[dayKey] = DayBucket()
                orderedDayKeys.append(dayKey)
            }

            if let visitData = entry["visit"] as? [String: Any] {
                if let v = makeVisit(visitData, startTime: startTimeStr, endTime: endTimeStr) {
                    dayMap[dayKey]!.visits.append(v)
                }
            } else if let activityData = entry["activity"] as? [String: Any] {
                if let a = makeActivity(activityData, startTime: startTimeStr, endTime: endTimeStr) {
                    dayMap[dayKey]!.activities.append(a)
                }
            } else if let pathData = entry["timelinePath"] as? [[String: Any]] {
                if let p = makePath(pathData, startTime: startTimeStr, endTime: endTimeStr, startDate: startDate) {
                    dayMap[dayKey]!.paths.append(p)
                }
            }
        }

        func finalize() throws -> AppExport {
            guard sawValidEntry else { throw ConversionError.notGoogleTimeline }

            let days: [Day] = orderedDayKeys.sorted().map { key in
                let bucket = dayMap[key]!
                return Day(
                    date: key,
                    visits: bucket.visits,
                    activities: bucket.activities,
                    paths: bucket.paths
                )
            }

            let meta = Meta(
                exportedAt: isoOutput.string(from: Date()),
                toolVersion: "ios-app-converter/1.0",
                source: Source(zipBasename: nil, zipPath: nil, inputFormat: "google_timeline"),
                output: Output(outDir: nil),
                config: ExportConfig(
                    mode: nil,
                    splitMidnight: nil,
                    splitMode: nil,
                    exportFormat: nil,
                    inputFormat: "google_timeline"
                ),
                filters: ExportFilters(
                    fromDate: nil,
                    toDate: nil,
                    year: nil,
                    month: nil,
                    weekday: nil,
                    limit: nil,
                    days: nil,
                    has: nil,
                    maxAccuracyM: nil,
                    activityTypes: nil,
                    minGapMin: nil
                )
            )

            return AppExport(
                schemaVersion: .v1_0,
                meta: meta,
                data: DataBlock(days: days),
                stats: nil
            )
        }
    }

    // MARK: - Date parsing

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

    // MARK: - Geo parsing

    /// Parses "geo:lat,lon" or "geo:lat,lon,alt" strings.
    private static func parseGeo(_ geo: String?) -> (lat: Double, lon: Double)? {
        guard let geo, geo.hasPrefix("geo:") else { return nil }
        let parts = geo.dropFirst(4).split(separator: ",")
        guard parts.count >= 2,
              let lat = Double(parts[0].trimmingCharacters(in: .whitespaces)),
              let lon = Double(parts[1].trimmingCharacters(in: .whitespaces)) else { return nil }
        return (lat, lon)
    }

    /// Handles numeric fields that Google may export as either a Number or a String.
    private static func parseDouble(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let s = value as? String { return Double(s) }
        return nil
    }

    // MARK: - Direct model builders

    private static func makeVisit(
        _ visitData: [String: Any],
        startTime: String,
        endTime: String?
    ) -> Visit? {
        let candidate = visitData["topCandidate"] as? [String: Any]
        let coord = parseGeo(candidate?["placeLocation"] as? String)
        return Visit(
            lat: coord?.lat,
            lon: coord?.lon,
            startTime: startTime,
            endTime: endTime,
            semanticType: candidate?["semanticType"] as? String,
            placeID: candidate?["placeID"] as? String,
            accuracyM: nil,
            sourceType: "google_timeline"
        )
    }

    private static func makeActivity(
        _ activityData: [String: Any],
        startTime: String,
        endTime: String?
    ) -> Activity? {
        let candidate = activityData["topCandidate"] as? [String: Any]
        let start = parseGeo(activityData["start"] as? String)
        let end = parseGeo(activityData["end"] as? String)
        return Activity(
            startTime: startTime,
            endTime: endTime,
            startLat: start?.lat,
            startLon: start?.lon,
            endLat: end?.lat,
            endLon: end?.lon,
            activityType: candidate?["type"] as? String,
            distanceM: parseDouble(activityData["distanceMeters"]),
            splitFromMidnight: nil,
            startAccuracyM: nil,
            endAccuracyM: nil,
            sourceType: "google_timeline",
            flatCoordinates: nil
        )
    }

    private static func makePath(
        _ pathData: [[String: Any]],
        startTime: String,
        endTime: String?,
        startDate: Date
    ) -> Path? {
        let points: [PathPoint] = pathData.compactMap { pt in
            guard let pointGeo = pt["point"] as? String,
                  let coord = parseGeo(pointGeo) else { return nil }
            var time: String?
            if let offsetStr = pt["durationMinutesOffsetFromStartTime"] as? String,
               let offset = Double(offsetStr) {
                time = isoOutput.string(from: startDate.addingTimeInterval(offset * 60))
            }
            return PathPoint(lat: coord.lat, lon: coord.lon, time: time, accuracyM: nil)
        }
        guard !points.isEmpty else { return nil }
        return Path(
            startTime: startTime,
            endTime: endTime,
            activityType: nil,
            distanceM: nil,
            sourceType: "google_timeline",
            points: points,
            flatCoordinates: nil
        )
    }
}
