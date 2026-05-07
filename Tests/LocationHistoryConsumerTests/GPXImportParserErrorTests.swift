import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Negative-path coverage for `GPXImportParser`. The malformed-XML and
/// no-trackpoints branches must surface as `AppContentLoaderError.decodeFailed`,
/// never crash the app (audit P1).
///
/// The internal `JSONSerialization` round-trip failure (a `decodeFailed` from
/// `makeExport`) cannot be triggered synthetically without injecting NaN
/// coordinates that XML attributes refuse to round-trip; that branch is
/// defensive and stays untested by design.
///
/// `buildDaysDict` is `private`, so the defensive sort closure (`as? String ?? ""`)
/// is exercised indirectly via the public `parse` API on inputs whose
/// timestamps fail to parse.
final class GPXImportParserErrorTests: XCTestCase {
    func testGPXMalformedXMLThrowsDecodeFailed() {
        let bad = Data("<gpx>not closed".utf8)
        XCTAssertThrowsError(try GPXImportParser.parse(bad, fileName: "bad.gpx")) { error in
            guard let parserError = error as? AppContentLoaderError,
                  case .decodeFailed = parserError else {
                XCTFail("Expected AppContentLoaderError.decodeFailed, got \(error)")
                return
            }
        }
    }

    func testGPXEmptyTrackpointsThrowsDecodeFailed() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="x" xmlns="http://www.topografix.com/GPX/1/1">
        </gpx>
        """
        XCTAssertThrowsError(try GPXImportParser.parse(Data(xml.utf8), fileName: "empty.gpx")) { error in
            guard let parserError = error as? AppContentLoaderError,
                  case .decodeFailed = parserError else {
                XCTFail("Expected AppContentLoaderError.decodeFailed, got \(error)")
                return
            }
        }
    }

    /// Trackpoints whose timestamps fail ISO-8601 parsing should not crash.
    /// They get bucketed under "no-timestamp" and dropped before sort, so the
    /// parser must throw `decodeFailed` (no usable days) — not crash.
    func testGPXSortClosureWithMissingDateKeyDoesNotCrash() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="x" xmlns="http://www.topografix.com/GPX/1/1">
          <trk><trkseg>
            <trkpt lat="52.5" lon="13.4">
              <time>not-a-real-timestamp</time>
            </trkpt>
          </trkseg></trk>
        </gpx>
        """
        XCTAssertThrowsError(try GPXImportParser.parse(Data(xml.utf8), fileName: "bad-time.gpx")) { error in
            guard let parserError = error as? AppContentLoaderError,
                  case .decodeFailed = parserError else {
                XCTFail("Expected AppContentLoaderError.decodeFailed, got \(error)")
                return
            }
        }
    }
}
