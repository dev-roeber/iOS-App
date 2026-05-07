import Foundation

/// Common surface for any importer that consumes raw bytes (or a URL)
/// and produces an `AppExport`. Existing types (`GPXImportParser`,
/// `TCXImportParser`, `GoogleTimelineConverter`, `AppExportDecoder`)
/// keep their idiomatic verb names; this protocol is the architecture-
/// level contract documenting what they have in common.
public protocol AppExportImporting {
    /// Best-effort sniff: returns true if the importer thinks `data`
    /// is in the format it understands.
    static func canImport(_ data: Data) -> Bool
    /// Decodes `data` into an `AppExport` or throws.
    static func makeAppExport(from data: Data, fileName: String) throws -> AppExport
}

extension AppExportDecoder: AppExportImporting {
    /// The decoder is the terminal step in the loader chain — it tries to
    /// parse anything that smells like a JSON object. Conservatively accept
    /// any non-empty payload that begins with `{` or `[`.
    public static func canImport(_ data: Data) -> Bool {
        guard let first = data.first(where: { !($0 == 0x20 || $0 == 0x09 || $0 == 0x0A || $0 == 0x0D) }) else {
            return false
        }
        return first == UInt8(ascii: "{") || first == UInt8(ascii: "[")
    }

    public static func makeAppExport(from data: Data, fileName _: String) throws -> AppExport {
        try decode(data: data)
    }
}

