import XCTest
@testable import LocationHistoryConsumerAppSupport

final class CloudFileManagementTests: XCTestCase {

    func testCloudFileKindAcceptsOnlyGPXKMLZIPCaseInsensitive() {
        XCTAssertEqual(CloudFileKind.from(filename: "track.gpx"), .gpx)
        XCTAssertEqual(CloudFileKind.from(filename: "TRACK.GPX"), .gpx)
        XCTAssertEqual(CloudFileKind.from(filename: "route.kml"), .kml)
        XCTAssertEqual(CloudFileKind.from(filename: "export.zip"), .zip)
        XCTAssertNil(CloudFileKind.from(filename: "history.json"))
        XCTAssertNil(CloudFileKind.from(filename: "table.csv"))
        XCTAssertNil(CloudFileKind.from(filename: "store.sqlite"))
        XCTAssertNil(CloudFileKind.from(filename: "activity.tcx"))
        XCTAssertNil(CloudFileKind.from(filename: "map.kmz"))
    }

    func testCloudFileRecordTypeAndFieldsAreStable() {
        XCTAssertEqual(CloudFileSchema.recordType, "LH2GPXCloudFile")
        XCTAssertEqual(CloudFileSchema.schemaVersion, 1)
        XCTAssertEqual(CloudFileSchema.Field.sha256Hex, "sha256Hex")
        XCTAssertEqual(CloudFileSchema.Field.asset, "asset")
        XCTAssertEqual(CloudFileSchema.recordName(sha256Hex: "abc"), "cloudfile-abc")
    }

    func testStreamingSHA256HexIsStableLowercaseAnd64Characters() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let file = tmp.appendingPathComponent("hello.gpx")
        try Data("hello".utf8).write(to: file)

        let digest = try StreamingSHA256.hexDigest(ofFileAt: file, chunkSize: 2)

        XCTAssertEqual(digest, "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
        XCTAssertEqual(digest.count, 64)
        XCTAssertEqual(digest, digest.lowercased())
    }

    func testCandidateFactoryRejectsUnsupportedTypeBeforeCloudCall() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let file = tmp.appendingPathComponent("history.json")
        try Data("{}".utf8).write(to: file)

        XCTAssertThrowsError(try CloudFileCandidateFactory.makeCandidate(for: file)) { error in
            XCTAssertEqual(error as? CloudFileError, .unsupportedFileType("history.json"))
        }
    }

    func testCandidateFactoryCreatesSupportedCandidateWithHash() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let file = tmp.appendingPathComponent("track.kml")
        try Data("<kml/>".utf8).write(to: file)

        let candidate = try CloudFileCandidateFactory.makeCandidate(for: file)

        XCTAssertEqual(candidate.fileName, "track.kml")
        XCTAssertEqual(candidate.kind, .kml)
        XCTAssertEqual(candidate.sizeBytes, 6)
        XCTAssertEqual(candidate.sha256Hex.count, 64)
    }

    func testDuplicateDetectionUsesSHA256NotFilename() async throws {
        let now = Date()
        let existing = CloudFileEntry(
            id: "same-sha",
            recordName: "cloudfile-same-sha",
            fileName: "first.gpx",
            kind: .gpx,
            sizeBytes: 10,
            sha256Hex: "same-sha",
            createdAt: now,
            updatedAt: now
        )
        let manager = InMemoryCloudFileManager(entries: [existing])
        let second = CloudFileUploadCandidate(
            url: URL(fileURLWithPath: "/tmp/second.gpx"),
            fileName: "second.gpx",
            kind: .gpx,
            sizeBytes: 10,
            modifiedAt: nil,
            sha256Hex: "same-sha"
        )

        do {
            _ = try await manager.upload(second)
            XCTFail("Expected duplicate SHA rejection")
        } catch {
            XCTAssertEqual(error as? CloudFileError, .duplicate(sha256Hex: "same-sha"))
        }
    }

    #if canImport(Combine)
    @MainActor
    func testViewModelUploadRequiresCloudGate() async throws {
        let manager = InMemoryCloudFileManager()
        let vm = AppCloudFileViewModel(
            manager: manager,
            isEnabled: { false },
            isCloudAvailable: { true }
        )
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let file = tmp.appendingPathComponent("track.gpx")
        try Data("hello".utf8).write(to: file)

        await vm.uploadPickedFile(at: file)

        XCTAssertTrue(vm.actionFailed)
        XCTAssertTrue((vm.actionMessage ?? "").contains("deaktiviert"))
        let entries = try await manager.listCloudFiles()
        XCTAssertEqual(entries, [])
    }

    @MainActor
    func testViewModelUploadSuccessAndDuplicateMessage() async throws {
        let manager = InMemoryCloudFileManager()
        let vm = AppCloudFileViewModel(manager: manager)
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let file = tmp.appendingPathComponent("track.gpx")
        try Data("hello".utf8).write(to: file)

        await vm.uploadPickedFile(at: file)
        XCTAssertFalse(vm.actionFailed)
        XCTAssertEqual(vm.actionMessage, "Upload abgeschlossen.")
        XCTAssertEqual(vm.cloudEntries.count, 1)

        await vm.uploadPickedFile(at: file)
        XCTAssertTrue(vm.actionFailed)
        XCTAssertEqual(vm.actionMessage, "Datei bereits in iCloud vorhanden")
        XCTAssertEqual(vm.cloudEntries.count, 1)
    }

    @MainActor
    func testViewModelDownloadIsPreparedOnly() async {
        let entry = CloudFileEntry(
            id: "sha",
            recordName: "cloudfile-sha",
            fileName: "track.gpx",
            kind: .gpx,
            sizeBytes: 1,
            sha256Hex: "sha",
            createdAt: Date(),
            updatedAt: Date()
        )
        let vm = AppCloudFileViewModel(manager: InMemoryCloudFileManager(entries: [entry]))

        await vm.downloadPrepared(entry)

        XCTAssertFalse(vm.actionFailed)
        XCTAssertTrue((vm.actionMessage ?? "").contains("Folgephase"))
        XCTAssertFalse((vm.actionMessage ?? "").contains("Download abgeschlossen"))
    }
    #endif

    private func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CloudFileManagementTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
