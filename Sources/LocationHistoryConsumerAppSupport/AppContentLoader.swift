import Foundation
import LocationHistoryConsumer
import ZIPFoundation

/// Errors that can occur when loading or decoding imported location-history data.
public enum AppContentLoaderError: LocalizedError {
    case fixtureNotFound(String)
    case fileReadFailed(String)
    case unsupportedFormat(String)
    case decodeFailed(String)
    case jsonNotFoundInZip(String)
    case multipleExportsInZip(String)

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
        case .jsonNotFoundInZip:
            return "No export found in ZIP"
        case .multipleExportsInZip:
            return "Multiple exports found in ZIP"
        }
    }

    public var errorDescription: String? {
        switch self {
        case let .fixtureNotFound(name):
            return "Demo fixture not found: \(name).json"
        case let .fileReadFailed(name):
            return "'\(name)' could not be read. The file may be corrupted or inaccessible."
        case let .unsupportedFormat(name):
            return "'\(name)' is not a supported location history format. Open an LH2GPX app_export.json or .zip from the LocationHistory2GPX tool, or a Google Timeline location-history.json or .zip."
        case let .decodeFailed(name):
            return "'\(name)' could not be decoded. The file may have been created with an incompatible version of the LocationHistory2GPX tool."
        case let .jsonNotFoundInZip(name):
            return "'\(name)' does not contain a supported location history export. The ZIP must contain exactly one compatible LH2GPX export JSON or one Google Timeline JSON such as location-history.json."
        case let .multipleExportsInZip(name):
            return "'\(name)' contains multiple compatible location history exports. Place only one LH2GPX export or one Google Timeline JSON per ZIP."
        }
    }
}

/// Decodes imported location-history files (JSON or ZIP) and fixtures into `AppSessionContent`.
public enum AppContentLoader {
    /// Name of the bundled demo fixture used by default when no file is imported.
    public static let defaultDemoFixtureName = "golden_app_export_sample_small"

    /// Loads a user-imported file (`.json` or `.zip`) from the given URL.
    public static func loadImportedContent(from url: URL) async throws -> AppSessionContent {
        return try await Task.detached(priority: .userInitiated) {
            if url.pathExtension.lowercased() == "zip" {
                return try loadZipContent(from: url)
            }
            let export = try decodeFile(at: url, sourceName: url.lastPathComponent)
            return AppSessionContent(export: export, source: .importedFile(filename: url.lastPathComponent))
        }.value
    }

    /// Maximum uncompressed size (256 MB) for a single ZIP entry.
    /// Guards against ZIP-bomb style inputs while staying well above any realistic export size.
    private static let maxUncompressedEntrySize = 256 * 1024 * 1024

    private static func loadZipContent(from url: URL) throws -> AppSessionContent {
        let zipName = url.lastPathComponent
        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .read)
        } catch {
            throw AppContentLoaderError.fileReadFailed(zipName)
        }

        // Collect JSON candidates, excluding macOS resource forks, hidden files, and oversized entries.
        let candidates = archive.filter { isJsonCandidate($0) }

        // Extract each candidate once; reuse the Data for both LH2GPX and Google Timeline attempts.
        let extracted: [(entry: Entry, data: Data)] = candidates.compactMap { entry in
            var data = Data()
            guard (try? archive.extract(entry, bufferSize: 65536) { data.append($0) }) != nil else { return nil }
            return (entry, data)
        }

        // Try to decode each extracted candidate as a valid LH2GPX app export.
        let valid: [(entry: Entry, export: AppExport)] = extracted.compactMap { item in
            guard !((try? JSONSerialization.jsonObject(with: item.data)) is [Any]) else { return nil }
            guard let export = try? AppExportDecoder.decode(data: item.data) else { return nil }
            return (item.entry, export)
        }

        switch valid.count {
        case 0:
            // No LH2GPX export found — try Google Timeline conversion using already-extracted data.
            return try loadGoogleTimelineFromExtracted(extracted, zipName: zipName)
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

    private static func loadGoogleTimelineFromExtracted(
        _ extracted: [(entry: Entry, data: Data)],
        zipName: String
    ) throws -> AppSessionContent {
        let timelineCandidates = extracted.filter { GoogleTimelineConverter.isGoogleTimeline($0.data) }

        switch timelineCandidates.count {
        case 0:
            throw AppContentLoaderError.jsonNotFoundInZip(zipName)
        case 1:
            do {
                let export = try GoogleTimelineConverter.convert(data: timelineCandidates[0].data)
                return AppSessionContent(export: export, source: .importedFile(filename: zipName))
            } catch {
                throw AppContentLoaderError.decodeFailed(zipName)
            }
        default:
            // Multiple Google Timeline JSONs: prefer "location-history.json" if unambiguous.
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
        }
    }

    private static func isJsonCandidate(_ entry: Entry) -> Bool {
        guard entry.type == .file else { return false }
        guard entry.uncompressedSize <= maxUncompressedEntrySize else { return false }
        let path = entry.path
        guard !path.hasPrefix("__MACOSX/"), !path.contains("/__MACOSX/") else { return false }
        let filename = (path as NSString).lastPathComponent
        guard !filename.hasPrefix(".") else { return false }
        return filename.lowercased().hasSuffix(".json")
    }

    public static func loadFixtureContent(named name: String, from bundle: Bundle, source: AppContentSource) throws -> AppSessionContent {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw AppContentLoaderError.fixtureNotFound(name)
        }
        let export = try decodeFile(at: url, sourceName: "\(name).json")
        return AppSessionContent(export: export, source: source)
    }

    private static func decodeFile(at url: URL, sourceName: String) throws -> AppExport {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw AppContentLoaderError.fileReadFailed(sourceName)
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
