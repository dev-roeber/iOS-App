#if canImport(SwiftUI) && canImport(UniformTypeIdentifiers)
import SwiftUI
import UniformTypeIdentifiers

// GPX is a registered public UTType on Apple platforms (com.topografix.gpx).
// Falling back to .xml ensures the file is never unreadable.
extension UTType {
    static var gpx: UTType {
        UTType(filenameExtension: "gpx") ?? .xml
    }

    static var kml: UTType {
        UTType(filenameExtension: "kml") ?? .xml
    }

    static var geoJSON: UTType {
        UTType(filenameExtension: "geojson") ?? .json
    }
}

/// A write-only `FileDocument` wrapper for XML-based export content.
///
/// Used with SwiftUI's `.fileExporter` modifier to let the user save or share
/// an export file via the system share sheet / Files app.
struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.gpx, .kml, .geoJSON, .csv] }

    let content: String
    let suggestedFilename: String

    init(content: String, suggestedFilename: String) {
        self.content = content
        self.suggestedFilename = suggestedFilename
    }

    /// Required by the protocol; GPX documents are write-only in this app.
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.content = text
        self.suggestedFilename = "import.xml"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = content.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}
#endif
