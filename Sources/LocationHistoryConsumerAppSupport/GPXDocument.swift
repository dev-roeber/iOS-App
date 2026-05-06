#if canImport(SwiftUI) && canImport(UniformTypeIdentifiers)
import SwiftUI
import UniformTypeIdentifiers

// GPX is a registered public UTType on Apple platforms (com.topografix.gpx).
// Falling back to .xml ensures the file is never unreadable.
public extension UTType {
    static var gpx: UTType {
        UTType(filenameExtension: "gpx") ?? .xml
    }

    static var kml: UTType {
        UTType(filenameExtension: "kml") ?? .xml
    }

    static var geoJSON: UTType {
        UTType(filenameExtension: "geojson") ?? .json
    }

    static var tcx: UTType {
        UTType(filenameExtension: "tcx") ?? .xml
    }

    static var kmz: UTType {
        UTType(filenameExtension: "kmz") ?? .zip
    }
}

/// A write-only `FileDocument` wrapper for export content.
///
/// Carries raw `Data` so a single `.fileExporter` modifier can serve all
/// export formats (GPX, KML, GeoJSON, CSV, KMZ). Stacking two `.fileExporter`
/// modifiers on the same view hierarchy is unreliable in SwiftUI — one of
/// the two presentations may be silently swallowed. Routing every format
/// through this type lets the call site present a single exporter.
struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.gpx, .kml, .geoJSON, .csv, .kmz] }

    let data: Data
    let suggestedFilename: String

    init(data: Data, suggestedFilename: String) {
        self.data = data
        self.suggestedFilename = suggestedFilename
    }

    init(content: String, suggestedFilename: String) {
        self.data = content.data(using: .utf8) ?? Data()
        self.suggestedFilename = suggestedFilename
    }

    /// Required by the protocol; documents are write-only in this app.
    init(configuration: ReadConfiguration) throws {
        guard let fileData = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = fileData
        self.suggestedFilename = "import.xml"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
#endif
