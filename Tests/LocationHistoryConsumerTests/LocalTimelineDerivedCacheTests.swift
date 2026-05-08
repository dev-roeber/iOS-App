import Foundation
import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Phase-8B — `derived_cache` Tabelle + CRUD-APIs.
final class LocalTimelineDerivedCacheTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTDerivedCache-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    private func makeStore(_ name: String = "store.sqlite") throws -> LocalTimelineStore {
        try LocalTimelineStore(url: tempDir.appendingPathComponent(name))
    }

    private func seedImport(_ store: LocalTimelineStore, id: String = "imp-A") throws {
        try store.insertImport(.init(id: id, sourceFilename: "x.json",
                                     createdAt: "2024-01-01T00:00:00Z"))
    }

    func testSchemaCreatesDerivedCacheTable() throws {
        let store = try makeStore()
        defer { store.close() }
        XCTAssertEqual(try store.countDerivedCache(), 0)
        let names = Set(try store.indexNames(forTable: "derived_cache"))
        XCTAssertTrue(names.contains("idx_derived_cache_import_kind_key"))
        XCTAssertTrue(names.contains("idx_derived_cache_kind_created"))
    }

    func testPutAndReadRoundTrip() throws {
        let store = try makeStore()
        defer { store.close() }
        try seedImport(store)
        let blob = Data([0x01, 0x02, 0x03, 0x04])
        try store.putDerivedCache(.init(
            id: "c-1", importId: "imp-A", cacheKind: "heatmap-lod", cacheKey: "k1",
            createdAt: "2024-02-01T00:00:00Z", version: 1,
            payloadEncoding: "heatmap-lod-v1", payloadBlob: blob
        ))
        let row = try store.derivedCache(importId: "imp-A",
                                         cacheKind: "heatmap-lod",
                                         cacheKey: "k1")
        XCTAssertEqual(row?.id, "c-1")
        XCTAssertEqual(row?.payloadBlob, blob)
        XCTAssertEqual(row?.version, 1)
        XCTAssertEqual(try store.countDerivedCache(), 1)
    }

    func testCacheKeyLookupReturnsNewestVersion() throws {
        let store = try makeStore()
        defer { store.close() }
        try seedImport(store)
        try store.putDerivedCache(.init(
            id: "c-v1", importId: "imp-A", cacheKind: "heatmap-lod", cacheKey: "k1",
            createdAt: "2024-02-01T00:00:00Z", version: 1,
            payloadEncoding: "v1", payloadBlob: Data([0xAA])))
        try store.putDerivedCache(.init(
            id: "c-v2", importId: "imp-A", cacheKind: "heatmap-lod", cacheKey: "k1",
            createdAt: "2024-02-02T00:00:00Z", version: 2,
            payloadEncoding: "v1", payloadBlob: Data([0xBB])))
        let row = try store.derivedCache(importId: "imp-A",
                                         cacheKind: "heatmap-lod",
                                         cacheKey: "k1")
        XCTAssertEqual(row?.id, "c-v2")
        XCTAssertEqual(row?.version, 2)
    }

    func testDeleteByImportAndKind() throws {
        let store = try makeStore()
        defer { store.close() }
        try seedImport(store)
        try seedImport(store, id: "imp-B")
        try store.putDerivedCache(.init(
            id: "c-A", importId: "imp-A", cacheKind: "heatmap-lod", cacheKey: "k",
            createdAt: "2024-02-01T00:00:00Z", version: 1,
            payloadEncoding: "v1", payloadBlob: Data([1])))
        try store.putDerivedCache(.init(
            id: "c-B", importId: "imp-B", cacheKind: "heatmap-lod", cacheKey: "k",
            createdAt: "2024-02-01T00:00:00Z", version: 1,
            payloadEncoding: "v1", payloadBlob: Data([2])))
        try store.deleteDerivedCache(importId: "imp-A", cacheKind: "heatmap-lod")
        XCTAssertNil(try store.derivedCache(importId: "imp-A",
                                            cacheKind: "heatmap-lod", cacheKey: "k"))
        XCTAssertNotNil(try store.derivedCache(importId: "imp-B",
                                                cacheKind: "heatmap-lod", cacheKey: "k"))
    }

    func testDeleteAllNukesDerivedCache() throws {
        let store = try makeStore()
        defer { store.close() }
        try seedImport(store)
        try store.putDerivedCache(.init(
            id: "c-1", importId: "imp-A", cacheKind: "k", cacheKey: "x",
            createdAt: "t", version: 1, payloadEncoding: "v1", payloadBlob: Data([9])))
        XCTAssertEqual(try store.countDerivedCache(), 1)
        try store.deleteAll()
        XCTAssertEqual(try store.countDerivedCache(), 0)
    }

    func testForeignKeyCascadeOnImportDelete() throws {
        let store = try makeStore()
        defer { store.close() }
        try seedImport(store)
        try store.putDerivedCache(.init(
            id: "c-1", importId: "imp-A", cacheKind: "k", cacheKey: "x",
            createdAt: "t", version: 1, payloadEncoding: "v1", payloadBlob: Data([9])))
        try store.deleteImport(id: "imp-A")
        XCTAssertEqual(try store.countDerivedCache(), 0)
    }

    func testGlobalScopeWhenImportIdIsNull() throws {
        let store = try makeStore()
        defer { store.close() }
        try store.putDerivedCache(.init(
            id: "c-global", importId: nil, cacheKind: "k", cacheKey: "x",
            createdAt: "t", version: 1, payloadEncoding: "v1", payloadBlob: Data([5])))
        let row = try store.derivedCache(importId: nil, cacheKind: "k", cacheKey: "x")
        XCTAssertEqual(row?.id, "c-global")
    }
}
