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
            let scanner = self.scanner
            let scanned = try await Task.detached { try scanner.scanAllBuckets() }.value
            snapshots = scanned
            actionMessage = "Datei-Übersicht aktualisiert."
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
            // Snapshot neu laden, damit UI den Eintrag verliert.
            let scanned = try await Task.detached { try scanner.scanAllBuckets() }.value
            snapshots = scanned
            actionMessage = "Datei „\(entry.fileName)“ gelöscht."
        } catch {
            actionFailed = true
            actionMessage = "Datei konnte nicht gelöscht werden: \(error.localizedDescription)"
        }
        actionState = .idle
    }
}
#endif
