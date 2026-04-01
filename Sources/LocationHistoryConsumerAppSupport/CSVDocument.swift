#if canImport(SwiftUI) && canImport(UniformTypeIdentifiers)
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var csv: UTType {
        UTType("public.comma-separated-values-text") ?? .plainText
    }
}

/// A write-only `FileDocument` wrapper for CSV export content.
///
/// Used with SwiftUI's `.fileExporter` modifier to let the user save a CSV file.
struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.csv] }

    let content: String
    let suggestedFilename: String

    init(content: String, suggestedFilename: String) {
        self.content = content
        self.suggestedFilename = suggestedFilename
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.content = text
        self.suggestedFilename = "import.csv"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = content.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}
#endif
