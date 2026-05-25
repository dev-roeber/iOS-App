import XCTest
@testable import LocationHistoryConsumerAppSupport

final class CloudFileManagementTests: XCTestCase {

    func testCloudFileKindAcceptsGPXKMLZIPJSONCaseInsensitive() {
        XCTAssertEqual(CloudFileKind.from(filename: "track.gpx"), .gpx)
        XCTAssertEqual(CloudFileKind.from(filename: "TRACK.GPX"), .gpx)
        XCTAssertEqual(CloudFileKind.from(filename: "route.kml"), .kml)
        XCTAssertEqual(CloudFileKind.from(filename: "export.zip"), .zip)
        XCTAssertEqual(CloudFileKind.from(filename: "history.json"), .json)
        XCTAssertEqual(CloudFileKind.from(filename: "HISTORY.JSON"), .json)
        XCTAssertNil(CloudFileKind.from(filename: "table.csv"))
        XCTAssertNil(CloudFileKind.from(filename: "store.sqlite"))
        XCTAssertNil(CloudFileKind.from(filename: "activity.tcx"))
        XCTAssertNil(CloudFileKind.from(filename: "map.kmz"))
    }

    // Content-Validator: erste Bytes müssen zum erklärten Format passen.
    func testContentValidatorAcceptsValidHeaders() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let gpx = tmp.appendingPathComponent("a.gpx")
        try Data("<gpx version=\"1.1\"></gpx>".utf8).write(to: gpx)
        let kml = tmp.appendingPathComponent("a.kml")
        try Data("<?xml?><kml></kml>".utf8).write(to: kml)
        let json = tmp.appendingPathComponent("a.json")
        try Data("  {\"k\":1}".utf8).write(to: json)
        let zip = tmp.appendingPathComponent("a.zip")
        try Data([0x50, 0x4B, 0x03, 0x04, 0xAA, 0xBB]).write(to: zip)

        XCTAssertNoThrow(try CloudFileContentValidator.validate(url: gpx, expected: .gpx))
        XCTAssertNoThrow(try CloudFileContentValidator.validate(url: kml, expected: .kml))
        XCTAssertNoThrow(try CloudFileContentValidator.validate(url: json, expected: .json))
        XCTAssertNoThrow(try CloudFileContentValidator.validate(url: zip, expected: .zip))
    }

    func testContentValidatorRejectsMismatchedHeader() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let fakeGpx = tmp.appendingPathComponent("fake.gpx")
        try Data("hello world".utf8).write(to: fakeGpx)
        XCTAssertThrowsError(try CloudFileContentValidator.validate(url: fakeGpx, expected: .gpx))

        let fakeZip = tmp.appendingPathComponent("fake.zip")
        try Data("not a zip".utf8).write(to: fakeZip)
        XCTAssertThrowsError(try CloudFileContentValidator.validate(url: fakeZip, expected: .zip))
    }

    func testContentValidatorRejectsEmptyFile() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let empty = tmp.appendingPathComponent("empty.gpx")
        try Data().write(to: empty)
        XCTAssertThrowsError(try CloudFileContentValidator.validate(url: empty, expected: .gpx))
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
        let file = tmp.appendingPathComponent("hello.bin")
        try Data("hello".utf8).write(to: file)

        let digest = try StreamingSHA256.hexDigest(ofFileAt: file, chunkSize: 2)

        XCTAssertEqual(digest, "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
        XCTAssertEqual(digest.count, 64)
        XCTAssertEqual(digest, digest.lowercased())
    }

    func testCandidateFactoryRejectsUnsupportedTypeBeforeCloudCall() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let file = tmp.appendingPathComponent("data.csv")
        try Data("a,b,c".utf8).write(to: file)

        XCTAssertThrowsError(try CloudFileCandidateFactory.makeCandidate(for: file)) { error in
            XCTAssertEqual(error as? CloudFileError, .unsupportedFileType("data.csv"))
        }
    }

    func testCandidateFactoryRejectsMalformedContent() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let file = tmp.appendingPathComponent("fake.gpx")
        try Data("not gpx".utf8).write(to: file)
        XCTAssertThrowsError(try CloudFileCandidateFactory.makeCandidate(for: file))
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
        try Data("<gpx version=\"1.1\"></gpx>".utf8).write(to: file)

        await vm.uploadCopiedFile(at: file)

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
        try Data("<gpx version=\"1.1\"></gpx>".utf8).write(to: file)

        await vm.uploadCopiedFile(at: file)
        XCTAssertFalse(vm.actionFailed)
        XCTAssertEqual(vm.actionMessage, "Upload abgeschlossen.")
        XCTAssertEqual(vm.cloudEntries.count, 1)

        await vm.uploadCopiedFile(at: file)
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
