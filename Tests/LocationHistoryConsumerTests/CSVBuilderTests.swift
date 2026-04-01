import XCTest
import LocationHistoryConsumer

final class CSVBuilderTests: XCTestCase {

    // MARK: - Header

    func testBuildIncludesHeader() {
        let csv = CSVBuilder.build(from: [])
        let firstLine = csv.components(separatedBy: "\n")[0]
        XCTAssertTrue(firstLine.contains("date"))
        XCTAssertTrue(firstLine.contains("entryType"))
        XCTAssertTrue(firstLine.contains("visitName"))
        XCTAssertTrue(firstLine.contains("routeIndex"))
    }

    func testHeaderColumnCount() {
        let csv = CSVBuilder.build(from: [])
        let headerCols = csv.components(separatedBy: "\n")[0].components(separatedBy: ",")
        XCTAssertEqual(headerCols.count, CSVBuilder.header.count)
    }

    // MARK: - Empty day produces placeholder row

    func testEmptyDayProducesOneRow() {
        let day = dayFromJSON(date: "2024-05-01")
        let csv = CSVBuilder.build(from: [day])
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 2) // header + 1 placeholder row
        XCTAssertTrue(lines[1].contains("empty"))
    }

    // MARK: - Visit rows

    func testVisitRowIsEmittedPerVisit() {
        let day = dayFromJSON(date: "2024-05-01", visitJSON: """
            {"lat":48.0,"lon":11.0,"start_time":"2024-05-01T08:00:00Z","end_time":"2024-05-01T09:00:00Z","semantic_type":"HOME"},
            {"lat":48.0,"lon":11.0,"start_time":"2024-05-01T10:00:00Z","end_time":"2024-05-01T11:00:00Z","semantic_type":"WORK"}
        """)
        let csv = CSVBuilder.build(from: [day])
        let data = dataLines(csv)
        XCTAssertEqual(data.count, 2)
        XCTAssertTrue(data[0].hasPrefix("2024-05-01"))
        XCTAssertTrue(data[0].contains("visit"))
    }

    // MARK: - Route rows

    func testRouteRowIncludesRouteIndex() {
        let pathJSON = """
            {"activity_type":"WALKING","distance_m":1000,"points":[{"lat":48.0,"lon":11.0,"time":"2024-05-01T10:00:00Z","accuracy_m":10}]},
            {"activity_type":"CYCLING","distance_m":2000,"points":[{"lat":48.0,"lon":11.0,"time":"2024-05-01T11:00:00Z","accuracy_m":5}]},
            {"activity_type":"RUNNING","distance_m":500,"points":[{"lat":48.0,"lon":11.0,"time":"2024-05-01T12:00:00Z","accuracy_m":8}]}
        """
        let day = dayFromJSON(date: "2024-05-01", pathJSON: pathJSON)
        let csv = CSVBuilder.build(from: [day])
        let data = dataLines(csv)
        XCTAssertEqual(data.count, 3)
        XCTAssertTrue(data[0].contains(",0,"))
        XCTAssertTrue(data[1].contains(",1,"))
        XCTAssertTrue(data[2].contains(",2,"))
    }

    // MARK: - Empty fields

    func testEmptyFieldsAreEmptyStringsNotNA() {
        let day = dayFromJSON(date: "2024-05-01", visitJSON: """
            {"lat":48.0,"lon":11.0,"semantic_type":"HOME"}
        """)
        let csv = CSVBuilder.build(from: [day])
        XCTAssertFalse(csv.contains("N/A"))
    }

    // MARK: - Special character escaping

    func testCommaInValueIsQuoted() {
        XCTAssertEqual(CSVBuilder.csvEscape("Hello, World"), "\"Hello, World\"")
    }

    func testQuoteInValueIsDoubled() {
        XCTAssertEqual(CSVBuilder.csvEscape("Say \"hi\""), "\"Say \"\"hi\"\"\"")
    }

    func testPlainValueIsUnquoted() {
        XCTAssertEqual(CSVBuilder.csvEscape("simple"), "simple")
    }

    func testNewlineInValueIsQuoted() {
        XCTAssertEqual(CSVBuilder.csvEscape("line1\nline2"), "\"line1\nline2\"")
    }

    // MARK: - Multiple days

    func testMultipleDaysAreAllRepresented() {
        let day1 = dayFromJSON(date: "2024-05-01", visitJSON: """
            {"lat":48.0,"lon":11.0,"semantic_type":"HOME"}
        """)
        let day2 = dayFromJSON(date: "2024-05-02", pathJSON: """
            {"activity_type":"WALKING","distance_m":1000,"points":[{"lat":48.0,"lon":11.0,"time":"2024-05-02T10:00:00Z","accuracy_m":10}]}
        """)
        let csv = CSVBuilder.build(from: [day1, day2])
        let data = dataLines(csv)
        XCTAssertEqual(data.count, 2)
        XCTAssertTrue(data[0].hasPrefix("2024-05-01"))
        XCTAssertTrue(data[1].hasPrefix("2024-05-02"))
    }

    // MARK: - Route entryType

    func testRouteRowHasRouteEntryType() {
        let pathJSON = """
            {"activity_type":"WALKING","distance_m":1000,"points":[{"lat":48.0,"lon":11.0,"time":"2024-05-01T10:00:00Z","accuracy_m":5}]}
        """
        let day = dayFromJSON(date: "2024-05-01", pathJSON: pathJSON)
        let csv = CSVBuilder.build(from: [day])
        let data = dataLines(csv)
        XCTAssertEqual(data.count, 1)
        XCTAssertTrue(data[0].contains("route"))
    }

    // MARK: - Helpers

    private func dataLines(_ csv: String) -> [String] {
        csv.components(separatedBy: "\n").dropFirst().filter { !$0.isEmpty }
    }

    private func dayFromJSON(
        date: String,
        visitJSON: String = "",
        pathJSON: String = ""
    ) -> Day {
        let visitsArray = visitJSON.isEmpty ? "[]" : "[\(visitJSON)]"
        let pathsArray = pathJSON.isEmpty ? "[]" : "[\(pathJSON)]"
        let json = """
        {
          "schema_version": "1.0",
          "meta": {
            "exported_at": "2024-01-01T00:00:00Z",
            "tool_version": "1.0",
            "source": {},
            "output": {},
            "config": {},
            "filters": {}
          },
          "data": {
            "days": [{
              "date": "\(date)",
              "visits": \(visitsArray),
              "activities": [],
              "paths": \(pathsArray)
            }]
          }
        }
        """
        let export = try! AppExportDecoder.decode(data: Data(json.utf8))
        return export.data.days[0]
    }
}
