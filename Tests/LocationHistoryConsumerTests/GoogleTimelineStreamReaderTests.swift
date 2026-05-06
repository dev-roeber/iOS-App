import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Coverage for the element-based streaming Google Timeline reader. The
/// reader is the primary defence against OOM on large manual imports — a
/// real 100 MB Google Timeline JSON now flows through with peak memory of
/// one element (~few KB) instead of the full ~150–200 MB transient
/// Foundation tree the old `JSONSerialization.jsonObject(with: fullData)`
/// path produced.
final class GoogleTimelineStreamReaderTests: XCTestCase {

    // MARK: - Happy path

    func testParsesSimpleTwoElementArray() throws {
        let json = Data(#"""
        [
            {"startTime":"2026-01-01T08:00:00Z","visit":{"topCandidate":{"placeLocation":"geo:50.0,8.0"}}},
            {"startTime":"2026-01-01T09:00:00Z","activity":{"topCandidate":{"type":"walking"}},"distanceMeters":"123.4"}
        ]
        """#.utf8)

        var elements: [[String: Any]] = []
        try GoogleTimelineStreamReader.forEachObjectElement(in: json) { raw in
            if let dict = raw as? [String: Any] { elements.append(dict) }
        }
        XCTAssertEqual(elements.count, 2)
        XCTAssertEqual(elements[0]["startTime"] as? String, "2026-01-01T08:00:00Z")
        XCTAssertEqual(elements[1]["startTime"] as? String, "2026-01-01T09:00:00Z")
    }

    func testStreamsFromFileURL() throws {
        let url = try writeJSONFile(content: #"""
        [{"startTime":"2026-02-01T10:00:00Z","visit":{"topCandidate":{"placeLocation":"geo:48.1,11.5"}}}]
        """#)
        defer { try? FileManager.default.removeItem(at: url) }

        var count = 0
        try GoogleTimelineStreamReader.forEachObjectElement(contentsOf: url) { _ in count += 1 }
        XCTAssertEqual(count, 1)
    }

    func testIgnoresLeadingBOMAndWhitespace() throws {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data("  \n\t[ {\"startTime\":\"2026-01-01T00:00:00Z\"} ]  \n".utf8))

        var count = 0
        try GoogleTimelineStreamReader.forEachObjectElement(in: data) { _ in count += 1 }
        XCTAssertEqual(count, 1)
    }

    func testEmptyArrayProducesZeroElements() throws {
        var count = 0
        try GoogleTimelineStreamReader.forEachObjectElement(in: Data("[]".utf8)) { _ in count += 1 }
        XCTAssertEqual(count, 0)

        try GoogleTimelineStreamReader.forEachObjectElement(in: Data("  [  \n ]  ".utf8)) { _ in count += 1 }
        XCTAssertEqual(count, 0)
    }

    // MARK: - String + escape edge cases

    func testStringContainingStructuralBytesIsNotConfusedWithObjectEnd() throws {
        // The closing `}` and `]` inside the string must not pop element depth.
        let json = Data(#"""
        [{"startTime":"2026-01-01T00:00:00Z","note":"closing }] inside string"},{"startTime":"2026-01-02T00:00:00Z"}]
        """#.utf8)

        var elements: [[String: Any]] = []
        try GoogleTimelineStreamReader.forEachObjectElement(in: json) { raw in
            if let dict = raw as? [String: Any] { elements.append(dict) }
        }
        XCTAssertEqual(elements.count, 2)
        XCTAssertEqual(elements[0]["note"] as? String, "closing }] inside string")
    }

    func testEscapedQuoteInsideStringIsHandled() throws {
        let json = Data(#"""
        [{"startTime":"2026-01-01T00:00:00Z","note":"He said \"hi\" then left"}]
        """#.utf8)

        var elements: [[String: Any]] = []
        try GoogleTimelineStreamReader.forEachObjectElement(in: json) { raw in
            if let dict = raw as? [String: Any] { elements.append(dict) }
        }
        XCTAssertEqual(elements.count, 1)
        XCTAssertEqual(elements[0]["note"] as? String, "He said \"hi\" then left")
    }

    func testNestedObjectsAndArraysInsideElement() throws {
        let json = Data(#"""
        [{"startTime":"2026-01-01T00:00:00Z","timelinePath":[{"point":"geo:50.0,8.0","durationMinutesOffsetFromStartTime":"0"},{"point":"geo:50.1,8.1","durationMinutesOffsetFromStartTime":"5"}]}]
        """#.utf8)

        var elements: [[String: Any]] = []
        try GoogleTimelineStreamReader.forEachObjectElement(in: json) { raw in
            if let dict = raw as? [String: Any] { elements.append(dict) }
        }
        XCTAssertEqual(elements.count, 1)
        XCTAssertEqual((elements[0]["timelinePath"] as? [[String: Any]])?.count, 2)
    }

    // MARK: - Error paths

    func testThrowsOnNonArrayRoot() {
        XCTAssertThrowsError(
            try GoogleTimelineStreamReader.forEachObjectElement(in: Data(#"{"key":"value"}"#.utf8)) { _ in }
        ) { error in
            guard case GoogleTimelineStreamReader.StreamError.notArray = error else {
                return XCTFail("Expected notArray, got \(error)")
            }
        }
    }

    func testThrowsOnNonObjectElement() {
        XCTAssertThrowsError(
            try GoogleTimelineStreamReader.forEachObjectElement(in: Data("[42, 7]".utf8)) { _ in }
        ) { error in
            guard case GoogleTimelineStreamReader.StreamError.malformedJSON = error else {
                return XCTFail("Expected malformedJSON, got \(error)")
            }
        }
    }

    func testThrowsOnTruncatedInput() {
        XCTAssertThrowsError(
            try GoogleTimelineStreamReader.forEachObjectElement(in: Data(#"[{"startTime":"2026-01-01T00:00:00Z""#.utf8)) { _ in }
        ) { error in
            guard case GoogleTimelineStreamReader.StreamError.malformedJSON = error else {
                return XCTFail("Expected malformedJSON, got \(error)")
            }
        }
    }

    func testThrowsOnElementOverMaxBytes() {
        // Build an element whose object body is larger than the cap.
        var json = Data("[{\"x\":\"".utf8)
        json.append(Data(repeating: UInt8(ascii: "a"), count: 2 * 1024 * 1024))
        json.append(Data("\"}]".utf8))

        let limits = GoogleTimelineStreamReader.Limits(chunkSize: 4096, maxElementBytes: 1 * 1024 * 1024)
        XCTAssertThrowsError(
            try GoogleTimelineStreamReader.forEachObjectElement(in: json, limits: limits) { _ in }
        ) { error in
            guard case GoogleTimelineStreamReader.StreamError.elementTooLarge = error else {
                return XCTFail("Expected elementTooLarge, got \(error)")
            }
        }
    }

    func testThrowsOnGarbageAfterClosingBracket() {
        XCTAssertThrowsError(
            try GoogleTimelineStreamReader.forEachObjectElement(in: Data("[]garbage".utf8)) { _ in }
        ) { error in
            guard case GoogleTimelineStreamReader.StreamError.malformedJSON = error else {
                return XCTFail("Expected malformedJSON, got \(error)")
            }
        }
    }

    // MARK: - Chunk-boundary correctness

    /// Feeding the parser one byte at a time must produce the same elements
    /// as feeding the full buffer. This is the regression net for
    /// chunk-boundary bugs: structural bytes splitting across reads.
    func testByteByByteFeedingMatchesBulkFeed() throws {
        let json = Data(#"""
        [{"a":1,"s":"x{y]z"},{"b":2,"t":"\"q\""},{"c":3,"path":[{"p":"geo:1,2"}]}]
        """#.utf8)

        var bulkCount = 0
        try GoogleTimelineStreamReader.forEachObjectElement(in: json) { _ in bulkCount += 1 }

        // Stream via a 1-byte chunk file.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("byte_by_byte.json")
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try json.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        var streamCount = 0
        let tinyChunks = GoogleTimelineStreamReader.Limits(chunkSize: 1, maxElementBytes: 1024)
        try GoogleTimelineStreamReader.forEachObjectElement(contentsOf: url, limits: tinyChunks) { _ in
            streamCount += 1
        }
        XCTAssertEqual(bulkCount, 3)
        XCTAssertEqual(streamCount, 3)
    }

    // MARK: - Converter integration

    /// The streaming converter must produce a structurally valid AppExport
    /// from a synthetic large-ish Timeline JSON written to disk. This is the
    /// closest unit-test analogue to the real 46 MB iPhone failure case.
    func testConvertStreamingHandlesLargeFile() throws {
        let entryCount = 5_000
        let url = try writeSyntheticTimelineFile(entryCount: entryCount)
        defer { try? FileManager.default.removeItem(at: url) }

        let export = try GoogleTimelineConverter.convertStreaming(contentsOf: url)
        XCTAssertGreaterThan(export.data.days.count, 0)
        let totalVisits = export.data.days.reduce(0) { $0 + $1.visits.count }
        XCTAssertEqual(totalVisits, entryCount)
    }

    /// IncrementalParser path: feed chunks across element boundaries and
    /// confirm we still see every element exactly once. Mirrors the byte-level
    /// scenario the ZIP-streaming path produces.
    func testIncrementalParserAcrossArbitraryChunkBoundaries() throws {
        let json = Data(#"""
        [{"startTime":"2026-01-01T00:00:00Z","note":"} ] inside string"},{"startTime":"2026-01-02T00:00:00Z","timelinePath":[{"point":"geo:1,2"}]},{"startTime":"2026-01-03T00:00:00Z"}]
        """#.utf8)

        var collected: [[String: Any]] = []
        let parser = GoogleTimelineStreamReader.IncrementalParser()
        // 7-byte chunks force boundary splits inside strings, depths, escapes.
        let chunkSize = 7
        var offset = 0
        while offset < json.count {
            let end = min(offset + chunkSize, json.count)
            try parser.feed(json.subdata(in: offset..<end)) { raw in
                if let dict = raw as? [String: Any] { collected.append(dict) }
            }
            offset = end
        }
        try parser.finish()
        XCTAssertEqual(collected.count, 3)
        XCTAssertEqual(collected[0]["note"] as? String, "} ] inside string")
    }

    /// IncrementalParser equivalence to the in-memory `forEachObjectElement(in:)`.
    func testIncrementalParserMatchesInMemoryPath() throws {
        let url = try writeSyntheticTimelineFile(entryCount: 200)
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try Data(contentsOf: url)

        var bulkCount = 0
        try GoogleTimelineStreamReader.forEachObjectElement(in: data) { _ in bulkCount += 1 }

        var streamCount = 0
        let parser = GoogleTimelineStreamReader.IncrementalParser()
        try parser.feed(data) { _ in streamCount += 1 }
        try parser.finish()

        XCTAssertEqual(bulkCount, streamCount)
        XCTAssertEqual(bulkCount, 200)
    }

    /// `convert(data:)` must remain functionally equivalent — both paths
    /// share the same per-entry ingest and finalisation helpers.
    func testConvertDataMatchesStreaming() throws {
        let entryCount = 200
        let url = try writeSyntheticTimelineFile(entryCount: entryCount)
        defer { try? FileManager.default.removeItem(at: url) }

        let data = try Data(contentsOf: url)
        let dataExport = try GoogleTimelineConverter.convert(data: data)
        let streamExport = try GoogleTimelineConverter.convertStreaming(contentsOf: url)

        XCTAssertEqual(dataExport.data.days.count, streamExport.data.days.count)
        let dataVisits = dataExport.data.days.reduce(0) { $0 + $1.visits.count }
        let streamVisits = streamExport.data.days.reduce(0) { $0 + $1.visits.count }
        XCTAssertEqual(dataVisits, streamVisits)
        XCTAssertEqual(dataVisits, entryCount)
    }

    // MARK: - Helpers

    private func writeJSONFile(content: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("timeline.json")
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(content.utf8).write(to: url)
        return url
    }

    /// Writes a synthetic Google Timeline JSON file with `entryCount`
    /// `visit` entries spread across 30 days. Each entry is a small,
    /// realistically-shaped object with a unique `placeID`.
    private func writeSyntheticTimelineFile(entryCount: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("synthetic_timeline.json")
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
            "visit":{"topCandidate":{"placeLocation":"geo:50.0,8.0","placeID":"p\(i)","semanticType":"HOME"}}}
            """
            if i > 0 { try handle.write(contentsOf: Data(",".utf8)) }
            try handle.write(contentsOf: Data(entry.utf8))
        }
        try handle.write(contentsOf: Data("]".utf8))
        return url
    }
}
