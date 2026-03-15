import Foundation
import LocationHistoryConsumer

public enum DemoContentSource: Equatable {
    case bundledFixture(name: String)
    case importedFile(filename: String)

    public var displayName: String {
        switch self {
        case let .bundledFixture(name):
            return "\(name).json"
        case let .importedFile(filename):
            return filename
        }
    }
}

public struct DemoContent {
    public let export: AppExport
    public let overview: ExportOverview
    public let daySummaries: [DaySummary]
    public let selectedDate: String?
    public let source: DemoContentSource

    public init(export: AppExport, source: DemoContentSource) {
        self.export = export
        self.overview = AppExportQueries.overview(from: export)
        self.daySummaries = AppExportQueries.daySummaries(from: export)
        self.selectedDate = self.daySummaries.first?.date
        self.source = source
    }

    public func detail(for date: String?) -> DayDetailViewState? {
        guard let date else {
            return nil
        }
        return AppExportQueries.dayDetail(for: date, in: export)
    }
}

public enum DemoDataLoaderError: LocalizedError {
    case fixtureNotFound(String)
    case fileReadFailed(String)
    case decodeFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .fixtureNotFound(name):
            return "Demo fixture not found: \(name).json"
        case let .fileReadFailed(name):
            return "Unable to read app export file: \(name)"
        case let .decodeFailed(name):
            return "Unable to decode app export file: \(name)"
        }
    }
}

public enum DemoDataLoader {
    public static let defaultFixtureName = "golden_app_export_sample_small"

    public static func loadDefaultContent() throws -> DemoContent {
        try loadContent(named: defaultFixtureName)
    }

    public static func loadContent(named name: String) throws -> DemoContent {
        let url = try fixtureURL(named: name)
        let export = try decodeFile(at: url, sourceName: "\(name).json")
        return DemoContent(export: export, source: .bundledFixture(name: name))
    }

    public static func loadImportedContent(from url: URL) throws -> DemoContent {
        let export = try decodeFile(at: url, sourceName: url.lastPathComponent)
        return DemoContent(export: export, source: .importedFile(filename: url.lastPathComponent))
    }

    public static func fixtureURL(named name: String) throws -> URL {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            throw DemoDataLoaderError.fixtureNotFound(name)
        }
        return url
    }

    private static func decodeFile(at url: URL, sourceName: String) throws -> AppExport {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw DemoDataLoaderError.fileReadFailed(sourceName)
        }

        do {
            return try AppExportDecoder.decode(data: data)
        } catch {
            throw DemoDataLoaderError.decodeFailed(sourceName)
        }
    }
}
