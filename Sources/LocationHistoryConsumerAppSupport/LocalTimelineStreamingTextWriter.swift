import Foundation

/// Phase-5 Streaming-Writer: schreibt UTF-8-Text inkrementell in eine Datei.
///
/// Der Writer existiert, damit Format-Emitter (GPX/KML/GeoJSON/CSV) ihre
/// Ausgabe sofort auf die Platte streamen können, ohne den vollständigen
/// Export jemals als String im RAM zu halten. Ziel ist explizit der Pfad
/// `ExportStaging/<uuid>/export.<ext>`.
///
/// **Robustheit:**
/// - Parent-Directory wird idempotent angelegt.
/// - Ein bereits existierendes Ziel wird überschrieben (Truncate-Open).
/// - `bytesWritten` zählt UTF-8-Bytes; passt zu Datei-Größe nach `finalize()`.
/// - `finalize()` schließt das FileHandle. Mehrfachaufruf ist idempotent.
public final class LocalTimelineStreamingTextWriter {

    public enum WriterError: Error, Equatable, CustomStringConvertible {
        case directoryCreationFailed(path: String, message: String)
        case fileCreationFailed(path: String, message: String)
        case writeFailed(path: String, message: String)
        case alreadyClosed(path: String)

        public var description: String {
            switch self {
            case let .directoryCreationFailed(p, m):
                return "directoryCreationFailed(path: \(p), message: \(m))"
            case let .fileCreationFailed(p, m):
                return "fileCreationFailed(path: \(p), message: \(m))"
            case let .writeFailed(p, m):
                return "writeFailed(path: \(p), message: \(m))"
            case let .alreadyClosed(p):
                return "alreadyClosed(path: \(p))"
            }
        }
    }

    public let outputURL: URL
    public private(set) var bytesWritten: Int = 0
    public private(set) var isClosed: Bool = false

    private var handle: FileHandle?

    public init(outputURL: URL, fileManager: FileManager = .default) throws {
        self.outputURL = outputURL

        let parent = outputURL.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        } catch {
            throw WriterError.directoryCreationFailed(path: parent.path,
                                                      message: error.localizedDescription)
        }

        // Truncate-create. Wenn die Datei existiert, wird sie überschrieben.
        if fileManager.fileExists(atPath: outputURL.path) {
            try? fileManager.removeItem(at: outputURL)
        }
        guard fileManager.createFile(atPath: outputURL.path, contents: nil) else {
            throw WriterError.fileCreationFailed(path: outputURL.path,
                                                 message: "createFile returned false")
        }

        do {
            self.handle = try FileHandle(forWritingTo: outputURL)
        } catch {
            throw WriterError.fileCreationFailed(path: outputURL.path,
                                                 message: error.localizedDescription)
        }
    }

    /// Schreibt `string` als UTF-8 inkrementell in die Datei.
    public func write(_ string: String) throws {
        guard let handle else {
            throw WriterError.alreadyClosed(path: outputURL.path)
        }
        guard !string.isEmpty else { return }
        let data = Data(string.utf8)
        do {
            try handle.write(contentsOf: data)
            bytesWritten += data.count
        } catch {
            throw WriterError.writeFailed(path: outputURL.path,
                                          message: error.localizedDescription)
        }
    }

    /// Schließt die Datei. Idempotent.
    public func finalize() throws {
        guard let handle else { return }
        do {
            try handle.synchronize()
            try handle.close()
        } catch {
            throw WriterError.writeFailed(path: outputURL.path,
                                          message: error.localizedDescription)
        }
        self.handle = nil
        self.isClosed = true
    }

    deinit {
        try? handle?.close()
    }
}
