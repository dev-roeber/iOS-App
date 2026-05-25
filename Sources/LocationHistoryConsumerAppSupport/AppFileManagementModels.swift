import Foundation

/// Prompt 1 — Datei-Tab Modelle. Beschreiben einen lokalen Datei-Eintrag,
/// seine Klassifizierung und den Bucket (Documents/Imports/Caches),
/// in dem er liegt. Foundation-only, damit `swift test` auf Linux läuft.

public enum LocalFileKind: String, Codable, CaseIterable, Sendable {
    case gpx
    case kml
    case kmz
    case zip
    case json
    case csv
    case sqlite
    case other

    public static func from(filename: String) -> LocalFileKind {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "gpx": return .gpx
        case "kml": return .kml
        case "kmz": return .kmz
        case "zip": return .zip
        case "json": return .json
        case "csv": return .csv
        case "sqlite", "sqlite-wal", "sqlite-shm", "db": return .sqlite
        default: return .other
        }
    }

    public var germanLabel: String {
        switch self {
        case .gpx: return "GPX-Track"
        case .kml: return "KML-Track"
        case .kmz: return "KMZ-Paket"
        case .zip: return "ZIP-Archiv"
        case .json: return "JSON-Datei"
        case .csv: return "CSV-Tabelle"
        case .sqlite: return "Datenbank"
        case .other: return "Datei"
        }
    }
}

public enum LocalFileBucket: String, Codable, CaseIterable, Sendable {
    case exports
    case imports
    case favorites
    case caches

    public var germanTitle: String {
        switch self {
        case .exports: return "Exporte"
        case .imports: return "Importe"
        case .favorites: return "Favoriten"
        case .caches: return "Zwischenspeicher"
        }
    }

    public var germanCaption: String {
        switch self {
        case .exports: return "Vom Nutzer exportierte Dateien im Documents-Ordner."
        case .imports: return "Importierte Quelldateien und lokale Timeline-Datenbank."
        case .favorites: return "Lokale Favoriten-Persistenz."
        case .caches: return "Regenerierbare Render- und Tile-Caches."
        }
    }
}

public struct LocalFileEntry: Identifiable, Equatable, Sendable {
    public let id: String
    public let url: URL
    public let fileName: String
    public let sizeBytes: Int64
    public let modifiedAt: Date?
    public let kind: LocalFileKind
    public let bucket: LocalFileBucket

    public init(id: String,
                url: URL,
                fileName: String,
                sizeBytes: Int64,
                modifiedAt: Date?,
                kind: LocalFileKind,
                bucket: LocalFileBucket) {
        self.id = id
        self.url = url
        self.fileName = fileName
        self.sizeBytes = sizeBytes
        self.modifiedAt = modifiedAt
        self.kind = kind
        self.bucket = bucket
    }
}

public struct LocalFileBucketSnapshot: Equatable, Sendable {
    public let bucket: LocalFileBucket
    public let entries: [LocalFileEntry]
    public let totalSizeBytes: Int64

    public init(bucket: LocalFileBucket, entries: [LocalFileEntry], totalSizeBytes: Int64) {
        self.bucket = bucket
        self.entries = entries
        self.totalSizeBytes = totalSizeBytes
    }
}

/// Foundation-only Byte-Formatter. Vermeidet Plattform-spezifisches
/// `ByteCountFormatter` in den Tests (Linux Foundation unvollständig).
public enum LocalFileSizeFormatter {
    public static func germanString(forBytes bytes: Int64) -> String {
        let absBytes = Double(max(bytes, 0))
        let units: [(Double, String)] = [
            (1_073_741_824, "GB"),
            (1_048_576, "MB"),
            (1_024, "KB"),
        ]
        for (divisor, suffix) in units where absBytes >= divisor {
            let value = absBytes / divisor
            return String(format: "%.1f %@", value, suffix).replacingOccurrences(of: ".", with: ",")
        }
        return "\(Int(absBytes)) B"
    }
}
