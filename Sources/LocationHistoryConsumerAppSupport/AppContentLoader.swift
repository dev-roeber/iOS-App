import Foundation
import LocationHistoryConsumer
import ZIPFoundation

public enum AppContentLoaderError: LocalizedError {
    case fixtureNotFound(String)
    case fileReadFailed(String)
    case unsupportedFormat(String)
    case decodeFailed(String)
    case jsonNotFoundInZip(String)

    public var errorDescription: String? {
        switch self {
        case let .fixtureNotFound(name):
            return "Demo fixture not found: \(name).json"
        case let .fileReadFailed(name):
            return "Unable to read app export file: \(name)"
        case let .unsupportedFormat(name):
            return "'\(name)' has an unsupported format. LH2GPX requires an app_export.json created by the LocationHistory2GPX tool."
        case let .decodeFailed(name):
            return "'\(name)' could not be opened. LH2GPX requires an app_export.json created by the LocationHistory2GPX tool."
        case let .jsonNotFoundInZip(name):
            return "'\(name)' does not contain an app_export.json file."
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
        let entry = archive["app_export.json"]
            ?? archive.first(where: { $0.type == .file && $0.path.hasSuffix("/app_export.json") })
        guard let entry else {
            throw AppContentLoaderError.jsonNotFoundInZip(zipName)
        }
        var data = Data()
        try archive.extract(entry, bufferSize: 65536) { data.append($0) }
        if (try? JSONSerialization.jsonObject(with: data)) is [Any] {
            throw AppContentLoaderError.unsupportedFormat(zipName)
        }
        do {
            let export = try AppExportDecoder.decode(data: data)
            return AppSessionContent(export: export, source: .importedFile(filename: zipName))
        } catch {
            throw AppContentLoaderError.decodeFailed(zipName)
        }
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
