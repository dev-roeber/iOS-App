import Foundation
#if canImport(Combine)
import Combine
#endif

/// Phase F — koordiniert den bidirektionalen Sync zwischen
/// `FavoriteEntryStore` (lokal) und `FavoriteEntryCloudSyncing` (iCloud).
///
/// Merge-Regel: jüngeres `updatedAt` gewinnt pro `favoriteID`. Tombstone
/// (`isFavorite = false`) wird respektiert. Idempotent — wiederholtes
/// Aufrufen führt zu denselben lokalen + Cloud-Records.

public enum FavoriteCloudSyncActionState: String, Sendable {
    case idle
    case syncing
}

#if canImport(Combine)
@MainActor
public final class FavoriteEntryCloudSyncCoordinator: ObservableObject {
    @Published public private(set) var actionState: FavoriteCloudSyncActionState = .idle
    @Published public var actionMessage: String?
    @Published public var actionFailed: Bool = false
    @Published public private(set) var lastSyncAt: Date?

    private let store: FavoriteEntryStore
    private let cloud: FavoriteEntryCloudSyncing

    public init(store: FavoriteEntryStore, cloud: FavoriteEntryCloudSyncing) {
        self.store = store
        self.cloud = cloud
    }

    /// Zwei-Wege-Sync: pushed lokale Einträge in die Cloud, holt Cloud-
    /// Einträge zurück und merged sie. Merge-Regel: jüngeres
    /// `updatedAt` gewinnt; neue Cloud-only-IDs werden lokal angelegt.
    public func sync() async {
        guard actionState == .idle else { return }
        actionState = .syncing
        actionFailed = false
        actionMessage = nil
        defer { actionState = .idle }
        do {
            let cloudInstance = self.cloud
            let local = (try? store.loadEntries()) ?? []
            try await cloudInstance.push(local)
            let cloudEntries = try await cloudInstance.pull()
            let merged = Self.merge(local: local, cloud: cloudEntries)
            if merged != local {
                try store.replaceAll(with: merged)
            }
            // Cloud-only-Einträge nochmal pushen, damit unsere
            // Merge-Entscheidung in der Cloud sichtbar wird.
            let upstreamPayload = merged.filter { entry in
                guard let cloudCopy = cloudEntries.first(where: { $0.favoriteID == entry.favoriteID }) else {
                    return true
                }
                return cloudCopy.updatedAt < entry.updatedAt
            }
            if !upstreamPayload.isEmpty {
                try await cloudInstance.push(upstreamPayload)
            }
            lastSyncAt = Date()
            actionMessage = "Favoriten synchronisiert (\(merged.count) Einträge)."
        } catch {
            actionFailed = true
            actionMessage = "Favoriten-Sync fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    /// Pure-funktionale Merge-Logik — testbar ohne CloudKit/Store und
    /// ohne MainActor-Hop.
    public nonisolated static func merge(local: [FavoriteEntry], cloud: [FavoriteEntry]) -> [FavoriteEntry] {
        var byID: [UUID: FavoriteEntry] = [:]
        for entry in local { byID[entry.favoriteID] = entry }
        for cloudEntry in cloud {
            if let existing = byID[cloudEntry.favoriteID] {
                byID[cloudEntry.favoriteID] = cloudEntry.updatedAt > existing.updatedAt
                    ? cloudEntry : existing
            } else {
                byID[cloudEntry.favoriteID] = cloudEntry
            }
        }
        return Array(byID.values).sorted { $0.createdAt < $1.createdAt }
    }
}
#endif
