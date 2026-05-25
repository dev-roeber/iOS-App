import Foundation

public enum CloudFileKind: String, Codable, CaseIterable, Sendable {
    case gpx
    case kml
    case zip
    case json

    public static func from(filename: String) -> CloudFileKind? {
        switch (filename as NSString).pathExtension.lowercased() {
        case "gpx": return .gpx
        case "kml": return .kml
        case "zip": return .zip
        case "json": return .json
        default: return nil
        }
    }

    public var germanLabel: String {
        switch self {
        case .gpx: return "GPX-Datei"
        case .kml: return "KML-Datei"
        case .zip: return "ZIP-Archiv"
        case .json: return "JSON-Datei"
        }
    }
}

/// Validiert die ersten Bytes einer Datei gegen das erwartete Format.
/// Verhindert dass eine als .gpx benannte Binärdatei oder eine kaputte
/// ZIP hochgeladen wird — Apple-Empfehlung für CKAsset-Uploads.
public enum CloudFileContentValidator {
    public enum ValidationError: LocalizedError, Equatable {
        case fileNotReadable(String)
        case formatMismatch(expected: CloudFileKind, head: String)
        case empty

        public var errorDescription: String? {
            switch self {
            case .fileNotReadable(let path): return "Datei nicht lesbar: \(path)"
            case .formatMismatch(let expected, _):
                return "Datei entspricht nicht dem Format \(expected.germanLabel)."
            case .empty: return "Datei ist leer."
            }
        }
    }

    public static func validate(url: URL, expected: CloudFileKind) throws {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            throw ValidationError.fileNotReadable(url.lastPathComponent)
        }
        defer { try? handle.close() }
        let head = (try? handle.read(upToCount: 512)) ?? Data()
        guard !head.isEmpty else { throw ValidationError.empty }
        let asString = String(data: head, encoding: .utf8) ?? ""
        switch expected {
        case .gpx:
            guard asString.contains("<gpx") else {
                throw ValidationError.formatMismatch(expected: .gpx, head: String(asString.prefix(40)))
            }
        case .kml:
            guard asString.contains("<kml") else {
                throw ValidationError.formatMismatch(expected: .kml, head: String(asString.prefix(40)))
            }
        case .zip:
            // PKZip Local File Header Signature: 50 4B 03 04
            let prefix = Array(head.prefix(4))
            guard prefix == [0x50, 0x4B, 0x03, 0x04]
                  || prefix == [0x50, 0x4B, 0x05, 0x06] // empty archive
                  || prefix == [0x50, 0x4B, 0x07, 0x08] // spanned
            else {
                throw ValidationError.formatMismatch(expected: .zip, head: head.map { String(format: "%02X", $0) }.prefix(8).joined())
            }
        case .json:
            // erstes Non-Whitespace muss { oder [ sein
            let trimmed = asString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let first = trimmed.first, first == "{" || first == "[" else {
                throw ValidationError.formatMismatch(expected: .json, head: String(asString.prefix(40)))
            }
        }
    }
}

public struct CloudFileEntry: Identifiable, Equatable, Sendable {
    public let id: String
    public let recordName: String
    public let fileName: String
    public let kind: CloudFileKind
    public let sizeBytes: Int64
    public let sha256Hex: String
    public let createdAt: Date
    public let updatedAt: Date

    public init(id: String,
                recordName: String,
                fileName: String,
                kind: CloudFileKind,
                sizeBytes: Int64,
                sha256Hex: String,
                createdAt: Date,
                updatedAt: Date) {
        self.id = id
        self.recordName = recordName
        self.fileName = fileName
        self.kind = kind
        self.sizeBytes = sizeBytes
        self.sha256Hex = sha256Hex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct CloudFileUploadCandidate: Equatable, Sendable {
    public let url: URL
    public let fileName: String
    public let kind: CloudFileKind
    public let sizeBytes: Int64
    public let modifiedAt: Date?
    public let sha256Hex: String

    public init(url: URL,
                fileName: String,
                kind: CloudFileKind,
                sizeBytes: Int64,
                modifiedAt: Date?,
                sha256Hex: String) {
        self.url = url
        self.fileName = fileName
        self.kind = kind
        self.sizeBytes = sizeBytes
        self.modifiedAt = modifiedAt
        self.sha256Hex = sha256Hex
    }
}

public enum CloudFileError: LocalizedError, Equatable {
    case unsupportedFileType(String)
    case duplicate(sha256Hex: String)
    case noSupportedLocalFile
    case missingAsset
    case deleteResultMissing(String)
    case deleteFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            return "Nicht unterstützter Dateityp"
        case .duplicate:
            return "Datei bereits in iCloud vorhanden"
        case .noSupportedLocalFile:
            return "Keine lokale GPX-, KML- oder ZIP-Datei gefunden."
        case .missingAsset:
            return "Cloud-Datei enthält kein ladbares Asset."
        case .deleteResultMissing:
            return "CloudKit hat kein Lösch-Ergebnis geliefert."
        case .deleteFailed:
            return "Cloud-Datei konnte nicht gelöscht werden."
        }
    }
}

public enum CloudFileSchema {
    public static let recordType = "LH2GPXCloudFile"
    public static let schemaVersion = 1

    public enum Field {
        public static let schemaVersion = "schemaVersion"
        public static let fileName = "fileName"
        public static let fileKind = "fileKind"
        public static let sizeBytes = "sizeBytes"
        public static let sha256Hex = "sha256Hex"
        public static let asset = "asset"
        public static let createdAt = "createdAt"
        public static let updatedAt = "updatedAt"
        public static let originalModifiedAt = "originalModifiedAt"
    }

    public static func recordName(sha256Hex: String) -> String {
        "cloudfile-\(sha256Hex)"
    }
}

public protocol CloudFileManaging: Sendable {
    func listCloudFiles() async throws -> [CloudFileEntry]
    func upload(_ candidate: CloudFileUploadCandidate) async throws -> CloudFileEntry
    func delete(_ entry: CloudFileEntry) async throws
    func download(_ entry: CloudFileEntry, to directory: URL) async throws -> URL
}

public struct NoopCloudFileManager: CloudFileManaging {
    public init() {}
    public func listCloudFiles() async throws -> [CloudFileEntry] { [] }
    public func upload(_ candidate: CloudFileUploadCandidate) async throws -> CloudFileEntry {
        throw CloudFileError.unsupportedFileType(candidate.fileName)
    }
    public func delete(_ entry: CloudFileEntry) async throws {}
    public func download(_ entry: CloudFileEntry, to directory: URL) async throws -> URL {
        throw CloudFileError.missingAsset
    }
}

public actor InMemoryCloudFileManager: CloudFileManaging {
    public private(set) var entries: [CloudFileEntry]
    public var scriptedListError: Error?
    public var scriptedUploadError: Error?
    public var scriptedDeleteError: Error?
    public private(set) var uploadedCandidates: [CloudFileUploadCandidate] = []
    public private(set) var deletedRecordNames: [String] = []

    public init(entries: [CloudFileEntry] = []) {
        self.entries = entries
    }

    public func listCloudFiles() async throws -> [CloudFileEntry] {
        if let scriptedListError { throw scriptedListError }
        return entries.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func upload(_ candidate: CloudFileUploadCandidate) async throws -> CloudFileEntry {
        if let scriptedUploadError { throw scriptedUploadError }
        if entries.contains(where: { $0.sha256Hex == candidate.sha256Hex }) {
            throw CloudFileError.duplicate(sha256Hex: candidate.sha256Hex)
        }
        uploadedCandidates.append(candidate)
        let now = Date()
        let entry = CloudFileEntry(
            id: candidate.sha256Hex,
            recordName: CloudFileSchema.recordName(sha256Hex: candidate.sha256Hex),
            fileName: candidate.fileName,
            kind: candidate.kind,
            sizeBytes: candidate.sizeBytes,
            sha256Hex: candidate.sha256Hex,
            createdAt: now,
            updatedAt: now
        )
        entries.append(entry)
        return entry
    }

    public func delete(_ entry: CloudFileEntry) async throws {
        if let scriptedDeleteError { throw scriptedDeleteError }
        deletedRecordNames.append(entry.recordName)
        entries.removeAll { $0.recordName == entry.recordName }
    }

    public func download(_ entry: CloudFileEntry, to directory: URL) async throws -> URL {
        directory.appendingPathComponent(entry.fileName)
    }
}

public enum CloudFileCandidateFactory {
    public static func makeCandidate(for url: URL) throws -> CloudFileUploadCandidate {
        let fileName = url.lastPathComponent
        guard let kind = CloudFileKind.from(filename: fileName) else {
            throw CloudFileError.unsupportedFileType(fileName)
        }
        // Header-Validierung verhindert dass eine fälschlich als .gpx
        // benannte Datei oder eine kaputte ZIP hochgeladen wird.
        try CloudFileContentValidator.validate(url: url, expected: kind)
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return CloudFileUploadCandidate(
            url: url,
            fileName: fileName,
            kind: kind,
            sizeBytes: Int64(values.fileSize ?? 0),
            modifiedAt: values.contentModificationDate,
            sha256Hex: try StreamingSHA256.hexDigest(ofFileAt: url)
        )
    }

    public static func makeCandidate(for entry: LocalFileEntry) throws -> CloudFileUploadCandidate {
        guard let kind = CloudFileKind.from(filename: entry.fileName) else {
            throw CloudFileError.unsupportedFileType(entry.fileName)
        }
        return CloudFileUploadCandidate(
            url: entry.url,
            fileName: entry.fileName,
            kind: kind,
            sizeBytes: entry.sizeBytes,
            modifiedAt: entry.modifiedAt,
            sha256Hex: try StreamingSHA256.hexDigest(ofFileAt: entry.url)
        )
    }
}

public enum StreamingSHA256 {
    public static func hexDigest(ofFileAt url: URL, chunkSize: Int = 1024 * 1024) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256Core()
        while true {
            let data = try handle.read(upToCount: chunkSize) ?? Data()
            if data.isEmpty { break }
            hasher.update(data)
        }
        return hasher.finalizeHex()
    }
}

private struct SHA256Core {
    private var hash: [UInt32] = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    ]
    private var buffer: [UInt8] = []
    private var bitCount: UInt64 = 0

    mutating func update(_ data: Data) {
        bitCount &+= UInt64(data.count) * 8
        buffer.append(contentsOf: data)
        while buffer.count >= 64 {
            process(Array(buffer.prefix(64)))
            buffer.removeFirst(64)
        }
    }

    mutating func finalizeHex() -> String {
        var final = buffer
        final.append(0x80)
        while final.count % 64 != 56 { final.append(0) }
        for i in (0..<8).reversed() {
            final.append(UInt8((bitCount >> (UInt64(i) * 8)) & 0xff))
        }
        for chunkStart in stride(from: 0, to: final.count, by: 64) {
            process(Array(final[chunkStart..<chunkStart + 64]))
        }
        return hash.flatMap { word in
            [
                UInt8((word >> 24) & 0xff),
                UInt8((word >> 16) & 0xff),
                UInt8((word >> 8) & 0xff),
                UInt8(word & 0xff),
            ]
        }
        .map { String(format: "%02x", $0) }
        .joined()
    }

    private mutating func process(_ chunk: [UInt8]) {
        let k: [UInt32] = [
            0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
            0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
            0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
            0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
            0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
            0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
            0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
            0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
        ]
        var w = [UInt32](repeating: 0, count: 64)
        for i in 0..<16 {
            let base = i * 4
            w[i] = (UInt32(chunk[base]) << 24)
                | (UInt32(chunk[base + 1]) << 16)
                | (UInt32(chunk[base + 2]) << 8)
                | UInt32(chunk[base + 3])
        }
        for i in 16..<64 {
            let s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
            let s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
            w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
        }
        var a = hash[0], b = hash[1], c = hash[2], d = hash[3]
        var e = hash[4], f = hash[5], g = hash[6], h = hash[7]
        for i in 0..<64 {
            let s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
            let ch = (e & f) ^ ((~e) & g)
            let temp1 = h &+ s1 &+ ch &+ k[i] &+ w[i]
            let s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
            let maj = (a & b) ^ (a & c) ^ (b & c)
            let temp2 = s0 &+ maj
            h = g; g = f; f = e; e = d &+ temp1
            d = c; c = b; b = a; a = temp1 &+ temp2
        }
        hash[0] &+= a; hash[1] &+= b; hash[2] &+= c; hash[3] &+= d
        hash[4] &+= e; hash[5] &+= f; hash[6] &+= g; hash[7] &+= h
    }

    private func rotr(_ x: UInt32, _ n: UInt32) -> UInt32 {
        (x >> n) | (x << (32 - n))
    }
}

#if canImport(CloudKit)
import CloudKit

public final class CloudKitCloudFileManager: CloudFileManaging, @unchecked Sendable {
    private let containerIdentifier: String
    private let fileManager: FileManager
    private let tempDirectory: URL

    public init(containerIdentifier: String = CloudKitCloudSyncService.defaultContainerIdentifier,
                fileManager: FileManager = .default,
                tempDirectory: URL = FileManager.default.temporaryDirectory) {
        self.containerIdentifier = containerIdentifier
        self.fileManager = fileManager
        self.tempDirectory = tempDirectory
    }

    public func listCloudFiles() async throws -> [CloudFileEntry] {
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        let records = try await fetchAllRecords(database: database)
        return records.compactMap(Self.decode).sorted { $0.updatedAt > $1.updatedAt }
    }

    public func upload(_ candidate: CloudFileUploadCandidate) async throws -> CloudFileEntry {
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        if try await duplicateExists(sha256Hex: candidate.sha256Hex, database: database) {
            throw CloudFileError.duplicate(sha256Hex: candidate.sha256Hex)
        }
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let assetURL = tempDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(candidate.url.pathExtension)
        try? fileManager.removeItem(at: assetURL)
        try fileManager.copyItem(at: candidate.url, to: assetURL)
        defer { try? fileManager.removeItem(at: assetURL) }

        let now = Date()
        let record = CKRecord(
            recordType: CloudFileSchema.recordType,
            recordID: CKRecord.ID(recordName: CloudFileSchema.recordName(sha256Hex: candidate.sha256Hex))
        )
        record[CloudFileSchema.Field.schemaVersion] = CloudFileSchema.schemaVersion as CKRecordValue
        record[CloudFileSchema.Field.fileName] = candidate.fileName as CKRecordValue
        record[CloudFileSchema.Field.fileKind] = candidate.kind.rawValue as CKRecordValue
        record[CloudFileSchema.Field.sizeBytes] = candidate.sizeBytes as CKRecordValue
        record[CloudFileSchema.Field.sha256Hex] = candidate.sha256Hex as CKRecordValue
        record[CloudFileSchema.Field.createdAt] = now as CKRecordValue
        record[CloudFileSchema.Field.updatedAt] = now as CKRecordValue
        if let modifiedAt = candidate.modifiedAt {
            record[CloudFileSchema.Field.originalModifiedAt] = modifiedAt as CKRecordValue
        }
        record[CloudFileSchema.Field.asset] = CKAsset(fileURL: assetURL)

        let expectedID = record.recordID
        let (saveResults, _) = try await database.modifyRecords(
            saving: [record],
            deleting: [],
            savePolicy: .changedKeys,
            atomically: true
        )
        try ICloudCloudKitMVPResultValidator.assertSaved(recordID: expectedID, in: saveResults)
        guard let entry = Self.decode(record) else {
            throw CloudFileError.unsupportedFileType(candidate.fileName)
        }
        return entry
    }

    public func delete(_ entry: CloudFileEntry) async throws {
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        let recordID = CKRecord.ID(recordName: entry.recordName)
        let (_, deleteResults) = try await database.modifyRecords(
            saving: [],
            deleting: [recordID],
            savePolicy: .changedKeys,
            atomically: true
        )
        do {
            try ICloudCloudKitMVPResultValidator.assertDeleted(recordID: recordID, in: deleteResults)
        } catch {
            if (error as NSError).domain == "CKErrorDomain",
               (error as NSError).code == 11 {
                return
            }
            throw error
        }
    }

    public func download(_ entry: CloudFileEntry, to directory: URL) async throws -> URL {
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        let record = try await database.record(for: CKRecord.ID(recordName: entry.recordName))
        guard let asset = record[CloudFileSchema.Field.asset] as? CKAsset,
              let source = asset.fileURL else {
            throw CloudFileError.missingAsset
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(entry.fileName)
        try? fileManager.removeItem(at: destination)
        try fileManager.copyItem(at: source, to: destination)
        return destination
    }

    private func duplicateExists(sha256Hex: String, database: CKDatabase) async throws -> Bool {
        let predicate = NSPredicate(format: "%K == %@", CloudFileSchema.Field.sha256Hex, sha256Hex)
        let query = CKQuery(recordType: CloudFileSchema.recordType, predicate: predicate)
        do {
            let page = try await database.records(matching: query, resultsLimit: 1)
            return page.matchResults.contains { _, result in
                if case .success = result { return true }
                return false
            }
        } catch {
            if (error as NSError).domain == "CKErrorDomain",
               (error as NSError).code == 11 {
                return false
            }
            throw error
        }
    }

    private func fetchAllRecords(database: CKDatabase) async throws -> [CKRecord] {
        var collected: [CKRecord] = []
        let query = CKQuery(recordType: CloudFileSchema.recordType, predicate: NSPredicate(format: "TRUEPREDICATE"))
        do {
            let firstPage = try await database.records(matching: query, resultsLimit: 200)
            collected.append(contentsOf: try records(from: firstPage.matchResults))
            var cursor = firstPage.queryCursor
            while let next = cursor {
                let page = try await database.records(continuingMatchFrom: next, resultsLimit: 200)
                collected.append(contentsOf: try records(from: page.matchResults))
                cursor = page.queryCursor
            }
        } catch {
            if (error as NSError).domain == "CKErrorDomain",
               (error as NSError).code == 11 {
                return []
            }
            throw error
        }
        return collected
    }

    private func records(
        from matchResults: [(CKRecord.ID, Result<CKRecord, Error>)]
    ) throws -> [CKRecord] {
        try matchResults.map { _, result in try result.get() }
    }

    private static func decode(_ record: CKRecord) -> CloudFileEntry? {
        guard let fileName = record[CloudFileSchema.Field.fileName] as? String,
              let kindRaw = record[CloudFileSchema.Field.fileKind] as? String,
              let kind = CloudFileKind(rawValue: kindRaw),
              let sha = record[CloudFileSchema.Field.sha256Hex] as? String
        else { return nil }
        let size = (record[CloudFileSchema.Field.sizeBytes] as? Int64)
            ?? (record[CloudFileSchema.Field.sizeBytes] as? Int).map(Int64.init)
            ?? (record[CloudFileSchema.Field.sizeBytes] as? NSNumber)?.int64Value
            ?? 0
        let createdAt = (record[CloudFileSchema.Field.createdAt] as? Date) ?? Date(timeIntervalSince1970: 0)
        let updatedAt = (record[CloudFileSchema.Field.updatedAt] as? Date) ?? createdAt
        return CloudFileEntry(
            id: sha,
            recordName: record.recordID.recordName,
            fileName: fileName,
            kind: kind,
            sizeBytes: size,
            sha256Hex: sha,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
#endif
