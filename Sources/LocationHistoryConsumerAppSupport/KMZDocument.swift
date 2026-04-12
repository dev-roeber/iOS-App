#if canImport(SwiftUI) && canImport(UniformTypeIdentifiers)
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var kmz: UTType {
        UTType(filenameExtension: "kmz") ?? .zip
    }
}

/// A write-only binary FileDocument for KMZ export.
struct KMZExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.kmz] }

    let data: Data
    let suggestedFilename: String

    init(data: Data, suggestedFilename: String) {
        self.data = data
        self.suggestedFilename = suggestedFilename
    }

    init(configuration: ReadConfiguration) throws {
        guard let fileData = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = fileData
        self.suggestedFilename = "import.kmz"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
#endif
