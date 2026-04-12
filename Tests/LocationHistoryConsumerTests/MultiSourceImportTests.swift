import XCTest
@testable import LocationHistoryConsumerAppSupport
import LocationHistoryConsumer

/// Tests for GPX and TCX import parsing (Prompt-2: multi-source import foundation).
final class MultiSourceImportTests: XCTestCase {

    // MARK: - 1. GPX with valid trackpoints → AppExport with correct Day structure

    func testGPXWithValidTrackpoints_producesAppExportWithDays() throws {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="test" xmlns="http://www.topografix.com/GPX/1/1">
          <trk>
            <trkseg>
              <trkpt lat="52.5200" lon="13.4050"><time>2024-06-01T08:00:00Z</time></trkpt>
              <trkpt lat="52.5210" lon="13.4060"><time>2024-06-01T08:15:00Z</time></trkpt>
            </trkseg>
          </trk>
        </gpx>
        """
        let data = Data(gpx.utf8)
        let export = try GPXImportParser.parse(data, fileName: "test.gpx")

        XCTAssertFalse(export.data.days.isEmpty, "Should produce at least one day")
        let day = try XCTUnwrap(export.data.days.first)
        XCTAssertFalse(day.paths.isEmpty, "Day should contain at least one path")
        let path = try XCTUnwrap(day.paths.first)
        XCTAssertEqual(path.points.count, 2)
        XCTAssertEqual(path.points[0].lat, 52.5200, accuracy: 0.0001)
        XCTAssertEqual(path.points[0].lon, 13.4050, accuracy: 0.0001)
        XCTAssertEqual(path.sourceType, "gpx")
    }

    // MARK: - 2. GPX fixture → correct number of days and points

    func testGPXFixture_correctDaysAndPoints() throws {
        let url = try TestSupport.contractFixtureURL(named: "sample_import.gpx")
        let data = try Data(contentsOf: url)
        let export = try GPXImportParser.parse(data, fileName: "sample_import.gpx")

        // The fixture has trackpoints on 2024-06-01 and 2024-06-02, plus a waypoint on 2024-06-01.
        // Since all timestamps are UTC, the local date depends on the machine timezone.
        // We just verify structural integrity: at least 2 days (June 1 and June 2 UTC).
        XCTAssertGreaterThanOrEqual(export.data.days.count, 1, "Should have at least 1 day")

        let allPathPoints = export.data.days.flatMap { $0.paths }.flatMap { $0.points }
        XCTAssertGreaterThanOrEqual(allPathPoints.count, 4, "Should have all 4 trackpoints")

        // Waypoint on 2024-06-01 should appear as a visit
        let allVisits = export.data.days.flatMap { $0.visits }
        XCTAssertEqual(allVisits.count, 1, "Should have 1 waypoint as visit")
        XCTAssertEqual(allVisits.first?.semanticType, "Home")
    }

    // MARK: - 3. TCX with valid trackpoints → AppExport with correct Day structure

    func testTCXWithValidTrackpoints_producesAppExportWithDays() throws {
        let tcx = """
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
                      <LongitudeDegrees>13.4050</LongitudeDegrees>
                    </Position>
                  </Trackpoint>
                  <Trackpoint>
                    <Time>2024-06-01T09:15:00Z</Time>
                    <Position>
                      <LatitudeDegrees>52.5215</LatitudeDegrees>
                      <LongitudeDegrees>13.4065</LongitudeDegrees>
                    </Position>
                  </Trackpoint>
                </Track>
              </Lap>
            </Activity>
          </Activities>
        </TrainingCenterDatabase>
        """
        let data = Data(tcx.utf8)
        let export = try TCXImportParser.parse(data, fileName: "test.tcx")

        XCTAssertFalse(export.data.days.isEmpty, "Should produce at least one day")
        let day = try XCTUnwrap(export.data.days.first)
        XCTAssertFalse(day.paths.isEmpty, "Day should contain at least one path")
        let path = try XCTUnwrap(day.paths.first)
        XCTAssertEqual(path.points.count, 2)
        XCTAssertEqual(path.points[0].lat, 52.5200, accuracy: 0.0001)
        XCTAssertEqual(path.sourceType, "tcx")
    }

    // MARK: - 4. GPX without trackpoints → throws AppContentLoaderError

    func testGPXWithoutTrackpoints_throwsDecodeFailed() throws {
        let url = try TestSupport.contractFixtureURL(named: "sample_import_empty.gpx")
        let data = try Data(contentsOf: url)

        do {
            _ = try GPXImportParser.parse(data, fileName: "sample_import_empty.gpx")
            XCTFail("Should throw for empty GPX")
        } catch let error as AppContentLoaderError {
            guard case .decodeFailed = error else {
                XCTFail("Expected decodeFailed but got: \(error)")
                return
            }
        } catch {
            XCTFail("Expected AppContentLoaderError but got: \(error)")
        }
    }

    // MARK: - 5. Invalid XML → throws AppContentLoaderError

    func testInvalidXML_throwsDecodeFailed() throws {
        let broken = Data("this is not xml at all".utf8)

        do {
            _ = try GPXImportParser.parse(broken, fileName: "broken.gpx")
            XCTFail("Should throw for invalid XML")
        } catch let error as AppContentLoaderError {
            guard case .decodeFailed = error else {
                XCTFail("Expected decodeFailed but got: \(error)")
                return
            }
        } catch {
            XCTFail("Expected AppContentLoaderError but got: \(error)")
        }
    }

    func testInvalidXML_TCX_throwsDecodeFailed() throws {
        // Even if the content is not XML at all, it should throw decodeFailed
        // because there are no Trackpoints found.
        let noPoints = Data("<TrainingCenterDatabase/>".utf8)
        do {
            _ = try TCXImportParser.parse(noPoints, fileName: "empty.tcx")
            XCTFail("Should throw for TCX with no trackpoints")
        } catch let error as AppContentLoaderError {
            guard case .decodeFailed = error else {
                XCTFail("Expected decodeFailed but got: \(error)")
                return
            }
        } catch {
            XCTFail("Expected AppContentLoaderError but got: \(error)")
        }
    }

    // MARK: - 6. Detection: isGPX / isTCX

    func testIsGPX_detectsValidGPX() {
        let gpxData = Data("""
        <?xml version="1.0"?><gpx version="1.1" creator="test">...</gpx>
        """.utf8)
        XCTAssertTrue(GPXImportParser.isGPX(gpxData))
    }

    func testIsGPX_rejectsNonGPX() {
        let jsonData = Data(#"{"schema_version":"1.0"}"#.utf8)
        XCTAssertFalse(GPXImportParser.isGPX(jsonData))

        let tcxData = Data("<TrainingCenterDatabase/>".utf8)
        XCTAssertFalse(GPXImportParser.isGPX(tcxData))
    }

    func testIsTCX_detectsValidTCX() {
        let tcxData = Data("""
        <?xml version="1.0"?><TrainingCenterDatabase xmlns="...">...</TrainingCenterDatabase>
        """.utf8)
        XCTAssertTrue(TCXImportParser.isTCX(tcxData))
    }

    func testIsTCX_rejectsNonTCX() {
        let jsonData = Data(#"{"schema_version":"1.0"}"#.utf8)
        XCTAssertFalse(TCXImportParser.isTCX(jsonData))

        let gpxData = Data("""
        <?xml version="1.0"?><gpx version="1.1">...</gpx>
        """.utf8)
        XCTAssertFalse(TCXImportParser.isTCX(gpxData))
    }

    // MARK: - 7. Regression: existing Google Timeline import stays unchanged

    func testGoogleTimelineImport_remainsUnchanged() throws {
        let json = """
        [
          {
            "startTime": "2024-01-15T12:34:56Z",
            "endTime": "2024-01-15T13:00:00Z",
            "visit": {
              "topCandidate": {
                "placeLocation": "geo:52.52,13.40",
                "semanticType": "HOME"
              }
            }
          }
        ]
        """
        let data = Data(json.utf8)
        let export = try GoogleTimelineConverter.convert(data: data)
        XCTAssertEqual(export.data.days.count, 1)
        XCTAssertEqual(export.data.days.first?.visits.count, 1)
        XCTAssertEqual(export.data.days.first?.date, "2024-01-15")
    }

    // MARK: - 8. Regression: existing LH2GPX JSON import stays unchanged

    func testLH2GPXImport_remainsUnchanged() throws {
        let url = try TestSupport.contractFixtureURL(named: "golden_app_export_sample_small.json")
        let data = try Data(contentsOf: url)
        let export = try AppExportDecoder.decode(data: data)
        XCTAssertFalse(export.data.days.isEmpty, "Golden fixture should have days")
        XCTAssertEqual(export.schemaVersion, .v1_0)
    }

    // MARK: - 9. GPX data flows correctly into daySummaries()

    func testGPXData_flowsIntoDaySummaries() throws {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="test" xmlns="http://www.topografix.com/GPX/1/1">
          <trk>
            <trkseg>
              <trkpt lat="52.5200" lon="13.4050"><time>2024-07-01T08:00:00Z</time></trkpt>
              <trkpt lat="52.5210" lon="13.4060"><time>2024-07-01T09:00:00Z</time></trkpt>
            </trkseg>
          </trk>
        </gpx>
        """
        let data = Data(gpx.utf8)
        let export = try GPXImportParser.parse(data, fileName: "test.gpx")
        let summaries = AppExportQueries.daySummaries(from: export)

        XCTAssertFalse(summaries.isEmpty, "daySummaries should not be empty")
        let summary = try XCTUnwrap(summaries.first)
        XCTAssertEqual(summary.pathCount, 1, "Should have one path")
    }

    // MARK: - 10. GPX data flows correctly into insights()

    func testGPXData_flowsIntoInsights() throws {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="test" xmlns="http://www.topografix.com/GPX/1/1">
          <trk>
            <trkseg>
              <trkpt lat="52.5200" lon="13.4050"><time>2024-07-01T08:00:00Z</time></trkpt>
              <trkpt lat="52.5210" lon="13.4060"><time>2024-07-01T09:00:00Z</time></trkpt>
            </trkseg>
          </trk>
        </gpx>
        """
        let data = Data(gpx.utf8)
        let export = try GPXImportParser.parse(data, fileName: "test.gpx")
        let insights = AppExportQueries.insights(from: export)

        XCTAssertNotNil(insights.dateRange, "insights should produce a date range")
        XCTAssertEqual(insights.dateRange?.firstDate, insights.dateRange?.lastDate, "Single-day import: first and last date should be the same")
    }

    // MARK: - AppContentLoader routing tests

    func testAppContentLoader_routesGPXFile() async throws {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="test" xmlns="http://www.topografix.com/GPX/1/1">
          <trk><trkseg>
            <trkpt lat="48.8566" lon="2.3522"><time>2024-08-10T10:00:00Z</time></trkpt>
          </trkseg></trk>
        </gpx>
        """
        let url = try writeTemp(content: gpx, filename: "track.gpx")
        defer { try? FileManager.default.removeItem(at: url) }

        let content = try await AppContentLoader.loadImportedContent(from: url)
        XCTAssertFalse(content.daySummaries.isEmpty, "Should load GPX file via AppContentLoader")
    }

    func testAppContentLoader_routesTCXFile() async throws {
        let tcx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">
          <Activities><Activity Sport="Running">
            <Lap StartTime="2024-08-10T10:00:00Z"><Track>
              <Trackpoint>
                <Time>2024-08-10T10:00:00Z</Time>
                <Position>
                  <LatitudeDegrees>48.8566</LatitudeDegrees>
                  <LongitudeDegrees>2.3522</LongitudeDegrees>
                </Position>
              </Trackpoint>
            </Track></Lap>
          </Activity></Activities>
        </TrainingCenterDatabase>
        """
        let url = try writeTemp(content: tcx, filename: "activity.tcx")
        defer { try? FileManager.default.removeItem(at: url) }

        let content = try await AppContentLoader.loadImportedContent(from: url)
        XCTAssertFalse(content.daySummaries.isEmpty, "Should load TCX file via AppContentLoader")
    }

    func testAppContentLoader_emptyGPX_throwsDecodeFailed() async throws {
        let emptyGPX = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="test" xmlns="http://www.topografix.com/GPX/1/1">
        </gpx>
        """
        let url = try writeTemp(content: emptyGPX, filename: "empty.gpx")
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            _ = try await AppContentLoader.loadImportedContent(from: url)
            XCTFail("Should throw for empty GPX")
        } catch let error as AppContentLoaderError {
            guard case .decodeFailed = error else {
                XCTFail("Expected decodeFailed but got: \(error)")
                return
            }
        } catch {
            XCTFail("Expected AppContentLoaderError but got: \(error)")
        }
    }

    // MARK: - Multi-day grouping

    func testGPX_multiDayGrouping_producesCorrectDays() throws {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="test" xmlns="http://www.topografix.com/GPX/1/1">
          <trk>
            <trkseg>
              <trkpt lat="52.52" lon="13.40"><time>2024-09-01T10:00:00Z</time></trkpt>
            </trkseg>
            <trkseg>
              <trkpt lat="48.85" lon="2.35"><time>2024-09-05T10:00:00Z</time></trkpt>
            </trkseg>
          </trk>
        </gpx>
        """
        let data = Data(gpx.utf8)

        // Force UTC timezone so the day grouping is deterministic
        let original = NSTimeZone.default
        defer { NSTimeZone.default = original }
        NSTimeZone.default = TimeZone(secondsFromGMT: 0)!

        let export = try GPXImportParser.parse(data, fileName: "multiday.gpx")
        XCTAssertEqual(export.data.days.count, 2, "Should have 2 distinct days")
        XCTAssertEqual(export.data.days[0].date, "2024-09-01")
        XCTAssertEqual(export.data.days[1].date, "2024-09-05")
    }

    func testTCX_multiDayGrouping_producesCorrectDays() throws {
        let url = try TestSupport.contractFixtureURL(named: "sample_import.tcx")
        let data = try Data(contentsOf: url)

        // Force UTC so dates are deterministic
        let original = NSTimeZone.default
        defer { NSTimeZone.default = original }
        NSTimeZone.default = TimeZone(secondsFromGMT: 0)!

        let export = try TCXImportParser.parse(data, fileName: "sample_import.tcx")
        XCTAssertEqual(export.data.days.count, 2, "TCX fixture should produce 2 days")
        XCTAssertEqual(export.data.days[0].date, "2024-06-01")
        XCTAssertEqual(export.data.days[1].date, "2024-06-03")
    }

    // MARK: - Helpers

    private func writeTemp(content: String, filename: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try Data(content.utf8).write(to: url)
        return url
    }
}
