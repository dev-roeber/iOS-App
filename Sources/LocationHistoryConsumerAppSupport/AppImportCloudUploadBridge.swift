import Foundation

/// Brücke zwischen dem `LH2GPXAppFlow`-Import-Pfad und der CloudKit-
/// Auto-Upload-Pipeline.
///
/// Der Flow hat statische Funktionen ohne Zugriff auf `AppPreferences`
/// oder `CloudFileManaging`. Damit wir nach erfolgreichem Import die
/// Original-Datei optional in iCloud sichern können, registriert die
/// App beim Start einen `handler`-Closure. Der Closure bekommt die URL
/// und entscheidet selbst, ob hochgeladen wird (Toggle-Gate, Wi-Fi-Gate,
/// SHA-256-Dedupe via `CloudFileManaging.upload`).
public enum AppImportCloudUploadBridge {
    public typealias Handler = @Sendable (URL) -> Void

    /// Wird beim App-Start gesetzt. Default ist `nil` — dann passiert
    /// nichts (sicherer Default, kein impliziter Cloud-Upload).
    public nonisolated(unsafe) static var handler: Handler?

    /// Triggert den registrierten Handler. Idempotent ohne Handler.
    public static func handle(importedFile url: URL) {
        handler?(url)
    }
}
