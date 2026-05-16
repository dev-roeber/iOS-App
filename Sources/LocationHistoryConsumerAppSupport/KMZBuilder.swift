import Foundation
import ZIPFoundation
import LocationHistoryConsumer

/// Builds KMZ archives (zipped KML) from Day arrays.
///
/// Train E1 (2026-05-16): Uses ZIPFoundation's in-memory archive backing
/// (`Archive(data:, accessMode: .create)` + `archive.data`) instead of writing
/// the KMZ to `temporaryDirectory` and reading it back via `Data(contentsOf:)`.
/// This removes the temp-file write and the final full-buffer re-read; the
/// KML payload buffer is still required because ZIPFoundation's `provider`
/// callback may request arbitrary ranges. Public API + output bytes unchanged.
public enum KMZBuilder {
    public static func build(from days: [Day], mode: ExportMode = .tracks) throws -> Data {
        let kmlString = KMLBuilder.build(from: days, mode: mode)
        guard let kmlData = kmlString.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        let archive = try Archive(accessMode: .create)
        try archive.addEntry(
            with: "doc.kml",
            type: .file,
            uncompressedSize: Int64(kmlData.count),
            provider: { position, size in
                // Bounds-Guard: schützt vor NSException aus `subdata`, falls
                // ZIPFoundation jemals einen ungültigen (position, size) liefert.
                let count = kmlData.count
                var start = Int(position)
                start = max(0, min(start, count))
                let end = min(start + size, count)
                if start >= end { return Data() }
                return kmlData.subdata(in: start..<end)
            }
        )
        guard let data = archive.data else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }
}
