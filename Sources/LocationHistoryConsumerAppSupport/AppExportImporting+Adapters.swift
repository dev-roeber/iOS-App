import Foundation
import LocationHistoryConsumer

// MARK: - GPX

extension GPXImportParser: AppExportImporting {
    public static func canImport(_ data: Data) -> Bool { isGPX(data) }

    public static func makeAppExport(from data: Data, fileName: String) throws -> AppExport {
        try parse(data, fileName: fileName)
    }
}

// MARK: - TCX

extension TCXImportParser: AppExportImporting {
    public static func canImport(_ data: Data) -> Bool { isTCX(data) }

    public static func makeAppExport(from data: Data, fileName: String) throws -> AppExport {
        try parse(data, fileName: fileName)
    }
}

// MARK: - Google Timeline
//
// Trade-off: `GoogleTimelineConverter` is internal to
// `LocationHistoryConsumerAppSupport`. It cannot conform to a `public`
// protocol with `public` requirements, so we expose the conformance with
// `internal` visibility — sufficient for in-module callers.

extension GoogleTimelineConverter: AppExportImporting {
    static func canImport(_ data: Data) -> Bool { isGoogleTimeline(data) }

    static func makeAppExport(from data: Data, fileName _: String) throws -> AppExport {
        try convert(data: data)
    }
}
