import Foundation
#if canImport(UIKit)
import UIKit
#endif

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

/// Synchron aufgerufener Staging-Helper für den Import-Auto-Upload-Pfad.
///
/// Hintergrund: Der `AppImportCloudUploadBridge.handler` läuft in einem
/// `Task { @MainActor in ... }`-Closure, der erst nach Rückkehr aus dem
/// Import-Flow ausgeführt wird. Zu diesem Zeitpunkt ist der
/// security-scoped Zugriff der ursprünglichen iCloud-Drive- / File-
/// Provider-URL längst freigegeben — ein `FileManager.copyItem` schlägt
/// dann mit `NSFileReadNoPermissionError` fehl.
///
/// `stage(sourceURL:)` muss daher **synchron** vom Import-Pfad
/// aufgerufen werden, solange dessen Security-Scope noch aktiv ist. Die
/// gestagete URL ist app-owned (liegt unter `temporaryDirectory`) und
/// kann später ohne Scope-Garantie weiterverwendet werden.
public enum AppImportCloudUploadStaging {

    /// Kopiert `sourceURL` in ein frisches Staging-Unterverzeichnis von
    /// `FileManager.default.temporaryDirectory` und gibt die app-eigene
    /// Ziel-URL zurück. Nutzt — wenn verfügbar —
    /// `NSFileCoordinator(...).coordinate(readingItemAt:options:[.forUploading, .withoutChanges])`,
    /// damit File-Provider-Materialisierung stabil triggert. Fällt auf
    /// `FileManager.copyItem` zurück (Linux / Targets ohne UIKit).
    public static func stage(sourceURL: URL) throws -> URL {
        let stagingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImportAutoUploadStaging-\(UUID().uuidString)",
                                    isDirectory: true)
        try FileManager.default.createDirectory(at: stagingDir,
                                                withIntermediateDirectories: true)
        let destination = stagingDir.appendingPathComponent(sourceURL.lastPathComponent)

        #if canImport(UIKit)
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessed { sourceURL.stopAccessingSecurityScopedResource() } }

        var coordError: NSError?
        var copyError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(
            readingItemAt: sourceURL,
            options: [.forUploading, .withoutChanges],
            error: &coordError
        ) { readableURL in
            do {
                try FileManager.default.copyItem(at: readableURL, to: destination)
            } catch {
                copyError = error
            }
        }
        if let coordError {
            try? FileManager.default.removeItem(at: stagingDir)
            throw coordError
        }
        if let copyError {
            try? FileManager.default.removeItem(at: stagingDir)
            throw copyError
        }
        #else
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: stagingDir)
            throw error
        }
        #endif

        return destination
    }

    /// Entfernt das Staging-Unterverzeichnis, in dem `stagedURL` liegt.
    /// Fehler werden absichtlich geschluckt — Aufräumen darf einen
    /// erfolgreichen Upload nicht nachträglich „failen" lassen.
    public static func cleanup(stagedURL: URL) {
        let directory = stagedURL.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: directory)
    }
}
