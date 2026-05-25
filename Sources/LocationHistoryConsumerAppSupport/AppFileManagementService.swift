import Foundation

/// Prompt 1 — Service-Layer für den Dateien-Tab.
///
/// `LocalFileScanning` ist als Protokoll modelliert, damit der ViewModel
/// in Tests gegen einen `InMemoryLocalFileScanner` laufen kann, ohne den
/// echten Disk-Inhalt anzufassen. `DiskLocalFileScanner` ist die
/// Produktiv-Implementation, die `FileManager.contentsOfDirectory(at:)`
/// gegen die vier Buckets (Exporte/Importe/Favoriten/Caches) aufruft.

public protocol LocalFileScanning: Sendable {
    func scanAllBuckets() throws -> [LocalFileBucketSnapshot]
    func deleteEntry(_ entry: LocalFileEntry) throws
}

public struct LocalFileBucketRoots: Sendable {
    public let exports: URL
    public let imports: URL
    public let favorites: URL
    public let caches: URL

    public init(exports: URL, imports: URL, favorites: URL, caches: URL) {
        self.exports = exports
        self.imports = imports
        self.favorites = favorites
        self.caches = caches
    }

    public static func production(fileManager: FileManager = .default) throws -> LocalFileBucketRoots {
        let documents = try fileManager.url(for: .documentDirectory,
                                            in: .userDomainMask,
                                            appropriateFor: nil,
                                            create: false)
        let appSupport = try fileManager.url(for: .applicationSupportDirectory,
                                             in: .userDomainMask,
                                             appropriateFor: nil,
                                             create: false)
        let caches = try fileManager.url(for: .cachesDirectory,
                                         in: .userDomainMask,
                                         appropriateFor: nil,
                                         create: false)
        let project = "LocationHistory2GPX"
        return LocalFileBucketRoots(
            exports: documents,
            imports: appSupport.appendingPathComponent(project, isDirectory: true)
                .appendingPathComponent("Imports", isDirectory: true),
            favorites: appSupport.appendingPathComponent(project, isDirectory: true)
                .appendingPathComponent("Favorites", isDirectory: true),
            caches: caches.appendingPathComponent(project, isDirectory: true)
                .appendingPathComponent("RenderCache", isDirectory: true)
        )
    }
}

public final class DiskLocalFileScanner: LocalFileScanning, @unchecked Sendable {
    private let roots: LocalFileBucketRoots
    private let fileManager: FileManager

    public init(roots: LocalFileBucketRoots, fileManager: FileManager = .default) {
        self.roots = roots
        self.fileManager = fileManager
    }

    public func scanAllBuckets() throws -> [LocalFileBucketSnapshot] {
        return [
            try snapshot(bucket: .exports, root: roots.exports),
            try snapshot(bucket: .imports, root: roots.imports),
            try snapshot(bucket: .favorites, root: roots.favorites),
            try snapshot(bucket: .caches, root: roots.caches),
        ]
    }

    public func deleteEntry(_ entry: LocalFileEntry) throws {
        try fileManager.removeItem(at: entry.url)
    }

    private func snapshot(bucket: LocalFileBucket, root: URL) throws -> LocalFileBucketSnapshot {
        guard fileManager.fileExists(atPath: root.path) else {
            return LocalFileBucketSnapshot(bucket: bucket, entries: [], totalSizeBytes: 0)
        }
        let contents = (try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        var entries: [LocalFileEntry] = []
        var total: Int64 = 0
        for url in contents {
            let values = try? url.resourceValues(forKeys: [
                .fileSizeKey, .contentModificationDateKey, .isRegularFileKey
            ])
            // Nur reguläre Dateien (keine Unterverzeichnisse) aufnehmen.
            guard values?.isRegularFile == true else { continue }
            let size = Int64(values?.fileSize ?? 0)
            let modified = values?.contentModificationDate
            let name = url.lastPathComponent
            let kind = LocalFileKind.from(filename: name)
            entries.append(LocalFileEntry(
                id: "\(bucket.rawValue)/\(name)",
                url: url,
                fileName: name,
                sizeBytes: size,
                modifiedAt: modified,
                kind: kind,
                bucket: bucket
            ))
            total += size
        }
        entries.sort { lhs, rhs in
            (lhs.modifiedAt ?? .distantPast) > (rhs.modifiedAt ?? .distantPast)
        }
        return LocalFileBucketSnapshot(bucket: bucket, entries: entries, totalSizeBytes: total)
    }
}

/// Testbarer In-Memory-Scanner. Wird vom ViewModel im Test-Doppel verwendet.
public final class InMemoryLocalFileScanner: LocalFileScanning, @unchecked Sendable {
    public var scriptedSnapshots: [LocalFileBucketSnapshot]
    public var scriptedScanError: Error?
    public var scriptedDeleteError: Error?
    public private(set) var deletedIDs: [String] = []
    /// Anzahl der `scanAllBuckets()`-Aufrufe — Tests prüfen damit,
    /// dass `delete()` keinen zusätzlichen Disk-Walk auslöst.
    public private(set) var scanCallCount: Int = 0
    private let lock = NSLock()

    public init(snapshots: [LocalFileBucketSnapshot] = []) {
        self.scriptedSnapshots = snapshots
    }

    public func scanAllBuckets() throws -> [LocalFileBucketSnapshot] {
        lock.lock(); scanCallCount += 1; lock.unlock()
        if let error = scriptedScanError { throw error }
        return scriptedSnapshots
    }

    public func deleteEntry(_ entry: LocalFileEntry) throws {
        if let error = scriptedDeleteError { throw error }
        lock.lock(); defer { lock.unlock() }
        deletedIDs.append(entry.id)
        // Entferne den Eintrag auch aus den scripted Snapshots, damit ein
        // anschließender scan() den gelöschten Eintrag nicht mehr enthält.
        scriptedSnapshots = scriptedSnapshots.map { snap in
            let filtered = snap.entries.filter { $0.id != entry.id }
            let total = filtered.reduce(Int64(0)) { $0 + $1.sizeBytes }
            return LocalFileBucketSnapshot(bucket: snap.bucket, entries: filtered, totalSizeBytes: total)
        }
    }
}
