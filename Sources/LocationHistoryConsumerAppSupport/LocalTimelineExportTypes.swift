import Foundation

/// Phase-5 Export-Zielmodell für den Store-backed Streaming-Export.
///
/// Diese Typen sind bewusst Foundation-only und UI-frei. Sie beschreiben,
/// *was* aus dem `LocalTimelineStore` heraus exportiert werden soll, ohne
/// jemals einen vollständigen `AppExport` im RAM zu materialisieren oder
/// einen kompletten `[Double]`-Coordinate-Buffer für einen ganzen Import
/// aufzubauen.
///
/// **Scope-Grenzen (s. Phase-5-Brief):**
///
/// - kein UI-Hook
/// - kein App-Session-Switch
/// - kein Map-Hook
/// - keine vollständige `AppExport`-Rekonstruktion aus dem Store
/// - kein vollständiger Export-String im RAM
public enum LocalTimelineExportFormat: String, CaseIterable, Equatable {
    case gpx
    case kml
    case geoJSON
    case csv

    /// Datei-Extension ohne führenden Punkt.
    public var fileExtension: String {
        switch self {
        case .gpx: return "gpx"
        case .kml: return "kml"
        case .geoJSON: return "geojson"
        case .csv: return "csv"
        }
    }

    /// Maschinenlesbarer Format-Hinweis für Diagnose-Logs / Tests.
    public var diagnosticName: String {
        switch self {
        case .gpx: return "gpx"
        case .kml: return "kml"
        case .geoJSON: return "geojson"
        case .csv: return "csv"
        }
    }
}

/// Beschreibt, *welche* Teile eines Imports exportiert werden sollen.
///
/// `dateRange` und `dayIds` sind beide optional und additiv-restriktiv:
/// fehlt beides, gilt der gesamte Import. Sind beide gesetzt, müssen
/// Days *beide* Filter passieren.
///
/// `includeVisits`/`includeActivities`/`includePaths` steuern, welche
/// Entitätstypen im Output landen. Default: alle drei `true`.
public struct LocalTimelineExportSelection: Equatable {

    public let importID: String
    public let dateRange: ClosedRange<String>?
    public let dayIds: [String]?
    public let includeVisits: Bool
    public let includeActivities: Bool
    public let includePaths: Bool

    public init(importID: String,
                dateRange: ClosedRange<String>? = nil,
                dayIds: [String]? = nil,
                includeVisits: Bool = true,
                includeActivities: Bool = true,
                includePaths: Bool = true) {
        self.importID = importID
        self.dateRange = dateRange
        self.dayIds = dayIds
        self.includeVisits = includeVisits
        self.includeActivities = includeActivities
        self.includePaths = includePaths
    }
}

/// Ergebnis eines erfolgreichen Store-backed Exports.
///
/// Die Zähler sind genau die im Output materialisierten Entitäten — also
/// nach Anwendung von Selection und `include*`-Flags.
public struct LocalTimelineExportResult: Equatable {

    public let outputURL: URL
    public let format: LocalTimelineExportFormat
    public let bytesWritten: Int
    public let dayCount: Int
    public let pathCount: Int
    public let visitCount: Int
    public let activityCount: Int
    public let pointCount: Int

    public init(outputURL: URL,
                format: LocalTimelineExportFormat,
                bytesWritten: Int,
                dayCount: Int,
                pathCount: Int,
                visitCount: Int,
                activityCount: Int,
                pointCount: Int) {
        self.outputURL = outputURL
        self.format = format
        self.bytesWritten = bytesWritten
        self.dayCount = dayCount
        self.pathCount = pathCount
        self.visitCount = visitCount
        self.activityCount = activityCount
        self.pointCount = pointCount
    }
}

/// Fehlerklassen des Phase-5-Exports.
public enum LocalTimelineExportError: Error, Equatable, CustomStringConvertible {
    /// Der angegebene Import existiert nicht im Store.
    case unknownImport(importID: String)
    /// Die Selection enthält keine Days (z. B. dayIds liefern keinen Treffer
    /// im Import). Phase 5 entscheidet sich gegen einen "leeren OK"-Output:
    /// die Auswahl ist explizit Fehler. Tests dokumentieren das.
    case emptySelection(importID: String)
    /// `coord_blob` für einen Pfad ist defekt; Iterator hat geworfen.
    case malformedCoordBlob(pathID: String, message: String)
    /// I/O-Fehler beim Schreiben in `ExportStaging/`.
    case ioFailure(path: String, message: String)
    /// Underlying Reader/Store hat geworfen.
    case readerFailure(message: String)

    public var description: String {
        switch self {
        case let .unknownImport(id):
            return "unknownImport(importID: \(id))"
        case let .emptySelection(id):
            return "emptySelection(importID: \(id))"
        case let .malformedCoordBlob(path, message):
            return "malformedCoordBlob(pathID: \(path), message: \(message))"
        case let .ioFailure(path, message):
            return "ioFailure(path: \(path), message: \(message))"
        case let .readerFailure(message):
            return "readerFailure(message: \(message))"
        }
    }
}
