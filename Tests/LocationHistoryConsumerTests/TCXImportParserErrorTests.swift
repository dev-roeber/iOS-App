import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Additional regression coverage for `TCXImportParser` failure paths
/// (audit P1). `TCXImportParserTests` already exercises the headline cases;
/// this file pins extra edge cases without overlapping the existing assertions.
///
/// The `TCXImportError.exportRoundTripFailed` branch (defensive
/// `JSONSerialization`-loss handler in `makeExport`) cannot be triggered
/// synthetically; it stays untested by design.
final class TCXImportParserErrorTests: XCTestCase {
    func testTCXMalformedXMLThrowsInvalidXML() {
        let bad = Data("<TrainingCenterDatabase><Activities><Activity".utf8)
        XCTAssertThrowsError(try TCXImportParser.parse(bad, fileName: "broken.tcx")) { error in
            guard let parserError = error as? TCXImportError else {
                XCTFail("Expected TCXImportError, got \(error)")
                return
            }
            // Darwin's XMLParser surfaces malformed/truncated XML as a parse
            // error → `.invalidXML`. Linux's swift-corelibs-foundation
            // XMLParser is more permissive and silently accepts the
            // truncated stream, so the parser ends up reporting the empty
            // result via `.noTrackPoints`. Both outcomes are acceptable
            // signals that the input was not a valid track-bearing TCX.
            switch parserError {
            case .invalidXML, .noTrackPoints:
                return
            default:
                XCTFail("Expected TCXImportError.invalidXML or .noTrackPoints, got \(parserError)")
            }
        }
    }

    func testTCXEmptyTrackpointsThrowsNoTrackPoints() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">
          <Activities>
            <Activity Sport="Running">
              <Lap StartTime="2024-06-01T09:00:00Z">
                <Track></Track>
              </Lap>
            </Activity>
          </Activities>
        </TrainingCenterDatabase>
        """
        XCTAssertThrowsError(try TCXImportParser.parse(Data(xml.utf8), fileName: "no-points.tcx")) { error in
            guard let parserError = error as? TCXImportError,
                  case .noTrackPoints = parserError else {
                XCTFail("Expected TCXImportError.noTrackPoints, got \(error)")
                return
            }
        }
    }
}
