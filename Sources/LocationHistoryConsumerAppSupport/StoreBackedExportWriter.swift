import Foundation
import LocationHistoryConsumer

/// Phase-5 Store-backed Streaming-Export-Writer.
///
/// Liest aus `LocalTimelineStoreReader` und schreibt direkt über den
/// `LocalTimelineStreamingTextWriter` nach
/// `ExportStaging/<uuid>/export.<ext>`. **Niemals** wird ein vollständiger
/// `AppExport` materialisiert oder ein `[Double]`-Buffer für einen ganzen
/// Import gehalten; Koordinaten werden ausschließlich pro Pfad lazy aus
/// `coordinateSequence(forPathId:)` (CoordBlobIterator) gelesen.
///
/// **Bewusste Grenzen:**
/// - kein UI-Hook
/// - kein App-Session-Switch
/// - kein Map-/DayList-/DayDetail-Hook
/// - bestehender AppExport-Pfad (GPXBuilder/KMLBuilder/GeoJSONBuilder/CSVBuilder)
///   bleibt unverändert; dieser Writer ist additiv.
public final class StoreBackedExportWriter {

    public let reader: LocalTimelineStoreReader
    public let locations: LocalTimelineStorageLocations
    private let fileManager: FileManager

    public init(reader: LocalTimelineStoreReader,
                locations: LocalTimelineStorageLocations,
                fileManager: FileManager = .default) {
        self.reader = reader
        self.locations = locations
        self.fileManager = fileManager
    }

    /// Führt einen Streaming-Export entsprechend `selection`/`format` aus.
    /// Wirft `LocalTimelineExportError` für alle erwarteten Fehlerklassen
    /// (unbekannter Import, leere Selection, defekter coord_blob, I/O).
    @discardableResult
    public func export(selection: LocalTimelineExportSelection,
                       format: LocalTimelineExportFormat) throws -> LocalTimelineExportResult {

        // 1) Import-Existenz prüfen.
        do {
            guard try reader.importRecord(id: selection.importID) != nil else {
                throw LocalTimelineExportError.unknownImport(importID: selection.importID)
            }
        } catch let e as LocalTimelineExportError {
            throw e
        } catch {
            throw LocalTimelineExportError.readerFailure(message: "\(error)")
        }

        // 2) Days bounded auflösen, dann Selection-Filter (date range + dayIds).
        let days = try resolveDays(selection: selection)
        if days.isEmpty {
            throw LocalTimelineExportError.emptySelection(importID: selection.importID)
        }

        // 3) Ausgabe-URL unter ExportStaging/<uuid>/.
        try locations.ensureDirectoriesExist(fileManager: fileManager)
        let runDir = locations.exportStagingRoot
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let outURL = runDir.appendingPathComponent("export.\(format.fileExtension)",
                                                   isDirectory: false)

        let writer: LocalTimelineStreamingTextWriter
        do {
            writer = try LocalTimelineStreamingTextWriter(outputURL: outURL,
                                                          fileManager: fileManager)
        } catch let e as LocalTimelineStreamingTextWriter.WriterError {
            throw LocalTimelineExportError.ioFailure(path: outURL.path,
                                                     message: "\(e)")
        }

        // 4) Format-spezifisches Streaming.
        var counters = Counters()
        do {
            switch format {
            case .gpx:
                try streamGPX(days: days, selection: selection, writer: writer, counters: &counters)
            case .kml:
                try streamKML(days: days, selection: selection, writer: writer, counters: &counters)
            case .geoJSON:
                try streamGeoJSON(days: days, selection: selection, writer: writer, counters: &counters)
            case .csv:
                try streamCSV(days: days, selection: selection, writer: writer, counters: &counters)
            }
        } catch let e as LocalTimelineExportError {
            try? writer.finalize()
            throw e
        } catch let e as LocalTimelineStreamingTextWriter.WriterError {
            try? writer.finalize()
            throw LocalTimelineExportError.ioFailure(path: outURL.path, message: "\(e)")
        } catch {
            try? writer.finalize()
            throw LocalTimelineExportError.readerFailure(message: "\(error)")
        }

        do {
            try writer.finalize()
        } catch let e as LocalTimelineStreamingTextWriter.WriterError {
            throw LocalTimelineExportError.ioFailure(path: outURL.path, message: "\(e)")
        }

        return LocalTimelineExportResult(
            outputURL: outURL,
            format: format,
            bytesWritten: writer.bytesWritten,
            dayCount: counters.dayCount,
            pathCount: counters.pathCount,
            visitCount: counters.visitCount,
            activityCount: counters.activityCount,
            pointCount: counters.pointCount
        )
    }

    // MARK: - Day resolution

    private func resolveDays(selection: LocalTimelineExportSelection) throws -> [LocalTimelineDayRecord] {
        let all: [LocalTimelineDayRecord]
        do {
            all = try reader.days(forImportId: selection.importID)
        } catch {
            throw LocalTimelineExportError.readerFailure(message: "\(error)")
        }
        var filtered = all
        if let range = selection.dateRange {
            filtered = filtered.filter { range.contains($0.date) }
        }
        if let ids = selection.dayIds {
            let allowed = Set(ids)
            filtered = filtered.filter { allowed.contains($0.id) }
        }
        return filtered
    }

    private func detail(for day: LocalTimelineDayRecord) throws -> LocalTimelineDayDetailSnapshot {
        do {
            guard let snap = try reader.dayDetail(dayId: day.id) else {
                throw LocalTimelineExportError.readerFailure(
                    message: "missing day detail for id \(day.id)")
            }
            return snap
        } catch let e as LocalTimelineExportError {
            throw e
        } catch {
            throw LocalTimelineExportError.readerFailure(message: "\(error)")
        }
    }

    private func iterator(for path: LocalTimelinePathRecord) throws -> CoordBlobIterator {
        do {
            return try reader.coordinateSequence(forPathId: path.id)
        } catch let e as LocalTimelineStoreReader.ReaderError {
            switch e {
            case let .malformedCoordBlob(pathId, byteCount):
                throw LocalTimelineExportError.malformedCoordBlob(
                    pathID: pathId,
                    message: "byteCount=\(byteCount)")
            case .unknownPath:
                throw LocalTimelineExportError.readerFailure(message: "\(e)")
            }
        } catch let e as CoordBlobError {
            throw LocalTimelineExportError.malformedCoordBlob(
                pathID: path.id,
                message: "\(e)")
        } catch {
            throw LocalTimelineExportError.readerFailure(message: "\(error)")
        }
    }

    // MARK: - Counters

    private struct Counters {
        var dayCount = 0
        var pathCount = 0
        var visitCount = 0
        var activityCount = 0
        var pointCount = 0
    }

    // MARK: - GPX streaming

    private func streamGPX(days: [LocalTimelineDayRecord],
                           selection: LocalTimelineExportSelection,
                           writer: LocalTimelineStreamingTextWriter,
                           counters: inout Counters) throws {
        try writer.write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
        try writer.write(#"<gpx version="1.1" creator="LocationHistory2GPX iOS (store-backed)" xmlns="http://www.topografix.com/GPX/1/1">"#)
        try writer.write("\n")

        for day in days {
            counters.dayCount += 1
            let snap = try detail(for: day)

            if selection.includeVisits {
                for v in snap.visits {
                    guard let lat = v.latitude, let lon = v.longitude else { continue }
                    counters.visitCount += 1
                    let name = ExportUtils.xmlEscape(v.name ?? "Visit")
                    try writer.write("  <wpt lat=\"\(lat)\" lon=\"\(lon)\">\n")
                    try writer.write("    <name>\(name)</name>\n")
                    if let t = v.startTime {
                        try writer.write("    <time>\(ExportUtils.xmlEscape(t))</time>\n")
                    }
                    try writer.write("  </wpt>\n")
                }
            }

            if selection.includePaths {
                for path in snap.paths {
                    counters.pathCount += 1
                    let title = ExportUtils.xmlEscape("\(day.date) \(path.mode ?? "path")")
                    try writer.write("  <trk>\n    <name>\(title)</name>\n    <trkseg>\n")
                    var iter = try iterator(for: path)
                    while let c = iter.next() {
                        counters.pointCount += 1
                        try writer.write("      <trkpt lat=\"\(c.latitude)\" lon=\"\(c.longitude)\"/>\n")
                    }
                    try writer.write("    </trkseg>\n  </trk>\n")
                }
            }

            if selection.includeActivities {
                counters.activityCount += snap.activities.count
                // GPX hat keine native Activity-Repräsentation; Activities
                // werden in CSV explizit ausgegeben. Für GPX bleibt das
                // ein gezählter, nicht emittierter Bereich.
            }
        }

        try writer.write("</gpx>\n")
    }

    // MARK: - KML streaming

    private func streamKML(days: [LocalTimelineDayRecord],
                           selection: LocalTimelineExportSelection,
                           writer: LocalTimelineStreamingTextWriter,
                           counters: inout Counters) throws {
        try writer.write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
        try writer.write(#"<kml xmlns="http://www.opengis.net/kml/2.2"><Document>"#)
        try writer.write("\n")

        for day in days {
            counters.dayCount += 1
            let snap = try detail(for: day)

            if selection.includeVisits {
                for v in snap.visits {
                    guard let lat = v.latitude, let lon = v.longitude else { continue }
                    counters.visitCount += 1
                    let name = ExportUtils.xmlEscape(v.name ?? "Visit")
                    try writer.write("  <Placemark><name>\(name)</name>")
                    try writer.write("<Point><coordinates>\(lon),\(lat)</coordinates></Point></Placemark>\n")
                }
            }

            if selection.includePaths {
                for path in snap.paths {
                    counters.pathCount += 1
                    let title = ExportUtils.xmlEscape("\(day.date) \(path.mode ?? "path")")
                    try writer.write("  <Placemark><name>\(title)</name><LineString><coordinates>")
                    var iter = try iterator(for: path)
                    var first = true
                    while let c = iter.next() {
                        counters.pointCount += 1
                        if !first { try writer.write(" ") }
                        try writer.write("\(c.longitude),\(c.latitude),0")
                        first = false
                    }
                    try writer.write("</coordinates></LineString></Placemark>\n")
                }
            }

            if selection.includeActivities {
                counters.activityCount += snap.activities.count
            }
        }

        try writer.write("</Document></kml>\n")
    }

    // MARK: - GeoJSON streaming

    private func streamGeoJSON(days: [LocalTimelineDayRecord],
                               selection: LocalTimelineExportSelection,
                               writer: LocalTimelineStreamingTextWriter,
                               counters: inout Counters) throws {
        try writer.write(#"{"type":"FeatureCollection","features":["#)
        var first = true

        for day in days {
            counters.dayCount += 1
            let snap = try detail(for: day)

            if selection.includeVisits {
                for v in snap.visits {
                    guard let lat = v.latitude, let lon = v.longitude else { continue }
                    counters.visitCount += 1
                    if !first { try writer.write(",") }
                    first = false
                    let name = jsonEscape(v.name ?? "Visit")
                    let date = jsonEscape(day.date)
                    try writer.write(#"{"type":"Feature","geometry":{"type":"Point","coordinates":["#)
                    try writer.write("\(lon),\(lat)")
                    try writer.write(#"]},"properties":{"kind":"visit","name":""#)
                    try writer.write(name)
                    try writer.write(#"","date":""#)
                    try writer.write(date)
                    try writer.write(#""}}"#)
                }
            }

            if selection.includePaths {
                for path in snap.paths {
                    counters.pathCount += 1
                    if !first { try writer.write(",") }
                    first = false
                    let mode = jsonEscape(path.mode ?? "path")
                    let date = jsonEscape(day.date)
                    try writer.write(#"{"type":"Feature","geometry":{"type":"LineString","coordinates":["#)
                    var iter = try iterator(for: path)
                    var firstCoord = true
                    while let c = iter.next() {
                        counters.pointCount += 1
                        if !firstCoord { try writer.write(",") }
                        firstCoord = false
                        try writer.write("[\(c.longitude),\(c.latitude)]")
                    }
                    try writer.write(#"]},"properties":{"kind":"path","mode":""#)
                    try writer.write(mode)
                    try writer.write(#"","date":""#)
                    try writer.write(date)
                    try writer.write(#""}}"#)
                }
            }

            if selection.includeActivities {
                counters.activityCount += snap.activities.count
            }
        }

        try writer.write("]}")
    }

    // MARK: - CSV streaming

    private func streamCSV(days: [LocalTimelineDayRecord],
                           selection: LocalTimelineExportSelection,
                           writer: LocalTimelineStreamingTextWriter,
                           counters: inout Counters) throws {
        try writer.write("type,date,time,lat,lon,name,mode,distance_m\n")

        for day in days {
            counters.dayCount += 1
            let snap = try detail(for: day)

            if selection.includeVisits {
                for v in snap.visits {
                    counters.visitCount += 1
                    let row = csvRow([
                        "visit",
                        day.date,
                        v.startTime ?? "",
                        v.latitude.map { String($0) } ?? "",
                        v.longitude.map { String($0) } ?? "",
                        v.name ?? "",
                        "",
                        ""
                    ])
                    try writer.write(row + "\n")
                }
            }

            if selection.includeActivities {
                for a in snap.activities {
                    counters.activityCount += 1
                    let row = csvRow([
                        "activity",
                        day.date,
                        a.startTime ?? "",
                        a.startLat.map { String($0) } ?? "",
                        a.startLon.map { String($0) } ?? "",
                        "",
                        a.mode ?? "",
                        a.distanceM.map { String($0) } ?? ""
                    ])
                    try writer.write(row + "\n")
                }
            }

            if selection.includePaths {
                for path in snap.paths {
                    counters.pathCount += 1
                    var iter = try iterator(for: path)
                    while let c = iter.next() {
                        counters.pointCount += 1
                        let row = csvRow([
                            "path",
                            day.date,
                            path.startTime ?? "",
                            String(c.latitude),
                            String(c.longitude),
                            "",
                            path.mode ?? "",
                            String(path.distanceM)
                        ])
                        try writer.write(row + "\n")
                    }
                }
            }
        }
    }

    // MARK: - Escaping helpers

    private func csvRow(_ fields: [String]) -> String {
        fields.map { csvEscape($0) }.joined(separator: ",")
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            let doubled = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(doubled)\""
        }
        return value
    }

    private func jsonEscape(_ value: String) -> String {
        var out = ""
        out.reserveCapacity(value.count)
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            default:
                if scalar.value < 0x20 {
                    out += String(format: "\\u%04x", scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out
    }
}
