import Foundation
import LocationHistoryConsumer
import ZIPFoundation

/// Errors that can occur when loading or decoding imported location-history data.
public enum AppContentLoaderError: LocalizedError {
    case fixtureNotFound(String)
    case fileReadFailed(String)
    case unsupportedFormat(String)
    case decodeFailed(String)
    case fileTooLarge(String)
    case jsonNotFoundInZip(String)
    case multipleExportsInZip(String)
    /// Auto-restore was suppressed because the previously-imported file is
    /// either a raw Google Timeline export (any size) or another file above
    /// the auto-restore size ceiling. Re-parsing on every launch would risk
    /// an out-of-memory shutdown on iPhone. The user must manually re-import
    /// when ready to wait for the parse.
    case autoRestoreSkippedLargeFile(String)

    public var userFacingTitle: String {
        switch self {
        case .fixtureNotFound:
            return "Demo data unavailable"
        case .fileReadFailed:
            return "Unable to read file"
        case .unsupportedFormat:
            return "Unsupported file format"
        case .decodeFailed:
            return "File could not be opened"
        case .fileTooLarge:
            return "File too large"
        case .jsonNotFoundInZip:
            return "No export found in ZIP"
        case .multipleExportsInZip:
            return "Multiple exports found in ZIP"
        case .autoRestoreSkippedLargeFile:
            return "Import not auto-restored"
        }
    }

    public var errorDescription: String? {
        switch self {
        case let .fixtureNotFound(name):
            return "Demo fixture not found: \(name).json"
        case let .fileReadFailed(name):
            return "'\(name)' could not be read. The file may be corrupted or inaccessible."
        case let .unsupportedFormat(name):
            return "'\(name)' is not a supported location history format. Open an LH2GPX app_export.json or .zip from the LocationHistory2GPX tool, a Google Timeline location-history.json or .zip, or a GPX/TCX track file."
        case let .decodeFailed(name):
            return "'\(name)' could not be decoded. The file may have been created with an incompatible version of the LocationHistory2GPX tool."
        case let .fileTooLarge(name):
            return "'\(name)' exceeds the 256 MB limit for JSON imports."
        case let .jsonNotFoundInZip(name):
            return "'\(name)' does not contain a supported location history export. The ZIP must contain exactly one compatible LH2GPX export JSON, one Google Timeline JSON such as location-history.json, or a GPX/TCX track file."
        case let .multipleExportsInZip(name):
            return "'\(name)' contains multiple compatible location history exports. Place only one LH2GPX export or one Google Timeline JSON per ZIP."
        case let .autoRestoreSkippedLargeFile(name):
            return "'\(name)' was not restored automatically. Raw Google Timeline exports and large files are skipped on launch because re-parsing them every time can cause an out-of-memory shutdown. Open it manually when you are ready to wait for the import."
        }
    }
}

/// Coarse import-pipeline phases surfaced to UI via the optional
/// `loadImportedContent(...,onPhase:)` callback. Granular enough to give
/// users feedback ("we're reading the bytes" vs "we're building the model")
/// without inviting per-element flicker. Each phase fires at most once per
/// `loadImportedContent` call.
public enum ImportPhase: String, Equatable, Sendable {
    /// File is being opened, sized, and sniffed. Cheap.
    case reading
    /// JSON / GPX / TCX / ZIP entries are being decoded element-by-element.
    /// Dominant phase for large Google Timeline imports.
    case parsing
    /// Per-day buckets are being collapsed into the final `AppExport` model.
    case building
}

/// Decodes imported location-history files (JSON or ZIP) and fixtures into `AppSessionContent`.
public enum AppContentLoader {
    /// Name of the bundled demo fixture used by default when no file is imported.
    public static let defaultDemoFixtureName = "golden_app_export_sample_small"

    /// Loads a user-imported file (`.json`, `.zip`, `.gpx`, or `.tcx`) from the given URL.
    /// - Parameter autoRestoreMode: When `true`, applies a stricter size cap
    ///   so a previously-imported large Google Timeline export does not
    ///   re-trigger an OOM shutdown on every app launch.
    /// - Parameter onPhase: Optional callback fired on the loader's
    ///   background queue when the pipeline transitions between coarse
    ///   phases (`reading` → `parsing` → `building`). UI listeners must
    ///   marshal back to the main actor themselves.
    public static func loadImportedContent(
        from url: URL,
        autoRestoreMode: Bool = false,
        onPhase: (@Sendable (ImportPhase) -> Void)? = nil
    ) async throws -> AppSessionContent {
        return try await Task.detached(priority: .userInitiated) {
            onPhase?(.reading)
            try assertAutoRestoreEligible(
                url: url,
                autoRestoreMode: autoRestoreMode
            )
            let ext = url.pathExtension.lowercased()
            if ext == "zip" {
                return try loadZipContent(from: url, onPhase: onPhase)
            }
            onPhase?(.parsing)
            let export = try decodeFile(at: url, sourceName: url.lastPathComponent, onPhase: onPhase)
            return AppSessionContent(export: export, source: .importedFile(filename: url.lastPathComponent))
        }.value
    }

    /// Maximum size (256 MB) for a JSON file or single ZIP entry.
    /// Guards against ZIP-bomb style inputs and OOM while staying well above any realistic export size.
    private static let maxSupportedFileSizeBytes: Int64 = 256 * 1024 * 1024

    /// Conservative ceiling for unattended auto-restore on launch. A 46 MB
    /// Google Timeline JSON parses through three full `JSONSerialization`
    /// passes plus intermediate Swift dictionaries — the resulting transient
    /// peak (~400–500 MB) reliably trips iOS Jetsam on devices with 4 GB RAM.
    /// Manual imports keep the higher 256 MB cap because the user is then
    /// actively waiting for the parse and will not be surprised by the cost.
    public static let autoRestoreMaxFileSizeBytes: Int64 = 50 * 1024 * 1024

    /// Inspects the URL prior to read. Auto-restore must NOT silently
    /// re-parse raw Google Timeline JSON on every launch — even when the file
    /// is below the size ceiling — because the converter still does a full
    /// `JSONSerialization` pass plus an intermediate dictionary tree, and a
    /// realistic 46 MB export already trips iOS Jetsam on devices with 4 GB
    /// RAM. Two independent skip conditions therefore apply when
    /// `autoRestoreMode == true`:
    ///
    /// 1. The head bytes look like a top-level JSON array (Google Timeline
    ///    raw export). Filename does not matter.
    /// 2. The on-disk size (or any JSON entry's uncompressed size in a ZIP)
    ///    exceeds `autoRestoreMaxFileSizeBytes`.
    ///
    /// Either condition throws `.autoRestoreSkippedLargeFile`. Manual loads
    /// (`autoRestoreMode == false`) bypass both checks.
    private static func assertAutoRestoreEligible(
        url: URL,
        autoRestoreMode: Bool
    ) throws {
        guard autoRestoreMode else { return }
        let filename = url.lastPathComponent
        let ext = url.pathExtension.lowercased()

        if ext == "zip" {
            guard let archive = try? Archive(url: url, accessMode: .read) else {
                // Treat unreadable archives as auto-restore skip rather than
                // hard-failing on launch.
                throw AppContentLoaderError.autoRestoreSkippedLargeFile(filename)
            }
            for entry in archive {
                guard isJsonCandidate(entry) else { continue }
                if entry.uncompressedSize > UInt64(autoRestoreMaxFileSizeBytes) {
                    throw AppContentLoaderError.autoRestoreSkippedLargeFile(filename)
                }
                if let head = sniffEntryHead(archive: archive, entry: entry),
                   GoogleTimelineConverter.isGoogleTimeline(head) {
                    throw AppContentLoaderError.autoRestoreSkippedLargeFile(filename)
                }
            }
            return
        }

        // Direct file (json/gpx/tcx). Stat first, then sniff a small head.
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64,
           size > autoRestoreMaxFileSizeBytes {
            throw AppContentLoaderError.autoRestoreSkippedLargeFile(filename)
        }
        if ext == "json", let head = sniffFileHead(url: url),
           GoogleTimelineConverter.isGoogleTimeline(head) {
            throw AppContentLoaderError.autoRestoreSkippedLargeFile(filename)
        }
    }

    /// Reads at most `byteLimit` bytes from the start of a file using a
    /// `FileHandle`. Returns nil on read failure. Does NOT load the whole
    /// file — used to sniff the JSON top-level kind (`[` vs `{`) before
    /// committing to a full parse.
    private static func sniffFileHead(url: URL, byteLimit: Int = 1024) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        return try? handle.read(upToCount: byteLimit)
    }

    /// Extracts the first ~`byteLimit` bytes of a ZIP entry by aborting the
    /// `Archive.extract` callback once enough data is buffered. Avoids
    /// decompressing the entire entry (which for a 60 MB Google Timeline
    /// would defeat the point of the auto-restore guard).
    private static func sniffEntryHead(archive: Archive, entry: Entry, byteLimit: Int = 1024) -> Data? {
        struct StopExtraction: Error {}
        var collected = Data()
        do {
            _ = try archive.extract(entry, bufferSize: 4096) { chunk in
                collected.append(chunk)
                if collected.count >= byteLimit { throw StopExtraction() }
            }
        } catch is StopExtraction {
            // Expected — early termination after byteLimit reached.
            return collected.isEmpty ? nil : collected
        } catch {
            // Echte ZIP-/IO-Fehler dürfen NICHT als erfolgreicher Empty-Parse
            // durchgereicht werden; sonst behandelt der Aufrufer einen kaputten
            // Stream wie eine leere, aber gültige Datei. Daher hier nil.
            return nil
        }
        return collected.isEmpty ? nil : collected
    }

    private static func loadZipContent(from url: URL, onPhase: (@Sendable (ImportPhase) -> Void)? = nil) throws -> AppSessionContent {
        let zipName = url.lastPathComponent
        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .read)
        } catch {
            throw AppContentLoaderError.fileReadFailed(zipName)
        }

        // Collect JSON candidates, excluding macOS resource forks, hidden files, and oversized entries.
        let candidates = archive.filter { isJsonCandidate($0) }

        // Early Google-Timeline streaming path. We sniff the first 1 KB of
        // each JSON candidate (without decompressing the rest) to look for a
        // top-level array. If exactly one candidate is a raw Google Timeline
        // and no candidate looks like an LH2GPX object, we stream-decompress
        // that single entry through the incremental converter — peak RAM is
        // then ~one element (~few KB) instead of the full uncompressed entry
        // size sitting in `extracted` alongside the Foundation tree.
        onPhase?(.parsing)
        if let streamed = try streamGoogleTimelineCandidateIfApplicable(
            candidates: candidates,
            archive: archive,
            zipName: zipName,
            onPhase: onPhase
        ) {
            return streamed
        }

        // Extract each JSON candidate once; reuse the Data for both LH2GPX and Google Timeline attempts.
        let extracted: [(entry: Entry, data: Data)] = candidates.compactMap { entry in
            var data = Data()
            guard (try? archive.extract(entry, bufferSize: 65536) { data.append($0) }) != nil else { return nil }
            return (entry, data)
        }

        // Try to decode each extracted candidate as a valid LH2GPX app export.
        // Cheap sniff first — LH2GPX export is a JSON object (`{`); skip
        // arrays without paying for a `JSONSerialization` parse, which on a
        // 46 MB Google Timeline file would allocate ~150-200 MB of transient
        // Foundation objects per attempt.
        let valid: [(entry: Entry, export: AppExport)] = extracted.compactMap { item in
            guard GoogleTimelineConverter.isJSONObject(item.data) else { return nil }
            guard let export = try? AppExportDecoder.decode(data: item.data) else { return nil }
            return (item.entry, export)
        }

        switch valid.count {
        case 0:
            // No LH2GPX export found — try Google Timeline, then GPX/TCX.
            return try loadNonLH2GPXFromExtracted(extracted, archive: archive, zipName: zipName)
        case 1:
            return AppSessionContent(export: valid[0].export, source: .importedFile(filename: zipName))
        default:
            // Multiple valid LH2GPX exports: prefer the canonical name if present and unambiguous.
            let preferred = valid.first(where: {
                ($0.entry.path as NSString).lastPathComponent == "app_export.json"
            })
            if let preferred {
                return AppSessionContent(export: preferred.export, source: .importedFile(filename: zipName))
            }
            throw AppContentLoaderError.multipleExportsInZip(zipName)
        }
    }

    /// Fallback when no LH2GPX JSON export was found: try Google Timeline, then GPX, then TCX.
    private static func loadNonLH2GPXFromExtracted(
        _ extracted: [(entry: Entry, data: Data)],
        archive: Archive,
        zipName: String
    ) throws -> AppSessionContent {
        // 1. Try Google Timeline
        let timelineCandidates = extracted.filter { GoogleTimelineConverter.isGoogleTimeline($0.data) }

        switch timelineCandidates.count {
        case 1:
            do {
                let export = try GoogleTimelineConverter.convert(data: timelineCandidates[0].data)
                return AppSessionContent(export: export, source: .importedFile(filename: zipName))
            } catch {
                throw AppContentLoaderError.decodeFailed(zipName)
            }
        case let n where n > 1:
            let preferred = timelineCandidates.first(where: {
                ($0.entry.path as NSString).lastPathComponent == "location-history.json"
            })
            if let preferred {
                do {
                    let export = try GoogleTimelineConverter.convert(data: preferred.data)
                    return AppSessionContent(export: export, source: .importedFile(filename: zipName))
                } catch {
                    throw AppContentLoaderError.decodeFailed(zipName)
                }
            }
            throw AppContentLoaderError.multipleExportsInZip(zipName)
        default:
            break
        }

        // 2. Try GPX entries in the ZIP
        let gpxEntries = archive.filter { isGPXCandidate($0) }
        for entry in gpxEntries {
            var data = Data()
            guard (try? archive.extract(entry, bufferSize: 65536) { data.append($0) }) != nil else { continue }
            if let export = try? GPXImportParser.parse(data, fileName: (entry.path as NSString).lastPathComponent) {
                return AppSessionContent(export: export, source: .importedFile(filename: zipName))
            }
        }

        // 3. Try TCX entries in the ZIP
        let tcxEntries = archive.filter { isTCXCandidate($0) }
        for entry in tcxEntries {
            var data = Data()
            guard (try? archive.extract(entry, bufferSize: 65536) { data.append($0) }) != nil else { continue }
            if let export = try? TCXImportParser.parse(data, fileName: (entry.path as NSString).lastPathComponent) {
                return AppSessionContent(export: export, source: .importedFile(filename: zipName))
            }
        }

        throw AppContentLoaderError.jsonNotFoundInZip(zipName)
    }

    /// Inspects each JSON candidate's first ~1 KB to classify it as Google
    /// Timeline (`[`) or LH2GPX-shaped (`{`). If exactly one Timeline entry
    /// is present and **no** entry looks like an LH2GPX object, the entry is
    /// stream-decompressed straight through the per-element converter.
    /// Returns the loaded `AppSessionContent`, or `nil` to signal that the
    /// caller should continue with the existing extract-then-decode path.
    private static func streamGoogleTimelineCandidateIfApplicable(
        candidates: [Entry],
        archive: Archive,
        zipName: String,
        onPhase: (@Sendable (ImportPhase) -> Void)? = nil
    ) throws -> AppSessionContent? {
        var timelineEntries: [Entry] = []
        var sawObjectShapedEntry = false

        for entry in candidates {
            guard let head = sniffEntryHead(archive: archive, entry: entry) else { continue }
            if GoogleTimelineConverter.isGoogleTimeline(head) {
                timelineEntries.append(entry)
            } else if GoogleTimelineConverter.isJSONObject(head) {
                sawObjectShapedEntry = true
            }
        }

        // Defer to the legacy extract-and-decode path if there is any object-
        // shaped candidate (likely an LH2GPX export) or anything other than
        // a single Timeline entry.
        guard !sawObjectShapedEntry else { return nil }

        let chosen: Entry
        switch timelineEntries.count {
        case 0:
            return nil
        case 1:
            chosen = timelineEntries[0]
        default:
            // Multiple Timeline-shaped entries: prefer the canonical filename
            // if exactly one matches; otherwise let the legacy path emit the
            // proper "multiple exports" error.
            guard let preferred = timelineEntries.first(where: {
                ($0.path as NSString).lastPathComponent == "location-history.json"
            }) else {
                return nil
            }
            chosen = preferred
        }

        let converter = GoogleTimelineConverter.incrementalStreamConverter()
        do {
            _ = try archive.extract(chosen, bufferSize: 256 * 1024) { chunk in
                try converter.feed(chunk)
            }
            onPhase?(.building)
            let export = try converter.finalize()
            return AppSessionContent(export: export, source: .importedFile(filename: zipName))
        } catch {
            throw AppContentLoaderError.decodeFailed(zipName)
        }
    }

    private static func isJsonCandidate(_ entry: Entry) -> Bool {
        guard entry.type == .file else { return false }
        guard entry.uncompressedSize <= maxSupportedFileSizeBytes else { return false }
        let path = entry.path
        guard !path.hasPrefix("__MACOSX/"), !path.contains("/__MACOSX/") else { return false }
        let filename = (path as NSString).lastPathComponent
        guard !filename.hasPrefix(".") else { return false }
        return filename.lowercased().hasSuffix(".json")
    }

    private static func isGPXCandidate(_ entry: Entry) -> Bool {
        guard entry.type == .file else { return false }
        guard entry.uncompressedSize <= maxSupportedFileSizeBytes else { return false }
        let path = entry.path
        guard !path.hasPrefix("__MACOSX/"), !path.contains("/__MACOSX/") else { return false }
        let filename = (path as NSString).lastPathComponent
        guard !filename.hasPrefix(".") else { return false }
        return filename.lowercased().hasSuffix(".gpx")
    }

    private static func isTCXCandidate(_ entry: Entry) -> Bool {
        guard entry.type == .file else { return false }
        guard entry.uncompressedSize <= maxSupportedFileSizeBytes else { return false }
        let path = entry.path
        guard !path.hasPrefix("__MACOSX/"), !path.contains("/__MACOSX/") else { return false }
        let filename = (path as NSString).lastPathComponent
        guard !filename.hasPrefix(".") else { return false }
        return filename.lowercased().hasSuffix(".tcx")
    }

    public static func loadFixtureContent(named name: String, from bundle: Bundle, source: AppContentSource) throws -> AppSessionContent {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw AppContentLoaderError.fixtureNotFound(name)
        }
        let export = try decodeFile(at: url, sourceName: "\(name).json")
        return AppSessionContent(export: export, source: source)
    }

    private static func decodeFile(at url: URL, sourceName: String, onPhase: (@Sendable (ImportPhase) -> Void)? = nil) throws -> AppExport {
        // Size check before loading into memory
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attributes[.size] as? Int64,
           size > maxSupportedFileSizeBytes {
            throw AppContentLoaderError.fileTooLarge(sourceName)
        }

        // Cheap head-sniff before committing to a full Data load. For Google
        // Timeline raw JSON we hand the URL straight to the streaming
        // converter — that path peaks at ~one element worth of Foundation
        // objects (a few KB) instead of holding the whole file in memory
        // alongside the JSONSerialization tree.
        if let head = peekFileHead(url: url, byteLimit: 1024) {
            if GoogleTimelineConverter.isGoogleTimeline(head) {
                do {
                    let result = try GoogleTimelineConverter.convertStreaming(contentsOf: url)
                    onPhase?(.building)
                    return result
                } catch {
                    throw AppContentLoaderError.unsupportedFormat(sourceName)
                }
            }
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw AppContentLoaderError.fileReadFailed(sourceName)
        }

        return try decodeData(data, sourceName: sourceName)
    }

    /// Reads at most `byteLimit` bytes from the start of a file. Used to
    /// classify the top-level JSON kind (`[` vs `{`) before committing to a
    /// full read. Distinct from `sniffFileHead` (auto-restore guard) so each
    /// caller can pick its own byte limit and error semantics.
    private static func peekFileHead(url: URL, byteLimit: Int) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        return try? handle.read(upToCount: byteLimit)
    }

    /// Decodes raw data into an `AppExport`, routing by format detection.
    static func decodeData(_ data: Data, sourceName: String) throws -> AppExport {
        // GPX format detection
        if GPXImportParser.isGPX(data) {
            return try GPXImportParser.parse(data, fileName: sourceName)
        }

        // TCX format detection
        if TCXImportParser.isTCX(data) {
            do {
                return try TCXImportParser.parse(data, fileName: sourceName)
            } catch is TCXImportError {
                throw AppContentLoaderError.decodeFailed(sourceName)
            }
        }

        // If the file is a JSON array, try Google Timeline conversion before giving up.
        if GoogleTimelineConverter.isGoogleTimeline(data) {
            do {
                return try GoogleTimelineConverter.convert(data: data)
            } catch {
                throw AppContentLoaderError.unsupportedFormat(sourceName)
            }
        }

        do {
            return try AppExportDecoder.decode(data: data)
        } catch {
            throw AppContentLoaderError.decodeFailed(sourceName)
        }
    }
}
