import XCTest
@testable import LocationHistoryConsumer

final class KMLBuilderTests: XCTestCase {
    func testBuildNoDaysProducesValidShell() {
        let kml = KMLBuilder.build(from: [])
        XCTAssertTrue(kml.contains(#"<?xml version="1.0""#))
        XCTAssertTrue(kml.contains(#"<kml xmlns="http://www.opengis.net/kml/2.2">"#))
        XCTAssertTrue(kml.contains("</kml>"))
        XCTAssertFalse(kml.contains("<Placemark>"))
    }

    func testBuildPathProducesPlacemarkAndCoordinates() {
        let path = Path(
            startTime: nil,
            endTime: nil,
            activityType: "WALKING",
            distanceM: 700,
            sourceType: nil,
            points: [
                PathPoint(lat: 48.0, lon: 11.0, time: nil, accuracyM: nil),
                PathPoint(lat: 48.001, lon: 11.001, time: nil, accuracyM: nil)
            ],
            flatCoordinates: nil
        )
        let day = Day(date: "2024-05-01", visits: [], activities: [], paths: [path])

        let kml = KMLBuilder.build(from: [day])

        XCTAssertTrue(kml.contains("<Placemark>"))
        XCTAssertTrue(kml.contains("<name>2024-05-01"))
        XCTAssertTrue(kml.contains("<LineString>"))
        XCTAssertTrue(kml.contains("11.00000000,48.00000000"))
        XCTAssertTrue(kml.contains("11.00100000,48.00100000"))
    }
}
