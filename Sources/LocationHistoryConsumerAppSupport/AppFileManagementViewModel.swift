import Foundation
#if canImport(Combine)
import Combine
#endif

/// Prompt 1 — ViewModel für AppFilesView.
///
/// Hält die geladenen Bucket-Snapshots, einen Filter-String und einen
/// `actionState`, damit Lade-/Lösch-Aktionen sichtbar sind. Der ViewModel
/// kennt nur das `LocalFileScanning`-Protokoll, deswegen ist die Logik
/// vollständig in Linux-Foundation testbar.

public enum LocalFilesActionState: String, Sendable {
    case idle
    case scanning
    case deleting
}

#if canImport(Combine)
@MainActor
public final class AppFilesViewModel: ObservableObject {
    @Published public private(set) var snapshots: [LocalFileBucketSnapshot] = []
    @Published public private(set) var actionState: LocalFilesActionState = .idle
    @Published public var actionMessage: String?
    @Published public var actionFailed: Bool = false
    @Published public var filterText: String = ""

    private let scanner: LocalFileScanning

    public init(scanner: LocalFileScanning) {
        self.scanner = scanner
    }

    public var totalSizeBytes: Int64 {
        snapshots.reduce(Int64(0)) { $0 + $1.totalSizeBytes }
    }

    public var totalSizeGerman: String {
        LocalFileSizeFormatter.germanString(forBytes: totalSizeBytes)
    }

    public func filteredEntries(for bucket: LocalFileBucket) -> [LocalFileEntry] {
        guard let snap = snapshots.first(where: { $0.bucket == bucket }) else { return [] }
        guard !filterText.trimmingCharacters(in: .whitespaces).isEmpty else { return snap.entries }
        let needle = filterText.lowercased()
        return snap.entries.filter { $0.fileName.lowercased().contains(needle) }
    }

    public func refresh() async {
        guard actionState == .idle else { return }
        actionState = .scanning
        actionFailed = false
        actionMessage = nil
        do {
            try Task.checkCancellation()
            let scanner = self.scanner
            let scanned = try await Task.detached { try scanner.scanAllBuckets() }.value
            try Task.checkCancellation()
            snapshots = scanned
            actionMessage = "Datei-Übersicht aktualisiert."
        } catch is CancellationError {
            // Cancellation (z. B. durch AppFilesView.onDisappear) darf
            // keinen Fehler-Banner setzen — es ist kein Bug, sondern eine
            // bewusste Abkehr vom Tab. State bleibt sauber idle.
            actionState = .idle
            return
        } catch {
            actionFailed = true
            actionMessage = "Datei-Übersicht konnte nicht geladen werden: \(error.localizedDescription)"
        }
        actionState = .idle
    }

    public func delete(_ entry: LocalFileEntry) async {
        guard actionState == .idle else { return }
        actionState = .deleting
        actionFailed = false
        actionMessage = nil
        do {
            let scanner = self.scanner
            try await Task.detached { try scanner.deleteEntry(entry) }.value
            // Lokale Snapshot-Mutation statt komplettem Re-Scan: spart eine
            // teure Disk-Walk-Operation und vermeidet das frühere
            // Double-Scan-Pattern (refresh-after-delete UND onAppear-refresh).
            // Ein voller Re-Scan passiert nur noch beim expliziten
            // Pull-To-Refresh / „Aktualisieren"-Button im UI.
            snapshots = AppFilesViewModel.removingEntry(entry, from: snapshots)
            actionMessage = "Datei „\(entry.fileName)“ gelöscht."
        } catch {
            actionFailed = true
            actionMessage = "Datei konnte nicht gelöscht werden: \(error.localizedDescription)"
        }
        actionState = .idle
    }

    /// Reine Snapshot-Mutation: entfernt `entry` aus dem zugehörigen
    /// Bucket und passt `totalSizeBytes` an. `internal` + `static`, damit
    /// das ohne MainActor-Hop unit-testbar ist.
    nonisolated static func removingEntry(
        _ entry: LocalFileEntry,
        from snapshots: [LocalFileBucketSnapshot]
    ) -> [LocalFileBucketSnapshot] {
        snapshots.map { snap in
            guard snap.bucket == entry.bucket else { return snap }
            let filtered = snap.entries.filter { $0.id != entry.id }
            let total = filtered.reduce(Int64(0)) { $0 + $1.sizeBytes }
            return LocalFileBucketSnapshot(bucket: snap.bucket, entries: filtered, totalSizeBytes: total)
        }
    }
}
#endif
