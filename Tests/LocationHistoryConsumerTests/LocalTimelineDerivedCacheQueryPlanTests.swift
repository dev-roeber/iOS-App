import Foundation
import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Train L, Phase 3 — verifies that the prune/lookup query paths against
/// `derived_cache` exercise one of the `idx_derived_cache_*` indexes.
/// The query-plan text varies between SQLite versions, so we match
/// permissively (substring on `idx_derived_cache_`).
final class LocalTimelineDerivedCacheQueryPlanTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTPlan-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    private func makeStore() throws -> LocalTimelineStore {
        try LocalTimelineStore(url: tempDir.appendingPathComponent("plan.sqlite"))
    }

    private func seedRow(_ store: LocalTimelineStore, id: String, kind: String, key: String, version: Int) throws {
        try store.putDerivedCache(.init(
            id: id, importId: nil, cacheKind: kind, cacheKey: key,
            createdAt: "2024-02-01T00:00:00Z", version: version,
            payloadEncoding: "v1", payloadBlob: Data([0x01])
        ))
    }

    /// Sanity check the introspection helper itself returns something.
    func testQueryPlanHelperReturnsNonEmpty() throws {
        let store = try makeStore()
        defer { store.close() }
        let plan = try store.queryPlan(for: "SELECT id FROM derived_cache WHERE cache_kind = 'k' AND cache_key = 'x';")
        XCTAssertFalse(plan.isEmpty, "EXPLAIN QUERY PLAN must return at least one row.")
    }

    /// The `derivedCache(importId:cacheKind:cacheKey:)` lookup is the
    /// hottest read path; it should be served by an index, never via a
    /// full table scan.
    func testCacheLookupAvoidsTableScan() throws {
        let store = try makeStore()
        defer { store.close() }
        for i in 0..<32 {
            try seedRow(store, id: "row-\(i)", kind: "heatmap-lod", key: "k\(i % 4)", version: 1)
        }
        let plan = try store.queryPlan(for: """
        SELECT id, payload_encoding, payload_blob, version, created_at \
        FROM derived_cache \
        WHERE cache_kind = 'heatmap-lod' AND cache_key = 'k1' \
        ORDER BY version DESC LIMIT 1;
        """)
        let joined = plan.joined(separator: " | ")
        XCTAssertTrue(joined.contains("idx_derived_cache_"),
                      "Lookup plan should reference an idx_derived_cache_* index. Plan was: \(joined)")
    }

    /// `pruneDerivedCache(maxEntries:cacheKind:)` issues a kind-scoped
    /// `ORDER BY created_at, version LIMIT` against `derived_cache`. The
    /// Train-I covering index `idx_derived_cache_kind_version_created`
    /// exists to serve this exact path; the plan must reference some
    /// derived-cache index rather than scanning the table.
    func testPruneOrderingUsesDerivedCacheIndex() throws {
        let store = try makeStore()
        defer { store.close() }
        for i in 0..<16 {
            try seedRow(store, id: "p-\(i)", kind: "heatmap-lod", key: "k", version: i)
        }
        let plan = try store.queryPlan(for: """
        SELECT id FROM derived_cache WHERE cache_kind = 'heatmap-lod' \
        ORDER BY created_at ASC, version ASC LIMIT 4;
        """)
        let joined = plan.joined(separator: " | ")
        XCTAssertTrue(joined.contains("idx_derived_cache_"),
                      "Prune plan should reference an idx_derived_cache_* index. Plan was: \(joined)")
    }
}
