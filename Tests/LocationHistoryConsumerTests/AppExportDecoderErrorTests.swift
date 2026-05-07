import Foundation
import XCTest
@testable import LocationHistoryConsumer

/// Negative-path coverage for `AppExportDecoder`. The happy paths are covered
/// by `AppExportGoldenDecodingTests`; this file pins the failure modes that
/// must surface as thrown errors instead of crashes (audit P1).
final class AppExportDecoderErrorTests: XCTestCase {
    func testEmptyDataThrows() {
        XCTAssertThrowsError(try AppExportDecoder.decode(data: Data()))
    }

    func testCorruptedJSONThrows() {
        XCTAssertThrowsError(try AppExportDecoder.decode(data: Data("{".utf8)))
    }

    func testMissingDataSectionThrows() {
        let json = #"{"schema_version":"1.0","meta":{"exported_at":"2024-01-01T00:00:00Z","tool_version":"x","source":{"input_format":"records"},"output":{},"config":{"mode":"all","split_mode":"single","export_format":["json"],"input_format":"records"},"filters":{}}}"#
        XCTAssertThrowsError(try AppExportDecoder.decode(data: Data(json.utf8))) { error in
            XCTAssertTrue(error is DecodingError, "Expected DecodingError, got \(error)")
        }
    }

    func testMissingMetaSectionThrows() {
        let json = #"{"schema_version":"1.0","data":{"days":[]}}"#
        XCTAssertThrowsError(try AppExportDecoder.decode(data: Data(json.utf8))) { error in
            XCTAssertTrue(error is DecodingError, "Expected DecodingError, got \(error)")
        }
    }

    func testMissingSchemaVersionThrows() {
        let json = #"{"meta":{"exported_at":"2024-01-01T00:00:00Z","tool_version":"x","source":{"input_format":"records"},"output":{},"config":{"mode":"all","split_mode":"single","export_format":["json"],"input_format":"records"},"filters":{}},"data":{"days":[]}}"#
        XCTAssertThrowsError(try AppExportDecoder.decode(data: Data(json.utf8))) { error in
            XCTAssertTrue(error is DecodingError, "Expected DecodingError, got \(error)")
        }
    }
}
