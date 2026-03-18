import Foundation
import LocationHistoryConsumer
import ZIPFoundation

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
            return "'\(name)' is not a supported export format. Open a file created by the LocationHistory2GPX tool — either a .json export or a .zip containing it."
        case let .decodeFailed(name):
            return "'\(name)' could not be decoded. The file may have been created with an incompatible version of the LocationHistory2GPX tool."
        case let .jsonNotFoundInZip(name):
            return "'\(name)' does not contain a compatible LH2GPX export. This app only opens exports created by the LocationHistory2GPX tool. If you have a Google Timeline ZIP, use the tool to convert it first."
        case let .multipleExportsInZip(name):
            return "'\(name)' contains multiple compatible exports. Place only one LH2GPX export per ZIP."
        }
    }
}

public enum AppContentLoader {
    public static let defaultDemoFixtureName = "golden_app_export_sample_small"

    public static func loadImportedContent(from url: URL) throws -> AppSessionContent {
        if url.pathExtension.lowercased() == "zip" {
            return try loadZipContent(from: url)
        }
        let export = try decodeFile(at: url, sourceName: url.lastPathComponent)
        return AppSessionContent(export: export, source: .importedFile(filename: url.lastPathComponent))
    }

    private static func loadZipContent(from url: URL) throws -> AppSessionContent {
        let zipName = url.lastPathComponent
        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .read)
        } catch {
            throw AppContentLoaderError.fileReadFailed(zipName)
        }

        // Collect all JSON candidates, ignoring macOS resource forks and hidden files.
        let candidates = archive.filter { isJsonCandidate($0) }

        // Attempt to decode each candidate as a valid LH2GPX app export.
        let valid: [(entry: Entry, export: AppExport)] = candidates.compactMap { entry in
            guard let export = tryDecodeEntry(entry, in: archive) else { return nil }
            return (entry, export)
        }

        switch valid.count {
        case 0:
            // No LH2GPX export found — try Google Timeline conversion as fallback.
            return try loadGoogleTimelineFromZip(candidates: candidates, archive: archive, zipName: zipName)
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

    private static func loadGoogleTimelineFromZip(
        candidates: [Entry],
        archive: Archive,
        zipName: String
    ) throws -> AppSessionContent {
        // Collect all JSON candidates that look like Google Timeline (array root).
        let timelineCandidates: [(entry: Entry, data: Data)] = candidates.compactMap { entry in
            var data = Data()
            guard (try? archive.extract(entry, bufferSize: 65536) { data.append($0) }) != nil,
                  GoogleTimelineConverter.isGoogleTimeline(data) else { return nil }
            return (entry, data)
        }

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
        let path = entry.path
        guard !path.hasPrefix("__MACOSX/"), !path.contains("/__MACOSX/") else { return false }
        let filename = (path as NSString).lastPathComponent
        guard !filename.hasPrefix(".") else { return false }
        return filename.lowercased().hasSuffix(".json")
    }

    private static func tryDecodeEntry(_ entry: Entry, in archive: Archive) -> AppExport? {
        var data = Data()
        guard (try? archive.extract(entry, bufferSize: 65536) { data.append($0) }) != nil else { return nil }
        guard !((try? JSONSerialization.jsonObject(with: data)) is [Any]) else { return nil }
        return try? AppExportDecoder.decode(data: data)
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

        // Pre-check: Google Location History exports use a JSON array as root.
        // Attempting to decode them as AppExport would produce a misleading error.
        if (try? JSONSerialization.jsonObject(with: data)) is [Any] {
            throw AppContentLoaderError.unsupportedFormat(sourceName)
        }

        do {
            return try AppExportDecoder.decode(data: data)
        } catch {
            throw AppContentLoaderError.decodeFailed(sourceName)
        }
    }
}
