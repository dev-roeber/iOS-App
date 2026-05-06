import Foundation
import ZIPFoundation
import LocationHistoryConsumer

/// Builds KMZ archives (zipped KML) from Day arrays.
public enum KMZBuilder {
    public static func build(from days: [Day], mode: ExportMode = .tracks) throws -> Data {
        let kmlString = KMLBuilder.build(from: days, mode: mode)
        guard let kmlData = kmlString.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".kmz")
        defer { try? FileManager.default.removeItem(at: tmpURL) }
        let archive = try Archive(url: tmpURL, accessMode: .create)
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
        return try Data(contentsOf: tmpURL)
    }
}
