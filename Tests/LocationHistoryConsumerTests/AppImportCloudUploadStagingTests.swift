import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Verifiziert den synchronen Staging-Helper, der die security-scoped
/// Original-URL aus dem Import-Pfad in eine app-owned tmp-Kopie hebt.
/// Auf Linux läuft der Test-Pfad ohne `startAccessingSecurityScopedResource`
/// / `NSFileCoordinator` und nutzt den `FileManager.copyItem`-Fallback —
/// das Verhalten (Datei vorhanden, gleicher Name, gleicher Inhalt) muss
/// trotzdem identisch sein.
final class AppImportCloudUploadStagingTests: XCTestCase {

    private var fixturesRoot: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fixturesRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppImportCloudUploadStagingTests-\(UUID().uuidString)",
                                    isDirectory: true)
        try FileManager.default.createDirectory(at: fixturesRoot,
                                                withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let fixturesRoot, FileManager.default.fileExists(atPath: fixturesRoot.path) {
            try? FileManager.default.removeItem(at: fixturesRoot)
        }
        try super.tearDownWithError()
    }

    func testStageCopiesFileIntoTempSubdirectoryWithSameNameAndBytes() throws {
        let payload = Data("hello-staging-\(UUID().uuidString)".utf8)
        let source = fixturesRoot.appendingPathComponent("Timeline.json")
        try payload.write(to: source)

        let staged = try AppImportCloudUploadStaging.stage(sourceURL: source)

        XCTAssertEqual(staged.lastPathComponent, source.lastPathComponent)
        XCTAssertTrue(FileManager.default.fileExists(atPath: staged.path))
        XCTAssertEqual(try Data(contentsOf: staged), payload)

        // Staging-Dir liegt unter temporaryDirectory und ist NICHT die
        // Original-Datei (app-owned Kopie, kein Symlink auf die Quelle).
        let tmp = FileManager.default.temporaryDirectory.standardizedFileURL.path
        XCTAssertTrue(staged.standardizedFileURL.path.hasPrefix(tmp),
                      "expected staged path under temporaryDirectory, got \(staged.path)")
        XCTAssertNotEqual(staged.standardizedFileURL.path,
                          source.standardizedFileURL.path)

        // Aufräumen für saubere Test-Reihenfolge.
        AppImportCloudUploadStaging.cleanup(stagedURL: staged)
    }

    func testCleanupRemovesStagingDirectory() throws {
        let source = fixturesRoot.appendingPathComponent("Timeline.json")
        try Data("cleanup-payload".utf8).write(to: source)

        let staged = try AppImportCloudUploadStaging.stage(sourceURL: source)
        let stagingDir = staged.deletingLastPathComponent()
        XCTAssertTrue(FileManager.default.fileExists(atPath: stagingDir.path))

        AppImportCloudUploadStaging.cleanup(stagedURL: staged)

        XCTAssertFalse(FileManager.default.fileExists(atPath: stagingDir.path),
                       "staging directory should be gone after cleanup")
    }

    func testCleanupOnMissingDirectoryIsSilent() {
        let bogus = FileManager.default.temporaryDirectory
            .appendingPathComponent("does-not-exist-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("file.json")
        // Darf nicht werfen / crashen.
        AppImportCloudUploadStaging.cleanup(stagedURL: bogus)
    }

    #if canImport(Combine)
    /// End-to-End-Spiegelbild des AppContentSplitView-Picker-Flows:
    /// `stage(...)` → `uploadCopiedFile(at:)` → `cleanup(...)`. Stellt
    /// sicher, dass die gestagete Datei beim Upload sichtbar ist UND
    /// dass das Staging-Verzeichnis am Ende verschwindet (kein Race).
    @MainActor
    func testStagingPatternUploadSuccessThenCleanup() async throws {
        let payload = Data("<gpx version=\"1.1\"></gpx>".utf8)
        let source = fixturesRoot.appendingPathComponent("Picker.gpx")
        try payload.write(to: source)

        let staged = try AppImportCloudUploadStaging.stage(sourceURL: source)
        let stagingDir = staged.deletingLastPathComponent()
        XCTAssertTrue(FileManager.default.fileExists(atPath: staged.path))

        let manager = InMemoryCloudFileManager()
        let vm = AppCloudFileViewModel(manager: manager)

        await vm.uploadCopiedFile(at: staged)
        AppImportCloudUploadStaging.cleanup(stagedURL: staged)

        XCTAssertFalse(vm.actionFailed)
        XCTAssertEqual(vm.cloudEntries.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stagingDir.path),
                       "Cleanup muss das Staging-Verzeichnis nach Upload entfernen")
    }

    /// Negativ-Fall: existiert die Quelle nicht, wirft `stage(...)` synchron
    /// und der Upload wird gar nicht erst angestoßen — Picker-Pfad meldet
    /// den Fehler über `reportPickerFailure`.
    @MainActor
    func testStagingFailurePropagatesAndSkipsUpload() async {
        let missing = fixturesRoot.appendingPathComponent("does-not-exist.gpx")
        XCTAssertThrowsError(try AppImportCloudUploadStaging.stage(sourceURL: missing))

        let manager = InMemoryCloudFileManager()
        let vm = AppCloudFileViewModel(manager: manager)
        // Simulation des Catch-Branches in AppContentSplitView.
        vm.reportPickerFailure(NSError(domain: "stage", code: 1,
                                       userInfo: [NSLocalizedDescriptionKey: "stage failed"]))

        XCTAssertTrue(vm.actionFailed)
        let entries = try? await manager.listCloudFiles()
        XCTAssertEqual(entries ?? [], [])
    }
    #endif
}
