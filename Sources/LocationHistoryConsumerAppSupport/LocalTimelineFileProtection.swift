import Foundation

/// Phase-4 FileProtection-Kapselung für den LocalTimelineStore.
///
/// **Ziel auf iOS:** der Produkt-Pfad soll später Data Protection
/// `.completeUnlessOpen` setzen (entspricht
/// `NSFileProtectionCompleteUnlessOpen` bzw. dem SQLite-Open-Flag
/// `SQLITE_OPEN_FILEPROTECTION_COMPLETEUNLESSOPEN`). Diese Kapselung
/// stellt die API bereit, hält den Linux-Build grün und dokumentiert,
/// dass die finale iOS-Verdrahtung Bestandteil des Darwin-/iOS-Rollouts
/// bleibt.
///
/// **Auf Linux** ist alles ein bewusster No-Op: Data Protection ist ein
/// Apple-only Konzept; der Build darf nicht brechen, das Verhalten ist
/// dokumentiert.
///
/// **Achtung:** Phase 4 setzt nirgends ein `.completeUnlessOpen` an einer
/// echten Datei. Die Helper signalisieren nur "an dieser Stelle wäre
/// FileProtection zu setzen" und liefern eine maschinenlesbare
/// `defaultProtectionDescription`. Die echte Anwendung (sowohl per
/// `URLResourceKey` als auch per SQLite-Open-Flag) muss im Darwin-/iOS-
/// Rollout-Schritt erfolgen, sobald die App-Session den Store nutzt.
public enum LocalTimelineFileProtection {

    public enum ProtectionError: Error, Equatable, CustomStringConvertible {
        /// Pfad existiert nicht — `applyDefaultProtection` ist konservativ
        /// und akzeptiert nur existierende Dateien/Verzeichnisse.
        case fileNotFound(path: String)

        public var description: String {
            switch self {
            case let .fileNotFound(path):
                return "fileNotFound(path: \(path))"
            }
        }
    }

    /// Maschinenlesbare Beschreibung des Default-Protection-Targets.
    /// Wird in Diagnose-Logs und in Tests benutzt, damit der iOS-Rollout
    /// gegen einen stabilen Wert prüfen kann.
    public static var defaultProtectionDescription: String {
        #if canImport(Darwin)
        return "completeUnlessOpen (Darwin target — actual flag application deferred to iOS rollout)"
        #else
        return "noop-linux"
        #endif
    }

    /// Wendet die Default-FileProtection auf `url` an, soweit auf der
    /// Plattform sinnvoll möglich.
    ///
    /// - **Linux:** No-Op, wirft nur, wenn `url` nicht existiert.
    /// - **Darwin:** Phase 4 markiert die Stelle, an der iOS später
    ///   `NSFileProtectionCompleteUnlessOpen` setzen wird. Das echte
    ///   Setzen über `FileManager.setAttributes([.protectionKey: ...])`
    ///   bzw. `SQLITE_OPEN_FILEPROTECTION_COMPLETEUNLESSOPEN` bleibt
    ///   absichtlich auskommentiert / dokumentiert, weil der Linux-CI-
    ///   Build keine `FileAttributeKey.protectionKey`-Symbole hat und
    ///   Phase 4 keinen Hardware-Pass behauptet.
    public static func applyDefaultProtection(to url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ProtectionError.fileNotFound(path: url.path)
        }
        #if canImport(Darwin)
        // iOS-Rollout-Pflicht — Hook bleibt absichtlich passiv:
        //
        //     try FileManager.default.setAttributes(
        //         [.protectionKey: FileProtectionType.completeUnlessOpen],
        //         ofItemAtPath: url.path
        //     )
        //
        // Wird im Darwin-/iOS-Schritt aktiviert, sobald die App-Session
        // den Store wirklich öffnet. Bis dahin: Stelle dokumentiert,
        // Linux-Build grün, kein Hardware-Anspruch erhoben.
        _ = url
        #else
        _ = url
        #endif
    }

    /// Bequeme Variante für mehrere URLs. Nicht-existierende Pfade werden
    /// still übersprungen, damit die Factory den Helper nach
    /// `ensureDirectoriesExist` idempotent aufrufen kann.
    public static func applyDefaultProtectionIfPresent(urls: [URL]) throws {
        let fm = FileManager.default
        for url in urls where fm.fileExists(atPath: url.path) {
            try applyDefaultProtection(to: url)
        }
    }
}
