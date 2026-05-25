import Foundation

/// File-basierter Store für die LiveTrack-CloudKit-Outbox.
///
/// Ersetzt den `UserDefaultsLiveTrackCloudBackupQueueStore` als Default-
/// Persistenz für `LiveTrackCloudBackupService`. Der ältere Store bleibt
/// nur noch für Backwards-Compat und für die einmalige Migration der
/// bereits in `UserDefaults` abgelegten Outbox bestehen.
///
/// **Speicherort (Produktion, Apple):**
/// `Application Support/LocationHistory2GPX/CloudOutbox/livetrack_queue.json`
///
/// **Eigenschaften:**
/// - Atomarer Write via `Data.write(to:options:[.atomic])`.
/// - Daten-Protection (`completeUnlessOpen` auf iOS-Familie) über
///   `LocalTimelineFileProtection.applyDefaultProtectionIfPresent`.
/// - Backup-Exclusion (`isExcludedFromBackupKey = true` auf Darwin) via
///   `LocalTimelineFileAttributes.markExcludedFromBackupIfPresent`.
/// - Migration: liest beim ersten `loadEnvelopes()` einmalig die
///   vorhandene UserDefaults-Outbox und persistiert sie als Datei. Der
///   UserDefaults-Eintrag wird anschließend entfernt; ein Marker
///   (`app.icloud.liveTrackBackup.fileMigration.v1 = true`) sorgt für
///   Idempotenz.
/// - Threading: Datei-IO ist synchron und durch ein `NSLock` serialisiert.
public final class LiveTrackCloudBackupFileQueueStore: LiveTrackCloudBackupQueueStoring {

    /// Schlüssel der Legacy-UserDefaults-Outbox. Muss mit dem Default-Key
    /// in `UserDefaultsLiveTrackCloudBackupQueueStore` übereinstimmen.
    public static let legacyUserDefaultsKey = "app.icloud.liveTrackBackup.queue"
    /// Marker für die Idempotenz der einmaligen Migration.
    public static let migrationMarkerKey = "app.icloud.liveTrackBackup.fileMigration.v1"

    private let fileURL: URL
    private let userDefaults: UserDefaults
    private let lock = NSLock()

    /// Initialisiert den Store. Bei `fileURL == nil` wird der Default-
    /// Pfad unter Application Support angelegt. Schlägt der Pfad-
    /// Resolver fehl (z. B. weil Application Support nicht zugreifbar
    /// ist), wird auf einen eindeutigen `tmp`-Pfad zurückgefallen, damit
    /// die App nicht crasht (analog `FavoriteEntryStore.makeInMemoryFallback`).
    public init(fileURL: URL? = nil, userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let provided = fileURL {
            self.fileURL = provided
        } else {
            self.fileURL = Self.resolveDefaultFileURLOrFallback()
        }
        // Verzeichnis idempotent anlegen und Protection/Backup-Flag
        // setzen, soweit auf der Plattform sinnvoll möglich.
        let directory = self.fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? LocalTimelineFileProtection.applyDefaultProtectionIfPresent(urls: [directory])
        try? LocalTimelineFileAttributes.markExcludedFromBackupIfPresent(urls: [directory])
    }

    // MARK: - LiveTrackCloudBackupQueueStoring

    public func loadEnvelopes() -> [LiveTrackCloudBackupEnvelope] {
        lock.lock()
        defer { lock.unlock() }

        let fm = FileManager.default
        let fileExists = fm.fileExists(atPath: fileURL.path)

        // Migration: nur einmalig, falls Marker noch nicht gesetzt und
        // noch keine File-Variante existiert.
        let alreadyMigrated = userDefaults.bool(forKey: Self.migrationMarkerKey)
        if !fileExists && !alreadyMigrated {
            if let legacyData = userDefaults.data(forKey: Self.legacyUserDefaultsKey),
               let decoded = try? Self.makeDecoder().decode(
                    [LiveTrackCloudBackupEnvelope].self, from: legacyData
               ) {
                // Persistiere migrierte Envelopes als File, dann lösche
                // den Legacy-Key und setze den Idempotenz-Marker.
                writeLocked(envelopes: decoded)
                userDefaults.removeObject(forKey: Self.legacyUserDefaultsKey)
                userDefaults.set(true, forKey: Self.migrationMarkerKey)
                return decoded
            }
            // Keine Legacy-Daten gefunden — Migration trotzdem als
            // erledigt markieren, damit nachfolgende Reads den Pfad
            // überspringen.
            userDefaults.set(true, forKey: Self.migrationMarkerKey)
            return []
        }

        guard fileExists else { return [] }
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? Self.makeDecoder().decode(
                  [LiveTrackCloudBackupEnvelope].self, from: data
              )
        else {
            return []
        }
        return decoded
    }

    public func saveEnvelopes(_ envelopes: [LiveTrackCloudBackupEnvelope]) {
        lock.lock()
        defer { lock.unlock() }
        writeLocked(envelopes: envelopes)
    }

    // MARK: - Private

    private func writeLocked(envelopes: [LiveTrackCloudBackupEnvelope]) {
        let fm = FileManager.default
        if envelopes.isEmpty {
            // Analog zur UserDefaults-Variante: leere Liste löscht die
            // Datei, damit der Outbox-Zustand "leer" persistent wird.
            try? fm.removeItem(at: fileURL)
            return
        }
        guard let data = try? Self.makeEncoder().encode(envelopes) else { return }
        let directory = fileURL.deletingLastPathComponent()
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            try data.write(to: fileURL, options: Data.WritingOptions.atomic)
        } catch {
            return
        }
        // Protection/Backup-Flag idempotent nachziehen.
        try? LocalTimelineFileProtection.applyDefaultProtectionIfPresent(urls: [fileURL])
        try? LocalTimelineFileAttributes.markExcludedFromBackupIfPresent(urls: [fileURL])
    }

    // MARK: - Codec helpers

    /// Spiegelbild von `JSONEncoder.liveTrackCloud` (fileprivate in
    /// `ICloudCloudKitMVP.swift`). Lokal dupliziert, damit dieser Store
    /// in einer eigenen Datei lebt, ohne die Sichtbarkeit dort zu ändern.
    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - Path resolution

    private static let projectFolder = "LocationHistory2GPX"
    private static let subFolder = "CloudOutbox"
    private static let fileName = "livetrack_queue.json"

    /// Canonical disk path under Application Support.
    public static func defaultFileURL(fileManager: FileManager = .default) throws -> URL {
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupport
            .appendingPathComponent(projectFolder, isDirectory: true)
            .appendingPathComponent(subFolder, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }

    private static func resolveDefaultFileURLOrFallback() -> URL {
        if let url = try? defaultFileURL() { return url }
        // Fallback analog `FavoriteEntryStore.makeInMemoryFallback`: tmp.
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("LiveTrackCloudBackupFileQueueStore-fallback-\(UUID().uuidString).json")
    }
}
