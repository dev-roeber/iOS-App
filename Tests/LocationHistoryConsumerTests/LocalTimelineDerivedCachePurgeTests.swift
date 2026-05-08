import Foundation
import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Phase-10C — Purge / Prune APIs auf `derived_cache`.
final class LocalTimelineDerivedCachePurgeTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTDerivedCachePurge-\(UUID().uuidString)", isDirectory: true)
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

    /// Insert `count` global cache rows with strictly monotonically increasing
    /// `createdAt` strings (lexicographically ordered, valid ISO-8601 prefix).
    /// `seq` controls the seconds-from-epoch offset so callers can interleave
    /// disjoint kinds without timestamp collisions.
    @discardableResult
    private func seedCacheRows(_ store: LocalTimelineStore,
                               count: Int,
                               cacheKind: String = "heatmap-lod",
                               idPrefix: String = "row",
                               importId: String? = nil,
                               seqStart: Int = 0) throws -> [String] {
        var ids: [String] = []
        // Use a wide minute/second range so even count==100 fits inside
        // 2026-01-01T00:00:00Z..2026-01-01T01:40:00Z. ISO-8601 lexicographic
        // ordering matches numeric ordering when zero-padded, which it is.
        for i in 0..<count {
            let total = seqStart + i
            let hh = (total / 3600) % 24
            let mm = (total / 60) % 60
            let ss = total % 60
            let stamp = String(format: "2026-01-01T%02d:%02d:%02dZ", hh, mm, ss)
            let id = "\(idPrefix)-\(i)"
            ids.append(id)
            try store.putDerivedCache(.init(
                id: id, importId: importId,
                cacheKind: cacheKind, cacheKey: "k-\(i)",
                createdAt: stamp, version: 1, payloadEncoding: "v1",
                payloadBlob: Data([UInt8(i & 0xff)])
            ))
        }
        return ids
    }

    // MARK: - prune

    func testPruneMaxEntriesNoOpUnderLimit() throws {
        let store = try makeStore()
        defer { store.close() }
        try seedCacheRows(store, count: 3)
        let deleted = try store.pruneDerivedCache(maxEntries: 10)
        XCTAssertEqual(deleted, 0)
        XCTAssertEqual(try store.countDerivedCache(), 3)
    }

    func testPruneMaxEntriesAtLimit() throws {
        let store = try makeStore()
        defer { store.close() }
        try seedCacheRows(store, count: 5)
        let deleted = try store.pruneDerivedCache(maxEntries: 5)
        XCTAssertEqual(deleted, 0)
        XCTAssertEqual(try store.countDerivedCache(), 5)
    }

    func testPruneMaxEntriesDeletesOldestFirst() throws {
        let store = try makeStore()
        defer { store.close() }
        // 6 rows: createdAt 2026-01-01 .. 2026-01-06
        let ids = try seedCacheRows(store, count: 6)
        let deleted = try store.pruneDerivedCache(maxEntries: 2)
        XCTAssertEqual(deleted, 4)
        XCTAssertEqual(try store.countDerivedCache(), 2)

        // Newest two are ids[4] and ids[5]; first four must be gone.
        for staleId in ids.prefix(4) {
            // Lookup via cache_key (each row has its own key). The row's
            // cacheKey was "k-<index>"; index = position in ids.
            let idx = ids.firstIndex(of: staleId)!
            XCTAssertNil(try store.derivedCache(importId: nil,
                                                cacheKind: "heatmap-lod",
                                                cacheKey: "k-\(idx)"))
        }
        XCTAssertNotNil(try store.derivedCache(importId: nil,
                                                cacheKind: "heatmap-lod",
                                                cacheKey: "k-4"))
        XCTAssertNotNil(try store.derivedCache(importId: nil,
                                                cacheKind: "heatmap-lod",
                                                cacheKey: "k-5"))
    }

    func testPruneCacheKindScoped() throws {
        let store = try makeStore()
        defer { store.close() }
        try seedCacheRows(store, count: 3, cacheKind: "heatmap-lod",
                          idPrefix: "h", seqStart: 0)
        try seedCacheRows(store, count: 3, cacheKind: "other",
                          idPrefix: "o", seqStart: 1000)
        let deleted = try store.pruneDerivedCache(maxEntries: 1,
                                                   cacheKind: "heatmap-lod")
        XCTAssertEqual(deleted, 2)
        XCTAssertEqual(try store.countDerivedCache(), 4) // 1 + 3
        // Untouched kind: still 3
        let otherDeleted = try store.pruneDerivedCache(maxEntries: 100,
                                                       cacheKind: "other")
        XCTAssertEqual(otherDeleted, 0)
    }

    // MARK: - deleteOlderThan

    func testDeleteOlderThan() throws {
        let store = try makeStore()
        defer { store.close() }
        let stamps = ["2026-01-01T00:00:00Z",
                      "2026-02-01T00:00:00Z",
                      "2026-03-01T00:00:00Z",
                      "2026-04-01T00:00:00Z"]
        for (i, ts) in stamps.enumerated() {
            try store.putDerivedCache(.init(
                id: "r-\(i)", importId: nil,
                cacheKind: "heatmap-lod", cacheKey: "k-\(i)",
                createdAt: ts, version: 1, payloadEncoding: "v1",
                payloadBlob: Data([UInt8(i)])
            ))
        }
        XCTAssertEqual(try store.countDerivedCache(), 4)
        try store.deleteDerivedCache(olderThan: "2026-03-01T00:00:00Z")
        XCTAssertEqual(try store.countDerivedCache(), 2)
        XCTAssertNil(try store.derivedCache(importId: nil,
                                            cacheKind: "heatmap-lod",
                                            cacheKey: "k-0"))
        XCTAssertNil(try store.derivedCache(importId: nil,
                                            cacheKind: "heatmap-lod",
                                            cacheKey: "k-1"))
        XCTAssertNotNil(try store.derivedCache(importId: nil,
                                                cacheKind: "heatmap-lod",
                                                cacheKey: "k-2"))
        XCTAssertNotNil(try store.derivedCache(importId: nil,
                                                cacheKind: "heatmap-lod",
                                                cacheKey: "k-3"))
    }

    func testDeleteOlderThanCacheKindScoped() throws {
        let store = try makeStore()
        defer { store.close() }
        // 2 old heatmap-lod, 1 new heatmap-lod, 2 old "other"
        try store.putDerivedCache(.init(
            id: "h-old-1", importId: nil, cacheKind: "heatmap-lod",
            cacheKey: "h1", createdAt: "2026-01-01T00:00:00Z",
            version: 1, payloadEncoding: "v1", payloadBlob: Data([1])))
        try store.putDerivedCache(.init(
            id: "h-old-2", importId: nil, cacheKind: "heatmap-lod",
            cacheKey: "h2", createdAt: "2026-01-15T00:00:00Z",
            version: 1, payloadEncoding: "v1", payloadBlob: Data([2])))
        try store.putDerivedCache(.init(
            id: "h-new", importId: nil, cacheKind: "heatmap-lod",
            cacheKey: "h3", createdAt: "2026-05-01T00:00:00Z",
            version: 1, payloadEncoding: "v1", payloadBlob: Data([3])))
        try store.putDerivedCache(.init(
            id: "o-old-1", importId: nil, cacheKind: "other",
            cacheKey: "o1", createdAt: "2026-01-02T00:00:00Z",
            version: 1, payloadEncoding: "v1", payloadBlob: Data([4])))
        try store.putDerivedCache(.init(
            id: "o-old-2", importId: nil, cacheKind: "other",
            cacheKey: "o2", createdAt: "2026-01-20T00:00:00Z",
            version: 1, payloadEncoding: "v1", payloadBlob: Data([5])))

        try store.deleteDerivedCache(olderThan: "2026-04-01T00:00:00Z",
                                      cacheKind: "heatmap-lod")
        // Heatmap-lod: only h-new remains; "other": both still there.
        XCTAssertEqual(try store.countDerivedCache(), 3)
        XCTAssertNil(try store.derivedCache(importId: nil,
                                            cacheKind: "heatmap-lod",
                                            cacheKey: "h1"))
        XCTAssertNil(try store.derivedCache(importId: nil,
                                            cacheKind: "heatmap-lod",
                                            cacheKey: "h2"))
        XCTAssertNotNil(try store.derivedCache(importId: nil,
                                                cacheKind: "heatmap-lod",
                                                cacheKey: "h3"))
        XCTAssertNotNil(try store.derivedCache(importId: nil,
                                                cacheKind: "other",
                                                cacheKey: "o1"))
        XCTAssertNotNil(try store.derivedCache(importId: nil,
                                                cacheKind: "other",
                                                cacheKey: "o2"))
    }

    // MARK: - deleteAll re-confirmation

    func testDeleteAllRemovesDerivedCache() throws {
        let store = try makeStore()
        defer { store.close() }
        try seedImport(store)
        try store.putDerivedCache(.init(
            id: "scoped", importId: "imp-A", cacheKind: "heatmap-lod",
            cacheKey: "k", createdAt: "2026-01-01T00:00:00Z",
            version: 1, payloadEncoding: "v1", payloadBlob: Data([1])))
        try seedCacheRows(store, count: 4, cacheKind: "k2",
                          idPrefix: "g", seqStart: 0)
        XCTAssertEqual(try store.countDerivedCache(), 5)
        try store.deleteAll()
        XCTAssertEqual(try store.countDerivedCache(), 0)
    }

    // MARK: - bounded behaviour

    func testRepeatedPruneIsBounded() throws {
        let store = try makeStore()
        defer { store.close() }
        try seedCacheRows(store, count: 100, cacheKind: "heatmap-lod",
                          idPrefix: "r", seqStart: 0)
        XCTAssertEqual(try store.countDerivedCache(), 100)
        let firstDeleted = try store.pruneDerivedCache(maxEntries: 10)
        XCTAssertEqual(firstDeleted, 90)
        XCTAssertEqual(try store.countDerivedCache(), 10)

        let secondDeleted = try store.pruneDerivedCache(maxEntries: 10)
        XCTAssertEqual(secondDeleted, 0)
        XCTAssertEqual(try store.countDerivedCache(), 10)
    }
}
