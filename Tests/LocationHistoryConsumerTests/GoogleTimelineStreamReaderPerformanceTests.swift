import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Micro-benchmark coverage for the streaming Google Timeline pipeline.
///
/// XCTest's `measure { … }` runs the closure ten times and reports
/// average / standard deviation. The numbers are baseline-only — we do **not**
/// fail-on-regression here because absolute timings vary too much across
/// host machines and Xcode-sim configurations to make a stable fail bar.
/// CI should spot a drastic slowdown by visual inspection of the
/// `xcodebuild test` output; locally, run with `--filter PerformanceTests`
/// and compare against the printed median.
///
/// What the benchmarks intentionally cover:
/// - 5 000-entry synthetic JSON file via `convertStreaming(contentsOf:)`
///   (the disk-streaming path used by direct user imports).
/// - 5 000-entry synthetic JSON via `convert(data:)` (the in-memory path
///   used after ZIP extraction or fixture load).
/// - The chunked `IncrementalParser` fed in 1 KB chunks — the hot path used
///   by ZIP-entry streaming inside `AppContentLoader.streamGoogleTimelineCandidateIfApplicable`.
final class GoogleTimelineStreamReaderPerformanceTests: XCTestCase {

    // MARK: - Disk-streaming path

    func testPerformanceConvertStreamingFromDisk() throws {
        let url = try writeSyntheticTimelineFile(entryCount: 5_000)
        defer { try? FileManager.default.removeItem(at: url) }

        measure {
            do {
                _ = try GoogleTimelineConverter.convertStreaming(contentsOf: url)
            } catch {
                XCTFail("Streaming convert from disk threw: \(error)")
            }
        }
    }

    // MARK: - In-memory streaming path

    func testPerformanceConvertFromMemoryData() throws {
        let url = try writeSyntheticTimelineFile(entryCount: 5_000)
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try Data(contentsOf: url)

        measure {
            do {
                _ = try GoogleTimelineConverter.convert(data: data)
            } catch {
                XCTFail("Convert from in-memory data threw: \(error)")
            }
        }
    }

    // MARK: - Incremental chunk-fed parser

    /// Mirrors the ZIP-entry streaming hot path: feed the parser tiny chunks
    /// (1 KB) the same way `Archive.extract(_:bufferSize:)` would deliver
    /// them when bufferSize is small. Lower bufferSize is the worst case for
    /// the per-byte loop.
    func testPerformanceIncrementalParserSmallChunks() throws {
        let url = try writeSyntheticTimelineFile(entryCount: 5_000)
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try Data(contentsOf: url)
        let chunkSize = 1024

        measure {
            do {
                let converter = GoogleTimelineConverter.incrementalStreamConverter()
                var offset = 0
                while offset < data.count {
                    let end = min(offset + chunkSize, data.count)
                    try converter.feed(data.subdata(in: offset..<end))
                    offset = end
                }
                _ = try converter.finalize()
            } catch {
                XCTFail("Incremental parser threw: \(error)")
            }
        }
    }

    // MARK: - Helpers

    private func writeSyntheticTimelineFile(entryCount: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("perf_timeline.json")
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }

        try handle.write(contentsOf: Data("[".utf8))
        for i in 0..<entryCount {
            let day = (i % 30) + 1
            let hour = (i % 12) + 1
            let entry = """
            {"startTime":"2026-01-\(String(format: "%02d", day))T\(String(format: "%02d", hour)):00:00Z",\
            "endTime":"2026-01-\(String(format: "%02d", day))T\(String(format: "%02d", hour)):30:00Z",\
            "visit":{"topCandidate":{"placeLocation":"geo:50.0,8.0","placeID":"perf-\(i)","semanticType":"HOME"}}}
            """
            if i > 0 { try handle.write(contentsOf: Data(",".utf8)) }
            try handle.write(contentsOf: Data(entry.utf8))
        }
        try handle.write(contentsOf: Data("]".utf8))
        return url
    }
}
