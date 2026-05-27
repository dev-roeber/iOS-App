import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Prompt 1 — Schließt die Verträge des Datei-Tabs fest:
/// Modell-Klassifizierung, Service-Scan/Lösch-Pfad und ViewModel-State.
final class AppFileManagementTests: XCTestCase {

    // MARK: - LocalFileKind

    func testLocalFileKindClassifiesByExtension() {
        XCTAssertEqual(LocalFileKind.from(filename: "track.gpx"), .gpx)
        XCTAssertEqual(LocalFileKind.from(filename: "Track.GPX"), .gpx)
        XCTAssertEqual(LocalFileKind.from(filename: "data.kml"), .kml)
        XCTAssertEqual(LocalFileKind.from(filename: "archive.zip"), .zip)
        XCTAssertEqual(LocalFileKind.from(filename: "store.sqlite-wal"), .sqlite)
        XCTAssertEqual(LocalFileKind.from(filename: "README"), .other)
    }

    func testLocalFileKindGermanLabels() {
        XCTAssertEqual(LocalFileKind.gpx.germanLabel, "GPX-Track")
        XCTAssertEqual(LocalFileKind.zip.germanLabel, "ZIP-Archiv")
    }

    // MARK: - Size formatter

    func testLocalFileSizeFormatterBoundaries() {
        XCTAssertEqual(LocalFileSizeFormatter.germanString(forBytes: 0), "0 B")
        XCTAssertEqual(LocalFileSizeFormatter.germanString(forBytes: 512), "512 B")
        XCTAssertTrue(LocalFileSizeFormatter.germanString(forBytes: 2048).contains("KB"))
        XCTAssertTrue(LocalFileSizeFormatter.germanString(forBytes: 5_000_000).contains("MB"))
        XCTAssertTrue(LocalFileSizeFormatter.germanString(forBytes: 5_000_000_000).contains("GB"))
        // Negative Werte werden zu 0 geklammert.
        XCTAssertEqual(LocalFileSizeFormatter.germanString(forBytes: -10), "0 B")
    }

    // MARK: - DiskLocalFileScanner

    func testDiskScannerListsRegularFilesAndComputesTotals() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let exports = tmp.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)
        try Data(repeating: 0xAB, count: 100).write(to: exports.appendingPathComponent("a.gpx"))
        try Data(repeating: 0xCD, count: 200).write(to: exports.appendingPathComponent("b.zip"))

        let roots = LocalFileBucketRoots(
            exports: exports,
            imports: tmp.appendingPathComponent("missing-imports", isDirectory: true),
            favorites: tmp.appendingPathComponent("missing-fav", isDirectory: true),
            caches: tmp.appendingPathComponent("missing-caches", isDirectory: true)
        )
        let scanner = DiskLocalFileScanner(roots: roots)

        let snapshots = try scanner.scanAllBuckets()
        XCTAssertEqual(snapshots.count, 4)
        let exportSnap = try XCTUnwrap(snapshots.first(where: { $0.bucket == .exports }))
        XCTAssertEqual(exportSnap.entries.count, 2)
        XCTAssertEqual(exportSnap.totalSizeBytes, 300)
        XCTAssertEqual(Set(exportSnap.entries.map { $0.fileName }), Set(["a.gpx", "b.zip"]))

        // Fehlende Verzeichnisse liefern leere Snapshots ohne Fehler.
        let importsSnap = try XCTUnwrap(snapshots.first(where: { $0.bucket == .imports }))
        XCTAssertEqual(importsSnap.entries.count, 0)
        XCTAssertEqual(importsSnap.totalSizeBytes, 0)
    }

    func testDiskScannerDeleteRemovesFileFromDisk() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let exports = tmp.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)
        let target = exports.appendingPathComponent("delete-me.gpx")
        try Data([1, 2, 3]).write(to: target)

        let roots = LocalFileBucketRoots(exports: exports, imports: tmp, favorites: tmp, caches: tmp)
        let scanner = DiskLocalFileScanner(roots: roots)
        let snap = try scanner.scanAllBuckets().first(where: { $0.bucket == .exports })
        let entry = try XCTUnwrap(snap?.entries.first)

        try scanner.deleteEntry(entry)
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
    }

    func testDiskScannerSkipsSubdirectories() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let exports = tmp.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: exports.appendingPathComponent("nested", isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data([0]).write(to: exports.appendingPathComponent("loose.gpx"))

        let roots = LocalFileBucketRoots(exports: exports, imports: tmp, favorites: tmp, caches: tmp)
        let scanner = DiskLocalFileScanner(roots: roots)
        let snap = try scanner.scanAllBuckets().first(where: { $0.bucket == .exports })
        XCTAssertEqual(snap?.entries.map(\.fileName), ["loose.gpx"])
    }

    // MARK: - ViewModel (Combine path)

    #if canImport(Combine)
    @MainActor
    func testViewModelRefreshPopulatesSnapshotsAndShowsSuccessMessage() async {
        let scanner = InMemoryLocalFileScanner(snapshots: [
            LocalFileBucketSnapshot(bucket: .exports, entries: [
                makeEntry(name: "a.gpx", bucket: .exports, size: 100)
            ], totalSizeBytes: 100)
        ])
        let vm = AppFilesViewModel(scanner: scanner)
        await vm.refresh()
        XCTAssertEqual(vm.actionState, .idle)
        XCTAssertEqual(vm.snapshots.count, 1)
        XCTAssertFalse(vm.actionFailed)
        XCTAssertEqual(vm.actionMessage, "Datei-Übersicht aktualisiert.")
        XCTAssertEqual(vm.totalSizeBytes, 100)
    }

    @MainActor
    func testViewModelRefreshFailureSetsErrorFlag() async {
        let scanner = InMemoryLocalFileScanner()
        scanner.scriptedScanError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Scan kaputt"])
        let vm = AppFilesViewModel(scanner: scanner)
        await vm.refresh()
        XCTAssertTrue(vm.actionFailed)
        XCTAssertTrue((vm.actionMessage ?? "").contains("Scan kaputt"))
        XCTAssertEqual(vm.actionState, .idle)
    }

    @MainActor
    func testViewModelClearActionMessageResetsLocalBannerState() async {
        let scanner = InMemoryLocalFileScanner()
        scanner.scriptedScanError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Scan kaputt"])
        let vm = AppFilesViewModel(scanner: scanner)
        await vm.refresh()
        XCTAssertTrue(vm.actionFailed)
        XCTAssertNotNil(vm.actionMessage)

        vm.clearActionMessage()

        XCTAssertFalse(vm.actionFailed)
        XCTAssertNil(vm.actionMessage)
    }

    @MainActor
    func testViewModelDeleteRemovesEntryAndReloadsSnapshot() async {
        let entry = makeEntry(name: "a.gpx", bucket: .exports, size: 50)
        let scanner = InMemoryLocalFileScanner(snapshots: [
            LocalFileBucketSnapshot(bucket: .exports, entries: [entry], totalSizeBytes: 50)
        ])
        let vm = AppFilesViewModel(scanner: scanner)
        await vm.refresh()
        await vm.delete(entry)
        XCTAssertEqual(scanner.deletedIDs, [entry.id])
        XCTAssertEqual(vm.filteredEntries(for: .exports), [])
        XCTAssertTrue((vm.actionMessage ?? "").contains("gelöscht"))
    }

    /// Regressionsschutz: nach `delete()` darf KEIN zweiter
    /// `scanAllBuckets()` laufen — Snapshot wird lokal mutiert. Ein voller
    /// Re-Scan bleibt dem expliziten Refresh-Button vorbehalten.
    @MainActor
    func testViewModelDeleteMutatesSnapshotLocallyWithoutReScan() async {
        let kept = makeEntry(name: "keep.gpx", bucket: .exports, size: 40)
        let doomed = makeEntry(name: "doomed.gpx", bucket: .exports, size: 60)
        let scanner = InMemoryLocalFileScanner(snapshots: [
            LocalFileBucketSnapshot(bucket: .exports, entries: [kept, doomed], totalSizeBytes: 100)
        ])
        let vm = AppFilesViewModel(scanner: scanner)
        await vm.refresh()
        XCTAssertEqual(scanner.scanCallCount, 1)

        await vm.delete(doomed)

        // Genau EIN Scan insgesamt — keine zusätzlichen Disk-Walks.
        XCTAssertEqual(scanner.scanCallCount, 1, "delete() darf keinen Re-Scan triggern")
        XCTAssertEqual(scanner.deletedIDs, [doomed.id])
        XCTAssertEqual(vm.filteredEntries(for: .exports).map(\.fileName), ["keep.gpx"])
        XCTAssertEqual(vm.totalSizeBytes, 40, "Bucket-Total nach Mutation = 40")
    }

    /// Pure Mutation ohne MainActor — schnelle Verifikation der
    /// Bucket-/Total-Bookkeeping-Logik.
    func testRemovingEntryHelperUpdatesBucketTotal() {
        let a = makeEntry(name: "a.gpx", bucket: .exports, size: 10)
        let b = makeEntry(name: "b.gpx", bucket: .exports, size: 30)
        let c = makeEntry(name: "c.gpx", bucket: .imports, size: 5)
        let snapshots = [
            LocalFileBucketSnapshot(bucket: .exports, entries: [a, b], totalSizeBytes: 40),
            LocalFileBucketSnapshot(bucket: .imports, entries: [c], totalSizeBytes: 5),
        ]
        let mutated = AppFilesViewModel.removingEntry(b, from: snapshots)
        let exports = mutated.first(where: { $0.bucket == .exports })
        XCTAssertEqual(exports?.entries.map(\.fileName), ["a.gpx"])
        XCTAssertEqual(exports?.totalSizeBytes, 10)
        let imports = mutated.first(where: { $0.bucket == .imports })
        XCTAssertEqual(imports?.entries.map(\.fileName), ["c.gpx"])
        XCTAssertEqual(imports?.totalSizeBytes, 5)
    }

    /// Cancellation: ein vor `await` abgebrochener Refresh setzt KEINEN
    /// Fehler-Banner und stellt `actionState` sauber zurück. Spiegelt das
    /// Verhalten beim Tab-Wechsel in `AppFilesView.onDisappear`.
    @MainActor
    func testViewModelRefreshHonoursTaskCancellationWithoutErrorBanner() async {
        let scanner = InMemoryLocalFileScanner(snapshots: [
            LocalFileBucketSnapshot(bucket: .exports, entries: [], totalSizeBytes: 0)
        ])
        let vm = AppFilesViewModel(scanner: scanner)

        let task = Task { @MainActor in
            await vm.refresh()
        }
        task.cancel()
        await task.value

        XCTAssertEqual(vm.actionState, .idle)
        XCTAssertFalse(vm.actionFailed)
        XCTAssertNil(vm.actionMessage,
                     "Cancellation darf keinen Erfolgs-/Fehler-Banner setzen")
    }

    @MainActor
    func testViewModelFilterReducesEntries() async {
        let scanner = InMemoryLocalFileScanner(snapshots: [
            LocalFileBucketSnapshot(bucket: .exports, entries: [
                makeEntry(name: "abc.gpx", bucket: .exports, size: 1),
                makeEntry(name: "xyz.kml", bucket: .exports, size: 1),
            ], totalSizeBytes: 2)
        ])
        let vm = AppFilesViewModel(scanner: scanner)
        await vm.refresh()
        vm.filterText = "abc"
        XCTAssertEqual(vm.filteredEntries(for: .exports).map(\.fileName), ["abc.gpx"])
        vm.filterText = "  "
        XCTAssertEqual(vm.filteredEntries(for: .exports).count, 2)
    }
    #endif

    // MARK: - Helpers

    private func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppFileManagementTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeEntry(name: String, bucket: LocalFileBucket, size: Int64) -> LocalFileEntry {
        LocalFileEntry(
            id: "\(bucket.rawValue)/\(name)",
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            fileName: name,
            sizeBytes: size,
            modifiedAt: Date(timeIntervalSince1970: 0),
            kind: LocalFileKind.from(filename: name),
            bucket: bucket
        )
    }
}
