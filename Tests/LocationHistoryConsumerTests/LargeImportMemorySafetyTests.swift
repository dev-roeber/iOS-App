import XCTest
import ZIPFoundation
import CoreLocation
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Coverage for the launch-OOM safety net introduced after a real-iPhone
/// Jetsam kill on auto-restore of a 46 MB Google Timeline JSON. Three
/// independent guarantees:
///
/// 1. Format detection no longer pays a full `JSONSerialization` parse.
/// 2. Auto-restore mode rejects oversized files before any data is read.
/// 3. The query fast path skips per-day allocation when no filter is active.
final class LargeImportMemorySafetyTests: XCTestCase {

    // MARK: - 1. Sniffer-only format detection

    func testIsGoogleTimelineSnifferAcceptsLargeArrayWithoutFullParse() throws {
        // Build a JSON-array head followed by a giant garbage tail. If the
        // sniffer were still calling JSONSerialization.jsonObject(with:) the
        // tail would parse-fail and return false. With a head-only sniff it
        // sees `[` and returns true.
        var data = Data("[{\"startTime\":\"2026-01-01T00:00:00Z\"}".utf8)
        // Append 8 MB of structurally invalid JSON tail.
        data.append(Data(repeating: UInt8(ascii: "x"), count: 8 * 1024 * 1024))
        XCTAssertTrue(GoogleTimelineConverter.isGoogleTimeline(data))
    }

    func testIsGoogleTimelineSnifferRejectsObjects() {
        let object = Data("   {\"key\":\"value\"}".utf8)
        XCTAssertFalse(GoogleTimelineConverter.isGoogleTimeline(object))
    }

    func testIsGoogleTimelineSnifferIgnoresWhitespaceAndBOM() {
        let withBOM = Data([0xEF, 0xBB, 0xBF]) + Data("  \n\t[".utf8)
        XCTAssertTrue(GoogleTimelineConverter.isGoogleTimeline(withBOM))

        let bomThenObject = Data([0xEF, 0xBB, 0xBF]) + Data(" {".utf8)
        XCTAssertFalse(GoogleTimelineConverter.isGoogleTimeline(bomThenObject))
    }

    func testIsJSONObjectSnifferAcceptsLargeObjectWithoutFullParse() {
        var data = Data("{\"schema_version\":\"1.0\"".utf8)
        data.append(Data(repeating: UInt8(ascii: "y"), count: 8 * 1024 * 1024))
        XCTAssertTrue(GoogleTimelineConverter.isJSONObject(data))
    }

    func testIsJSONObjectSnifferRejectsArrays() {
        XCTAssertFalse(GoogleTimelineConverter.isJSONObject(Data(" [".utf8)))
    }

    func testSnifferEmptyDataReturnsFalse() {
        XCTAssertFalse(GoogleTimelineConverter.isGoogleTimeline(Data()))
        XCTAssertFalse(GoogleTimelineConverter.isJSONObject(Data()))
    }

    // MARK: - 2. Auto-restore size guard (direct file)

    func testAutoRestoreSkipsOversizedDirectJSONFile() async throws {
        let url = try makeTempFile(name: "huge_timeline.json", payloadByteCount: 60 * 1024 * 1024)
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            _ = try await AppContentLoader.loadImportedContent(from: url, autoRestoreMode: true)
            XCTFail("Auto-restore should refuse files above the conservative ceiling")
        } catch let error as AppContentLoaderError {
            guard case .autoRestoreSkippedLargeFile = error else {
                return XCTFail("Expected autoRestoreSkippedLargeFile, got \(error)")
            }
        }
    }

    func testManualLoadDoesNotApplyAutoRestoreCeiling() async throws {
        // 60 MB is above the autoRestoreMaxFileSizeBytes ceiling (50 MB) but
        // well below the manual ceiling (256 MB). It should NOT be rejected
        // for size — it will fail later because the bytes are not valid JSON,
        // but the failure must not be the auto-restore size guard.
        let url = try makeTempFile(name: "manual_60mb.json", payloadByteCount: 60 * 1024 * 1024)
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            _ = try await AppContentLoader.loadImportedContent(from: url, autoRestoreMode: false)
            XCTFail("Garbage payload should still fail to decode")
        } catch let error as AppContentLoaderError {
            if case .autoRestoreSkippedLargeFile = error {
                XCTFail("Manual load must not trip the auto-restore size guard")
            }
        }
    }

    // MARK: - 3. Auto-restore size guard (ZIP entry)

    func testAutoRestoreSkipsOversizedZipEntry() async throws {
        let zipURL = try makeZipWithLargeJSONEntry(
            name: "location-history.json",
            payloadByteCount: 60 * 1024 * 1024
        )
        defer { try? FileManager.default.removeItem(at: zipURL) }

        do {
            _ = try await AppContentLoader.loadImportedContent(from: zipURL, autoRestoreMode: true)
            XCTFail("Auto-restore should refuse ZIPs whose JSON entry is above ceiling")
        } catch let error as AppContentLoaderError {
            guard case .autoRestoreSkippedLargeFile = error else {
                return XCTFail("Expected autoRestoreSkippedLargeFile, got \(error)")
            }
        }
    }

    // MARK: - 3b. Auto-restore Google-Timeline-raw guard (independent of size)

    /// Real-world failure case: a ~46 MB Google Timeline JSON sits below the
    /// 50 MB size cap, but parsing it through GoogleTimelineConverter still
    /// allocates a full intermediate dictionary tree and Jetsam-kills the
    /// app on launch. Auto-restore must therefore refuse raw Google Timeline
    /// files regardless of size.
    func testAutoRestoreSkipsRawGoogleTimelineUnderSizeCap() async throws {
        let url = try makeGoogleTimelineLikeFile(
            name: "location-history.json",
            payloadByteCount: 46 * 1024 * 1024
        )
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            _ = try await AppContentLoader.loadImportedContent(from: url, autoRestoreMode: true)
            XCTFail("Auto-restore must refuse raw Google Timeline regardless of size")
        } catch let error as AppContentLoaderError {
            guard case .autoRestoreSkippedLargeFile = error else {
                return XCTFail("Expected autoRestoreSkippedLargeFile, got \(error)")
            }
        }
    }

    func testAutoRestoreSkipsRawGoogleTimelineZipEntryUnderSizeCap() async throws {
        let zipURL = try makeZipWithGoogleTimelineEntry(
            name: "location-history.json",
            payloadByteCount: 46 * 1024 * 1024
        )
        defer { try? FileManager.default.removeItem(at: zipURL) }

        do {
            _ = try await AppContentLoader.loadImportedContent(from: zipURL, autoRestoreMode: true)
            XCTFail("Auto-restore must refuse ZIPs containing raw Google Timeline regardless of size")
        } catch let error as AppContentLoaderError {
            guard case .autoRestoreSkippedLargeFile = error else {
                return XCTFail("Expected autoRestoreSkippedLargeFile, got \(error)")
            }
        }
    }

    /// Counter-example: a small AppExport JSON object (`{ ... }`) that is
    /// not Google Timeline must remain auto-restore eligible. The file here
    /// is intentionally not a valid AppExport — we only assert that the
    /// failure path is NOT the auto-restore guard. Actual decoding may fail
    /// later, which is fine.
    func testAutoRestoreAllowsSmallAppExportLikeFile() async throws {
        let url = try makeAppExportLikeFile(name: "app_export.json", payloadByteCount: 256 * 1024)
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            _ = try await AppContentLoader.loadImportedContent(from: url, autoRestoreMode: true)
            // Decoding will likely fail (synthetic object), but that's not the guard's job.
        } catch let error as AppContentLoaderError {
            if case .autoRestoreSkippedLargeFile = error {
                XCTFail("Small AppExport-like JSON must not trip auto-restore guard")
            }
        }
    }

    /// Manual import of a raw Google Timeline file must still go through —
    /// the auto-restore-only guards must not bleed into the manual path.
    func testManualLoadAllowsRawGoogleTimeline() async throws {
        let url = try makeGoogleTimelineLikeFile(
            name: "location-history.json",
            payloadByteCount: 1 * 1024 * 1024
        )
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            _ = try await AppContentLoader.loadImportedContent(from: url, autoRestoreMode: false)
            // May still fail because synthetic payload is not a valid Timeline,
            // but that failure must NOT be the auto-restore guard.
        } catch let error as AppContentLoaderError {
            if case .autoRestoreSkippedLargeFile = error {
                XCTFail("Manual load must not trip auto-restore guard")
            }
        }
    }

    // MARK: - 4. Query fast path

    func testProjectedDaysFastPathReturnsSortedDaysWithoutCopying() {
        let export = makeMultiDayExport(dayCount: 32)
        let summaries = AppExportQueries.daySummaries(from: export)
        XCTAssertEqual(summaries.count, 32)
        // Ensure ascending date order — the fast path must still sort.
        let dates = summaries.map(\.date)
        XCTAssertEqual(dates, dates.sorted())
    }

    func testIsPassthroughTrueForDefaultFilter() {
        let filter = AppExportQueryFilter()
        XCTAssertTrue(filter.isPassthrough)
    }

    func testIsPassthroughFalseWhenAnyConstraintSet() {
        XCTAssertFalse(AppExportQueryFilter(fromDate: "2026-01-01").isPassthrough)
        XCTAssertFalse(AppExportQueryFilter(activityTypes: ["walking"]).isPassthrough)
        XCTAssertFalse(AppExportQueryFilter(maxAccuracyM: 50).isPassthrough)
        XCTAssertFalse(AppExportQueryFilter(limit: 10).isPassthrough)
    }

    // MARK: - 5. Bounded OverviewMap candidate storage

    func testOverviewMapStrideDecimateRespectsCap() {
        let coords = (0..<5000).map { i in
            CLLocationCoordinate2D(latitude: 50.0 + Double(i) * 0.0001, longitude: 8.0)
        }
        let decimated = OverviewMapPreparation.strideDecimate(coords, maxPoints: 256)
        XCTAssertLessThanOrEqual(decimated.count, 256)
        XCTAssertGreaterThan(decimated.count, 1)
        // First and last must be preserved so the polyline still reaches both
        // ends of the original track.
        XCTAssertEqual(decimated.first?.latitude, coords.first?.latitude)
        XCTAssertEqual(decimated.last?.latitude, coords.last?.latitude)
    }

    func testOverviewMapStrideDecimatePassesShortPathsThrough() {
        let coords = [
            CLLocationCoordinate2D(latitude: 50.0, longitude: 8.0),
            CLLocationCoordinate2D(latitude: 50.1, longitude: 8.1)
        ]
        let decimated = OverviewMapPreparation.strideDecimate(coords, maxPoints: 256)
        XCTAssertEqual(decimated.count, coords.count)
    }

    // MARK: - Helpers

    private func makeTempFile(name: String, payloadByteCount: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent(name)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let chunk = Data(repeating: UInt8(ascii: "a"), count: 1024 * 1024)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        var written = 0
        while written < payloadByteCount {
            let remaining = payloadByteCount - written
            if remaining >= chunk.count {
                try handle.write(contentsOf: chunk)
                written += chunk.count
            } else {
                try handle.write(contentsOf: chunk.prefix(remaining))
                written += remaining
            }
        }
        return url
    }

    /// Writes a file whose first byte is `[` so the sniffer classifies it as
    /// a Google Timeline raw export, padded to `payloadByteCount` with
    /// arbitrary bytes.
    private func makeGoogleTimelineLikeFile(name: String, payloadByteCount: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent(name)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        // Realistic Google Timeline head, then garbage padding.
        try handle.write(contentsOf: Data("[{\"startTime\":\"2026-01-01T00:00:00Z\"}".utf8))
        let chunk = Data(repeating: UInt8(ascii: "x"), count: 1024 * 1024)
        var written = 38
        while written < payloadByteCount {
            let remaining = payloadByteCount - written
            if remaining >= chunk.count {
                try handle.write(contentsOf: chunk)
                written += chunk.count
            } else {
                try handle.write(contentsOf: chunk.prefix(remaining))
                written += remaining
            }
        }
        return url
    }

    /// Writes a file whose first byte is `{` so the sniffer classifies it as
    /// an AppExport-like JSON object (not Google Timeline).
    private func makeAppExportLikeFile(name: String, payloadByteCount: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent(name)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.write(contentsOf: Data("{\"schema_version\":\"1.0\",\"_pad\":\"".utf8))
        let chunk = Data(repeating: UInt8(ascii: "a"), count: 1024 * 1024)
        var written = 32
        while written < payloadByteCount {
            let remaining = payloadByteCount - written
            if remaining >= chunk.count {
                try handle.write(contentsOf: chunk)
                written += chunk.count
            } else {
                try handle.write(contentsOf: chunk.prefix(remaining))
                written += remaining
            }
        }
        try handle.write(contentsOf: Data("\"}".utf8))
        return url
    }

    private func makeZipWithGoogleTimelineEntry(name: String, payloadByteCount: Int) throws -> URL {
        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("synthetic_timeline.zip")
        try FileManager.default.createDirectory(
            at: zipURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let archive = try Archive(url: zipURL, accessMode: .create)
        var payload = Data("[{\"startTime\":\"2026-01-01T00:00:00Z\"}".utf8)
        if payload.count < payloadByteCount {
            payload.append(Data(repeating: UInt8(ascii: "x"), count: payloadByteCount - payload.count))
        }
        try archive.addEntry(
            with: name,
            type: .file,
            uncompressedSize: Int64(payload.count),
            compressionMethod: .none
        ) { position, size in
            let start = Int(position)
            let end = min(start + size, payload.count)
            return payload.subdata(in: start..<end)
        }
        return zipURL
    }

    private func makeZipWithLargeJSONEntry(name: String, payloadByteCount: Int) throws -> URL {
        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("synthetic.zip")
        try FileManager.default.createDirectory(
            at: zipURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let archive = try Archive(url: zipURL, accessMode: .create)
        let payload = Data(repeating: UInt8(ascii: "z"), count: payloadByteCount)
        try archive.addEntry(
            with: name,
            type: .file,
            uncompressedSize: Int64(payload.count),
            compressionMethod: .none
        ) { position, size in
            let start = Int(position)
            let end = min(start + size, payload.count)
            return payload.subdata(in: start..<end)
        }
        return zipURL
    }

    private func makeMultiDayExport(dayCount: Int) -> AppExport {
        let days: [Day] = (0..<dayCount).map { i in
            let dateString = String(format: "2026-01-%02d", i + 1)
            return Day(date: dateString, visits: [], activities: [], paths: [])
        }
        let shuffled = days.shuffled() // verify fast path still sorts
        return AppExport(
            schemaVersion: .v1_0,
            meta: Meta(
                exportedAt: "2026-01-01T00:00:00Z",
                toolVersion: "test/1.0",
                source: Source(zipBasename: nil, zipPath: nil, inputFormat: "test"),
                output: Output(outDir: nil),
                config: ExportConfig(
                    mode: "all",
                    splitMidnight: nil,
                    splitMode: "daily",
                    exportFormat: ["json"],
                    inputFormat: "test"
                ),
                filters: ExportFilters(
                    fromDate: nil,
                    toDate: nil,
                    year: nil,
                    month: nil,
                    weekday: nil,
                    limit: nil,
                    days: nil,
                    has: nil,
                    maxAccuracyM: nil,
                    activityTypes: nil,
                    minGapMin: nil
                )
            ),
            data: DataBlock(days: shuffled),
            stats: nil
        )
    }
}
