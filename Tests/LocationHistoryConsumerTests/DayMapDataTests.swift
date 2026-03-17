import Foundation
import XCTest
@testable import LocationHistoryConsumer

final class DayMapDataTests: XCTestCase {

    // MARK: - Full day with visits and paths

    func testExtractsVisitAnnotationsFromDay() throws {
        let detail = try dayDetail(fixture: "golden_app_export_sample_small.json", date: "2024-05-01")
        let mapData = DayMapDataExtractor.mapData(from: detail)

        XCTAssertEqual(mapData.visitAnnotations.count, 3)
        XCTAssertEqual(mapData.visitAnnotations[0].semanticType, "HOME")
        XCTAssertEqual(mapData.visitAnnotations[0].coordinate.lat, 52.5208)
        XCTAssertEqual(mapData.visitAnnotations[0].coordinate.lon, 13.4095)
        XCTAssertEqual(mapData.visitAnnotations[1].semanticType, "WORK")
        XCTAssertEqual(mapData.visitAnnotations[2].semanticType, "LEISURE")
    }

    func testExtractsPathOverlaysFromDay() throws {
        let detail = try dayDetail(fixture: "golden_app_export_sample_small.json", date: "2024-05-01")
        let mapData = DayMapDataExtractor.mapData(from: detail)

        XCTAssertEqual(mapData.pathOverlays.count, 2)
        XCTAssertEqual(mapData.pathOverlays[0].activityType, "WALKING")
        XCTAssertEqual(mapData.pathOverlays[0].coordinates.count, 3)
        XCTAssertEqual(mapData.pathOverlays[1].activityType, "IN PASSENGER VEHICLE")
        XCTAssertEqual(mapData.pathOverlays[1].coordinates.count, 4)
    }

    func testHasMapContentWhenCoordinatesExist() throws {
        let detail = try dayDetail(fixture: "golden_app_export_sample_small.json", date: "2024-05-01")
        let mapData = DayMapDataExtractor.mapData(from: detail)

        XCTAssertTrue(mapData.hasMapContent)
        XCTAssertNotNil(mapData.fittedRegion)
    }

    // MARK: - Region computation

    func testFittedRegionCoversAllCoordinates() throws {
        let detail = try dayDetail(fixture: "golden_app_export_sample_small.json", date: "2024-05-01")
        let mapData = DayMapDataExtractor.mapData(from: detail)

        let region = try XCTUnwrap(mapData.fittedRegion)
        XCTAssertGreaterThan(region.spanLat, 0)
        XCTAssertGreaterThan(region.spanLon, 0)

        let allLats = mapData.visitAnnotations.map(\.coordinate.lat)
            + mapData.pathOverlays.flatMap { $0.coordinates.map(\.lat) }
        let allLons = mapData.visitAnnotations.map(\.coordinate.lon)
            + mapData.pathOverlays.flatMap { $0.coordinates.map(\.lon) }

        let minLat = allLats.min()!
        let maxLat = allLats.max()!
        let minLon = allLons.min()!
        let maxLon = allLons.max()!

        XCTAssertLessThanOrEqual(region.centerLat - region.spanLat / 2, minLat)
        XCTAssertGreaterThanOrEqual(region.centerLat + region.spanLat / 2, maxLat)
        XCTAssertLessThanOrEqual(region.centerLon - region.spanLon / 2, minLon)
        XCTAssertGreaterThanOrEqual(region.centerLon + region.spanLon / 2, maxLon)
    }

    func testRegionHasMinimumSpan() {
        let coords = [DayMapCoordinate(lat: 52.52, lon: 13.41)]
        let region = DayMapDataExtractor.computeRegion(from: coords)

        XCTAssertNotNil(region)
        XCTAssertGreaterThanOrEqual(region!.spanLat, 0.005)
        XCTAssertGreaterThanOrEqual(region!.spanLon, 0.005)
    }

    func testRegionIsNilForEmptyCoordinates() {
        let region = DayMapDataExtractor.computeRegion(from: [])
        XCTAssertNil(region)
    }

    // MARK: - Empty / no-coordinate cases

    func testEmptyDayProducesNoMapContent() throws {
        let detail = try dayDetail(fixture: "golden_app_export_empty_collections_minimal.json", date: "2024-03-01")
        let mapData = DayMapDataExtractor.mapData(from: detail)

        XCTAssertFalse(mapData.hasMapContent)
        XCTAssertTrue(mapData.visitAnnotations.isEmpty)
        XCTAssertTrue(mapData.pathOverlays.isEmpty)
        XCTAssertNil(mapData.fittedRegion)
    }

    func testVisitsWithoutCoordinatesAreSkipped() {
        let detail = DayDetailViewState(
            date: "2024-01-01",
            visits: [
                DayDetailViewState.VisitItem(
                    startTime: nil, endTime: nil, semanticType: "HOME",
                    placeID: nil, lat: nil, lon: nil, accuracyM: nil, sourceType: nil
                )
            ],
            activities: [],
            paths: [],
            totalPathPointCount: 0,
            hasContent: true
        )
        let mapData = DayMapDataExtractor.mapData(from: detail)

        XCTAssertTrue(mapData.visitAnnotations.isEmpty)
        XCTAssertFalse(mapData.hasMapContent)
    }

    func testPathWithSinglePointIsSkipped() {
        let detail = DayDetailViewState(
            date: "2024-01-01",
            visits: [],
            activities: [],
            paths: [
                DayDetailViewState.PathItem(
                    startTime: nil, endTime: nil, activityType: "WALKING",
                    distanceM: 10, pointCount: 1, sourceType: nil,
                    points: [
                        DayDetailViewState.PathPointItem(lat: 52.52, lon: 13.41, time: nil, accuracyM: nil)
                    ]
                )
            ],
            totalPathPointCount: 1,
            hasContent: true
        )
        let mapData = DayMapDataExtractor.mapData(from: detail)

        XCTAssertTrue(mapData.pathOverlays.isEmpty)
        XCTAssertFalse(mapData.hasMapContent)
    }

    // MARK: - Second day (different data)

    func testSecondDayExtractsCorrectly() throws {
        let detail = try dayDetail(fixture: "golden_app_export_sample_small.json", date: "2024-05-02")
        let mapData = DayMapDataExtractor.mapData(from: detail)

        XCTAssertEqual(mapData.visitAnnotations.count, 3)
        XCTAssertEqual(mapData.pathOverlays.count, 2)
        XCTAssertEqual(mapData.pathOverlays[0].activityType, "CYCLING")
        XCTAssertEqual(mapData.pathOverlays[1].activityType, "IN BUS")
        XCTAssertTrue(mapData.hasMapContent)
    }

    // MARK: - Helpers

    private func dayDetail(fixture name: String, date: String) throws -> DayDetailViewState {
        let export = try AppExportDecoder.decode(contentsOf: TestSupport.contractFixtureURL(named: name))
        return try XCTUnwrap(AppExportQueries.dayDetail(for: date, in: export))
    }
}
