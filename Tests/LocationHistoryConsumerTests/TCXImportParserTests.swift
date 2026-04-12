import XCTest
@testable import LocationHistoryConsumerAppSupport
import LocationHistoryConsumer

final class TCXImportParserTests: XCTestCase {

    // MARK: - Happy Path

    func testParseSampleTCX() throws {
        let url = try TestSupport.contractFixtureURL(named: "sample_import.tcx")
        let data = try Data(contentsOf: url)

        // Force UTC so date grouping is deterministic
        let original = NSTimeZone.default
        defer { NSTimeZone.default = original }
        NSTimeZone.default = TimeZone(secondsFromGMT: 0)!

        let export = try TCXImportParser.parse(data, fileName: "sample_import.tcx")

        // Fixture has trackpoints on 2024-06-01 and 2024-06-03
        XCTAssertGreaterThanOrEqual(export.data.days.count, 1, "Should produce at least one day")
        XCTAssertEqual(export.data.days.count, 2, "Fixture should produce exactly 2 days")
        XCTAssertEqual(export.data.days[0].date, "2024-06-01")
        XCTAssertEqual(export.data.days[1].date, "2024-06-03")

        let allPaths = export.data.days.flatMap { $0.paths }
        XCTAssertFalse(allPaths.isEmpty, "Should have at least one path")

        let allPoints = allPaths.flatMap { $0.points }
        XCTAssertEqual(allPoints.count, 4, "Fixture has 4 trackpoints total")

        XCTAssertEqual(allPaths.first?.sourceType, "tcx", "Source type should be 'tcx'")

        // Spot-check first point coordinates
        let firstPoint = try XCTUnwrap(allPoints.first)
        XCTAssertEqual(firstPoint.lat, 52.5200, accuracy: 0.0001)
        XCTAssertEqual(firstPoint.lon, 13.4050, accuracy: 0.0001)
    }

    // MARK: - Error Paths

    func testParseEmptyDataThrows() {
        let empty = Data()
        XCTAssertThrowsError(try TCXImportParser.parse(empty, fileName: "empty.tcx")) { error in
            guard let parserError = error as? TCXImportError,
                  case .invalidXML = parserError else {
                XCTFail("Expected TCXImportError.invalidXML, got: \(error)")
                return
            }
        }
    }

    func testParseCorruptXMLThrows() {
        let corrupt = Data("<<not valid xml>>".utf8)
        XCTAssertThrowsError(try TCXImportParser.parse(corrupt, fileName: "corrupt.tcx")) { error in
            guard let parserError = error as? TCXImportError,
                  case .invalidXML = parserError else {
                XCTFail("Expected TCXImportError.invalidXML, got: \(error)")
                return
            }
        }
    }

    func testParseValidXMLWithoutTrackpointsThrows() {
        let noPoints = Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">
          <Activities>
            <Activity Sport="Running">
              <Lap StartTime="2024-06-01T09:00:00Z">
                <Track>
                </Track>
              </Lap>
            </Activity>
          </Activities>
        </TrainingCenterDatabase>
        """.utf8)

        XCTAssertThrowsError(try TCXImportParser.parse(noPoints, fileName: "nopoints.tcx")) { error in
            guard let parserError = error as? TCXImportError,
                  case .noTrackPoints = parserError else {
                XCTFail("Expected TCXImportError.noTrackPoints, got: \(error)")
                return
            }
        }
    }

    func testParseTrackpointsWithoutPositionThrowsMissingRequiredData() {
        // Trackpoints exist but lack <Position> → malformed TCX trackpoint.
        let noPosition = Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">
          <Activities>
            <Activity Sport="Running">
              <Lap StartTime="2024-06-01T09:00:00Z">
                <Track>
                  <Trackpoint>
                    <Time>2024-06-01T09:00:00Z</Time>
                  </Trackpoint>
                </Track>
              </Lap>
            </Activity>
          </Activities>
        </TrainingCenterDatabase>
        """.utf8)

        XCTAssertThrowsError(try TCXImportParser.parse(noPosition, fileName: "noposition.tcx")) { error in
            guard let parserError = error as? TCXImportError,
                  case .missingRequiredTrackpointData = parserError else {
                XCTFail("Expected TCXImportError.missingRequiredTrackpointData, got: \(error)")
                return
            }
        }
    }

    func testParseTrackpointWithOnlyLatitudeThrowsMissingRequiredData() {
        let incompletePosition = Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">
          <Activities>
            <Activity Sport="Running">
              <Lap StartTime="2024-06-01T09:00:00Z">
                <Track>
                  <Trackpoint>
                    <Time>2024-06-01T09:00:00Z</Time>
                    <Position>
                      <LatitudeDegrees>52.5200</LatitudeDegrees>
                    </Position>
                  </Trackpoint>
                </Track>
              </Lap>
            </Activity>
          </Activities>
        </TrainingCenterDatabase>
        """.utf8)

        XCTAssertThrowsError(try TCXImportParser.parse(incompletePosition, fileName: "incomplete.tcx")) { error in
            guard let parserError = error as? TCXImportError,
                  case .missingRequiredTrackpointData = parserError else {
                XCTFail("Expected TCXImportError.missingRequiredTrackpointData, got: \(error)")
                return
            }
        }
    }

    // MARK: - isTCX Detection

    func testIsTCXDetectsCorrectly() {
        let tcxData = Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">
        </TrainingCenterDatabase>
        """.utf8)
        XCTAssertTrue(TCXImportParser.isTCX(tcxData), "Should detect TCX data")
    }

    func testIsTCXRejectsGPX() {
        let gpxData = Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="test" xmlns="http://www.topografix.com/GPX/1/1">
        </gpx>
        """.utf8)
        XCTAssertFalse(TCXImportParser.isTCX(gpxData), "Should reject GPX data")
    }

    func testIsTCXRejectsJSON() {
        let jsonData = Data(#"{"schema_version":"1.0","data":{"days":[]}}"#.utf8)
        XCTAssertFalse(TCXImportParser.isTCX(jsonData), "Should reject JSON data")
    }

    func testIsTCXRejectsEmptyData() {
        XCTAssertFalse(TCXImportParser.isTCX(Data()), "Should reject empty data")
    }

    // MARK: - Source type

    func testParseProducesSourceTypeTCX() throws {
        let tcx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">
          <Activities>
            <Activity Sport="Cycling">
              <Lap StartTime="2024-09-10T07:00:00Z">
                <Track>
                  <Trackpoint>
                    <Time>2024-09-10T07:00:00Z</Time>
                    <Position>
                      <LatitudeDegrees>48.8566</LatitudeDegrees>
                      <LongitudeDegrees>2.3522</LongitudeDegrees>
                    </Position>
                  </Trackpoint>
                </Track>
              </Lap>
            </Activity>
          </Activities>
        </TrainingCenterDatabase>
        """
        let data = Data(tcx.utf8)
        let export = try TCXImportParser.parse(data, fileName: "activity.tcx")
        let path = try XCTUnwrap(export.data.days.first?.paths.first)
        XCTAssertEqual(path.sourceType, "tcx")
    }

    // MARK: - Coordinate accuracy

    func testParsePreservesCoordinates() throws {
        let tcx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">
          <Activities>
            <Activity Sport="Running">
              <Lap StartTime="2024-10-01T06:00:00Z">
                <Track>
                  <Trackpoint>
                    <Time>2024-10-01T06:00:00Z</Time>
                    <Position>
                      <LatitudeDegrees>37.7749</LatitudeDegrees>
                      <LongitudeDegrees>-122.4194</LongitudeDegrees>
                    </Position>
                  </Trackpoint>
                  <Trackpoint>
                    <Time>2024-10-01T06:30:00Z</Time>
                    <Position>
                      <LatitudeDegrees>37.7850</LatitudeDegrees>
                      <LongitudeDegrees>-122.4075</LongitudeDegrees>
                    </Position>
                  </Trackpoint>
                </Track>
              </Lap>
            </Activity>
          </Activities>
        </TrainingCenterDatabase>
        """
        let data = Data(tcx.utf8)
        let export = try TCXImportParser.parse(data, fileName: "sf.tcx")

        let points = try XCTUnwrap(export.data.days.first?.paths.first?.points)
        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(points[0].lat, 37.7749, accuracy: 0.00001)
        XCTAssertEqual(points[0].lon, -122.4194, accuracy: 0.00001)
        XCTAssertEqual(points[1].lat, 37.7850, accuracy: 0.00001)
        XCTAssertEqual(points[1].lon, -122.4075, accuracy: 0.00001)
    }
}
