import Foundation
#if canImport(OSLog)
import OSLog
#endif

/// Loggt Fehler aus dem Import-Auto-Upload-Pfad. Wird vom AppShellRootView-
/// Handler nach einem fehlgeschlagenen CloudKit-Upload aufgerufen. Da der
/// Auto-Upload bewusst „silent" ist (kein UI-Banner), brauchen wir
/// wenigstens einen Console.app-Hinweis pro Failure.
public enum AppImportCloudUploadLogger {
    #if canImport(OSLog)
    private static let logger = Logger(
        subsystem: "de.roeber.LH2GPXWrapper",
        category: "import.autoUpload"
    )
    #endif

    public static func log(error: Error, url: URL) {
        #if canImport(OSLog)
        let ns = error as NSError
        let domain = ns.domain
        let code = ns.code
        let description = ns.localizedDescription
        let name = url.lastPathComponent
        logger.error("Auto-Upload fehlgeschlagen für \(name, privacy: .public): domain=\(domain, privacy: .public) code=\(code, privacy: .public) desc=\(description, privacy: .public)")
        #endif
    }
}
