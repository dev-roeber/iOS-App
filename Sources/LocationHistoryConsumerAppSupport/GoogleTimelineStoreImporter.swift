import Foundation
import LocationHistoryConsumer

/// Disk-first importer for Google Timeline JSON / ZIP into the
/// `LocalTimelineStore` (Phase 2).
///
/// Sits on top of the existing `GoogleTimelineStreamReader` (object-by-object,
/// per-element peak ~few KB) and forwards each entry to a
/// `LocalTimelineImportWriter` that batches inserts inside a single SQLite
/// transaction. **No `AppExport` is built.** No `[Day]`, `[Visit]`,
/// `[Activity]`, or `[Path]` accumulators exist on the import path — the
/// only retained per-day state is a small aggregator (`route_count`,
/// `visit_count`, summed `distance_m`, `dayId`).
///
/// This importer is **not** wired into any UI flow. The existing
/// `AppContentLoader` → `GoogleTimelineConverter` → `AppExport` path is
/// untouched in `main`. This type exists so the Linux test surface can
/// exercise the disk-first pipeline end-to-end before any production hook.
public enum GoogleTimelineStoreImporter {

    public enum ImportError: Error {
        case notGoogleTimeline
        case streamFailed(underlying: Error)
        case writeFailed(underlying: Error)
    }

    /// Stream a Google Timeline JSON file directly into the store.
    /// Returns the resulting import-id + day count + entry totals.
    @discardableResult
    public static func importFromFile(
        url: URL,
        sourceFilename: String? = nil,
        store: LocalTimelineStore,
        writerOptions: LocalTimelineImportWriter.Options = .init()
    ) throws -> LocalTimelineImportSummary {
        let writer = try LocalTimelineImportWriter(
            store: store,
            source: sourceFilename ?? url.lastPathComponent,
            options: writerOptions
        )
        do {
            try GoogleTimelineStreamReader.forEachObjectElement(contentsOf: url) { raw in
                try ingest(raw, writer: writer)
            }
            return try writer.finalize()
        } catch {
            writer.cancel()
            if error is LocalTimelineStoreError {
                throw ImportError.writeFailed(underlying: error)
            }
            if let stream = error as? GoogleTimelineStreamReader.StreamError {
                throw ImportError.streamFailed(underlying: stream)
            }
            throw error
        }
    }

    /// Stream a Google Timeline JSON `Data` (already in memory, e.g. from a
    /// ZIP entry) directly into the store.
    @discardableResult
    public static func importFromData(
        _ data: Data,
        sourceFilename: String,
        store: LocalTimelineStore,
        writerOptions: LocalTimelineImportWriter.Options = .init()
    ) throws -> LocalTimelineImportSummary {
        let writer = try LocalTimelineImportWriter(
            store: store, source: sourceFilename, options: writerOptions
        )
        do {
            try GoogleTimelineStreamReader.forEachObjectElement(in: data) { raw in
                try ingest(raw, writer: writer)
            }
            return try writer.finalize()
        } catch {
            writer.cancel()
            if error is LocalTimelineStoreError {
                throw ImportError.writeFailed(underlying: error)
            }
            if let stream = error as? GoogleTimelineStreamReader.StreamError {
                throw ImportError.streamFailed(underlying: stream)
            }
            throw error
        }
    }

    // MARK: - Per-entry dispatch

    private static func ingest(_ raw: Any, writer: LocalTimelineImportWriter) throws {
        guard let entry = raw as? [String: Any] else { return }
        let startTime = entry["startTime"] as? String
        let endTime = entry["endTime"] as? String

        if let visitData = entry["visit"] as? [String: Any] {
            let candidate = visitData["topCandidate"] as? [String: Any]
            let coord = parseGeo(candidate?["placeLocation"] as? String)
            try writer.addVisit(.init(
                startTime: startTime,
                endTime: endTime,
                latitude: coord?.lat,
                longitude: coord?.lon,
                name: candidate?["semanticType"] as? String,
                semanticType: candidate?["semanticType"] as? String,
                placeId: candidate?["placeID"] as? String,
                probability: parseDouble(visitData["probability"])
                    ?? parseDouble(candidate?["probability"])
            ))
        } else if let activityData = entry["activity"] as? [String: Any] {
            let candidate = activityData["topCandidate"] as? [String: Any]
            let start = parseGeo(activityData["start"] as? String)
            let end = parseGeo(activityData["end"] as? String)
            let mode = candidate?["type"] as? String
            try writer.addActivity(.init(
                startTime: startTime,
                endTime: endTime,
                mode: mode,
                distanceM: parseDouble(activityData["distanceMeters"]),
                startLat: start?.lat, startLon: start?.lon,
                endLat: end?.lat, endLon: end?.lon,
                probability: parseDouble(activityData["probability"])
                    ?? parseDouble(candidate?["probability"]),
                rawType: mode
            ))
        } else if let pathData = entry["timelinePath"] as? [[String: Any]] {
            var flat: [Double] = []
            flat.reserveCapacity(pathData.count * 2)
            for pt in pathData {
                guard let geo = pt["point"] as? String,
                      let coord = parseGeo(geo) else { continue }
                flat.append(coord.lat)
                flat.append(coord.lon)
            }
            if flat.count >= 4 {
                try writer.addPath(.init(
                    startTime: startTime,
                    endTime: endTime,
                    mode: nil,
                    distanceM: 0,
                    flatCoordinates: flat
                ))
            }
        }
        // Entries without a recognised payload are silently skipped — same
        // behaviour as `GoogleTimelineConverter.ExportBuilder.ingest`.
    }

    private static func parseGeo(_ geo: String?) -> (lat: Double, lon: Double)? {
        guard let geo, geo.hasPrefix("geo:") else { return nil }
        let parts = geo.dropFirst(4).split(separator: ",")
        guard parts.count >= 2,
              let lat = Double(parts[0].trimmingCharacters(in: .whitespaces)),
              let lon = Double(parts[1].trimmingCharacters(in: .whitespaces)) else { return nil }
        return (lat, lon)
    }

    private static func parseDouble(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let s = value as? String { return Double(s) }
        return nil
    }
}
