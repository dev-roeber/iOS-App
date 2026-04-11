import XCTest
@testable import LocationHistoryConsumer

final class GeoJSONBuilderTests: XCTestCase {
    func testBuildBothModeProducesLineAndPointFeatures() throws {
        let day = Day(
            date: "2024-05-01",
            visits: [
                Visit(
                    lat: 48.0,
                    lon: 11.0,
                    startTime: "2024-05-01T08:00:00Z",
                    endTime: nil,
                    semanticType: "HOME",
                    placeID: nil,
                    accuracyM: nil,
                    sourceType: nil
                )
            ],
            activities: [],
            paths: [
                Path(
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
            ]
        )

        let geoJSON = try GeoJSONBuilder.build(from: [day], mode: .both)

        XCTAssertTrue(geoJSON.contains("\"type\" : \"FeatureCollection\""))
        XCTAssertTrue(geoJSON.contains("\"type\" : \"LineString\""))
        XCTAssertTrue(geoJSON.contains("\"type\" : \"Point\""))
        XCTAssertTrue(geoJSON.contains("\"geometry_kind\" : \"track\""))
        XCTAssertTrue(geoJSON.contains("\"geometry_kind\" : \"waypoint\""))
    }

    func testWaypointModeOmitsTracks() throws {
        let day = Day(
            date: "2024-05-01",
            visits: [
                Visit(
                    lat: 48.0,
                    lon: 11.0,
                    startTime: "2024-05-01T08:00:00Z",
                    endTime: nil,
                    semanticType: "HOME",
                    placeID: nil,
                    accuracyM: nil,
                    sourceType: nil
                )
            ],
            activities: [],
            paths: [
                Path(
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
            ]
        )

        let geoJSON = try GeoJSONBuilder.build(from: [day], mode: .waypoints)

        XCTAssertFalse(geoJSON.contains("\"type\" : \"LineString\""))
        XCTAssertTrue(geoJSON.contains("\"type\" : \"Point\""))
    }

    func testBuildEmptyDaysProducesValidFeatureCollection() throws {
        // Empty input must produce a valid FeatureCollection (not throw, not return garbage)
        let geoJSON = try GeoJSONBuilder.build(from: [], mode: .tracks)
        XCTAssertTrue(geoJSON.contains("\"type\" : \"FeatureCollection\""))
        // Verify it is parseable JSON with a "features" key
        let data = try XCTUnwrap(geoJSON.data(using: .utf8))
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let features = try XCTUnwrap(parsed["features"] as? [Any])
        XCTAssertEqual(features.count, 0)
    }
}
