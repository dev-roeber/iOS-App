import Foundation
#if canImport(Combine)
import Combine
#endif

public enum CloudFilesActionState: String, Sendable {
    case idle
    case refreshing
    case selecting
    case uploading
    case downloading
    case deleting
}

public struct CloudFileStatusSummary: Equatable, Sendable {
    public let isCloudAvailable: Bool
    public let lastRefreshAt: Date?
    public let localCount: Int
    public let cloudCount: Int
    public let pendingCount: Int

    public init(isCloudAvailable: Bool,
                lastRefreshAt: Date?,
                localCount: Int,
                cloudCount: Int,
                pendingCount: Int) {
        self.isCloudAvailable = isCloudAvailable
        self.lastRefreshAt = lastRefreshAt
        self.localCount = localCount
        self.cloudCount = cloudCount
        self.pendingCount = pendingCount
    }
}

#if canImport(Combine)
@MainActor
public final class AppCloudFileViewModel: ObservableObject {
    @Published public private(set) var cloudEntries: [CloudFileEntry] = []
    @Published public private(set) var pendingUploads: [CloudFileUploadCandidate] = []
    @Published public private(set) var actionState: CloudFilesActionState = .idle
    @Published public private(set) var actionMessage: String?
    @Published public private(set) var actionFailed: Bool = false
    @Published public private(set) var lastRefreshAt: Date?
    @Published public private(set) var isCloudAvailable: Bool

    private let manager: CloudFileManaging
    private let isEnabled: @Sendable () -> Bool
    private let isCloudAvailableProvider: @Sendable () -> Bool

    public init(manager: CloudFileManaging,
                isEnabled: @escaping @Sendable () -> Bool = { true },
                isCloudAvailable: @escaping @Sendable () -> Bool = { true }) {
        self.manager = manager
        self.isEnabled = isEnabled
        self.isCloudAvailableProvider = isCloudAvailable
        self.isCloudAvailable = isCloudAvailable()
    }

    public func statusSummary(localCount: Int) -> CloudFileStatusSummary {
        CloudFileStatusSummary(
            isCloudAvailable: isCloudAvailable,
            lastRefreshAt: lastRefreshAt,
            localCount: localCount,
            cloudCount: cloudEntries.count,
            pendingCount: pendingUploads.count
        )
    }

    public var canUpload: Bool {
        isEnabled() && isCloudAvailable && actionState == .idle
    }

    public func refreshCloudFiles() async {
        guard actionState == .idle else { return }
        actionState = .refreshing
        actionFailed = false
        actionMessage = nil
        isCloudAvailable = isCloudAvailableProvider()
        guard isEnabled(), isCloudAvailable else {
            actionFailed = true
            actionMessage = "iCloud ist nicht erreichbar oder Datei-Upload ist deaktiviert."
            actionState = .idle
            return
        }
        do {
            let manager = self.manager
            let entries = try await manager.listCloudFiles()
            cloudEntries = entries
            lastRefreshAt = Date()
            actionMessage = "Cloud-Dateien aktualisiert."
        } catch {
            actionFailed = true
            actionMessage = error.localizedDescription
        }
        actionState = .idle
    }

    public func uploadPickedFile(at url: URL) async {
        // Fix B1: Security-Scope MUSS auf MainActor + auf der gleichen
        // Task-Hierarchie wie die Datei-Read-Calls aktiv sein.
        // `Task.detached` verliert den Scope. Wir kopieren die Datei
        // jetzt SOFORT in das App-eigene tmp-Verzeichnis (Foundation-
        // copy respektiert den noch aktiven Scope) und hashen +
        // uploaden danach von der Kopie — dort braucht es keinen
        // Security-Scope mehr.
        actionFailed = false
        actionMessage = nil
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CloudFileUpload-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
            let copy = tmpDir.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.copyItem(at: url, to: copy)
            await uploadCandidate {
                try CloudFileCandidateFactory.makeCandidate(for: copy)
            }
            try? FileManager.default.removeItem(at: tmpDir)
        } catch {
            actionFailed = true
            actionMessage = "Datei konnte nicht eingelesen werden: \(error.localizedDescription)"
            try? FileManager.default.removeItem(at: tmpDir)
        }
    }

    public func uploadLocalEntry(_ entry: LocalFileEntry) async {
        await uploadCandidate {
            try CloudFileCandidateFactory.makeCandidate(for: entry)
        }
    }

    // Fix B-Neu2: fileImporter-Fehler werden jetzt sichtbar.
    public func reportPickerFailure(_ error: Error) {
        actionFailed = true
        actionMessage = "Datei-Auswahl fehlgeschlagen: \(error.localizedDescription)"
    }

    public func downloadPrepared(_ entry: CloudFileEntry) async {
        guard actionState == .idle else { return }
        actionFailed = false
        // Fix B-Neu4: keine fake Success-Message mehr. Stub klar als
        // „in Arbeit" gekennzeichnet, kein State-Wechsel.
        actionMessage = "Download/Wiederherstellen folgt in einer Folgephase. Datei bleibt in iCloud erhalten."
    }

    public func delete(_ entry: CloudFileEntry) async {
        guard actionState == .idle else { return }
        actionState = .deleting
        actionFailed = false
        actionMessage = nil
        do {
            let manager = self.manager
            try await manager.delete(entry)
            cloudEntries.removeAll { $0.recordName == entry.recordName }
            // Fix B-Neu7: lastRefreshAt auch nach erfolgreichem Delete.
            lastRefreshAt = Date()
            actionMessage = "Cloud-Datei gelöscht. Lokale Dateien bleiben erhalten."
        } catch {
            actionFailed = true
            actionMessage = error.localizedDescription
        }
        actionState = .idle
    }

    private func uploadCandidate(_ makeCandidate: @escaping @Sendable () throws -> CloudFileUploadCandidate) async {
        guard actionState == .idle else { return }
        actionState = .uploading
        actionFailed = false
        actionMessage = nil
        isCloudAvailable = isCloudAvailableProvider()
        guard isEnabled(), isCloudAvailable else {
            actionFailed = true
            actionMessage = "iCloud ist nicht erreichbar oder Datei-Upload ist deaktiviert."
            actionState = .idle
            return
        }
        // Fix B1: SHA-Berechnung läuft jetzt auf einer Kopie ohne
        // Security-Scope-Abhängigkeit — Task.detached ist hier sicher.
        var pendingShaForCleanup: String?
        do {
            let candidate = try await Task.detached { try makeCandidate() }.value
            pendingShaForCleanup = candidate.sha256Hex
            pendingUploads = [candidate]
            let manager = self.manager
            let entry = try await manager.upload(candidate)
            pendingUploads.removeAll { $0.sha256Hex == candidate.sha256Hex }
            cloudEntries.removeAll { $0.sha256Hex == entry.sha256Hex }
            cloudEntries.insert(entry, at: 0)
            lastRefreshAt = Date()
            actionMessage = "Upload abgeschlossen."
        } catch {
            actionFailed = true
            actionMessage = error.localizedDescription
            // Fix B2: hängende Pending-Einträge beim Fehler aufräumen.
            if let sha = pendingShaForCleanup {
                pendingUploads.removeAll { $0.sha256Hex == sha }
            }
        }
        actionState = .idle
    }
}
#endif
