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
        await uploadURL(url, usesSecurityScope: true)
    }

    public func uploadLocalEntry(_ entry: LocalFileEntry) async {
        await uploadCandidate {
            try CloudFileCandidateFactory.makeCandidate(for: entry)
        }
    }

    public func downloadPrepared(_ entry: CloudFileEntry) async {
        guard actionState == .idle else { return }
        actionState = .downloading
        actionFailed = false
        actionMessage = "Herunterladen/Wiederherstellen ist vorbereitet. Vollständige Restore-Logik folgt separat."
        actionState = .idle
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
            actionMessage = "Cloud-Datei gelöscht. Lokale Dateien bleiben erhalten."
        } catch {
            actionFailed = true
            actionMessage = error.localizedDescription
        }
        actionState = .idle
    }

    private func uploadURL(_ url: URL, usesSecurityScope: Bool) async {
        await uploadCandidate {
            let accessed = usesSecurityScope ? url.startAccessingSecurityScopedResource() : false
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            return try CloudFileCandidateFactory.makeCandidate(for: url)
        }
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
        do {
            let candidate = try await Task.detached { try makeCandidate() }.value
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
        }
        actionState = .idle
    }
}
#endif
