import Foundation
import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Phase-5 — Streaming-Writer-Verhalten: idempotente Parent-Erstellung,
/// inkrementelle UTF-8-Writes, korrekte Bytecount, idempotentes finalize.
final class LocalTimelineStreamingTextWriterTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTSWriter-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    func testCreatesParentDirectoryAndFile() throws {
        let url = tempDir.appendingPathComponent("nested/sub/export.txt")
        let w = try LocalTimelineStreamingTextWriter(outputURL: url)
        try w.write("hello")
        try w.finalize()
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let data = try Data(contentsOf: url)
        XCTAssertEqual(String(data: data, encoding: .utf8), "hello")
    }

    func testBytesWrittenMatchesUTF8ByteCount() throws {
        let url = tempDir.appendingPathComponent("a.txt")
        let w = try LocalTimelineStreamingTextWriter(outputURL: url)
        try w.write("ä")        // 2 bytes UTF-8
        try w.write("€")        // 3 bytes
        try w.write("hi")       // 2 bytes
        try w.finalize()
        XCTAssertEqual(w.bytesWritten, 7)
        let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int
        XCTAssertEqual(size, 7)
    }

    func testFinalizeIsIdempotent() throws {
        let url = tempDir.appendingPathComponent("a.txt")
        let w = try LocalTimelineStreamingTextWriter(outputURL: url)
        try w.write("x")
        try w.finalize()
        XCTAssertNoThrow(try w.finalize())
        XCTAssertTrue(w.isClosed)
    }

    func testWriteAfterFinalizeThrows() throws {
        let url = tempDir.appendingPathComponent("a.txt")
        let w = try LocalTimelineStreamingTextWriter(outputURL: url)
        try w.finalize()
        XCTAssertThrowsError(try w.write("x"))
    }

    func testOverwritesExistingFile() throws {
        let url = tempDir.appendingPathComponent("a.txt")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try Data("OLD-CONTENT".utf8).write(to: url)
        let w = try LocalTimelineStreamingTextWriter(outputURL: url)
        try w.write("NEW")
        try w.finalize()
        let data = try Data(contentsOf: url)
        XCTAssertEqual(String(data: data, encoding: .utf8), "NEW")
    }
}
