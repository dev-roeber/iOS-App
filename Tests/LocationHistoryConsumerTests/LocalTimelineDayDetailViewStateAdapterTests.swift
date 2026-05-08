import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-7B — Store-backed DayDetail-Presentation.
final class LocalTimelineDayDetailViewStateAdapterTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTDetail-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    private func makeStore() throws
        -> (LocalTimelineStore, LocalTimelineSession, LocalTimelineStoreReader, String)
    {
        let url = tempDir.appendingPathComponent("store.sqlite")
        let store = try LocalTimelineStore(url: url)
        let writer = try LocalTimelineImportWriter(store: store, source: "phase7b.json")
        try writer.addVisit(.init(startTime: "2024-05-01T08:00:00Z",
                                  endTime: "2024-05-01T09:00:00Z",
                                  latitude: 48.0, longitude: 11.0, name: "Home"))
        try writer.addPath(.init(startTime: "2024-05-01T10:00:00Z",
                                 endTime: "2024-05-01T10:30:00Z",
                                 mode: "cycling",
                                 distanceM: 500,
                                 flatCoordinates: [48.0, 11.0, 48.001, 11.001, 48.002, 11.002]))
        let summary = try writer.finalize()
        let reader = LocalTimelineStoreReader(store: store)
        let session = try LocalTimelineSession.make(reader: reader,
                                                    importID: summary.importId,
                                                    storeURL: url)
        let day = try XCTUnwrap(reader.days(forImportId: session.importID).first)
        return (store, session, reader, day.id)
    }

    func testDetailReturnsVisitsActivitiesAndPathMetadata() throws {
        let (store, session, reader, dayId) = try makeStore()
        defer { store.close() }
        let adapter = LocalTimelineDayDetailViewStateAdapter(reader: reader, session: session)
        let detail = try XCTUnwrap(try adapter.viewState(forDayId: dayId))
        XCTAssertEqual(detail.visits.count, 1)
        XCTAssertGreaterThanOrEqual(detail.paths.count, 1)
        let cycling = try XCTUnwrap(detail.paths.first(where: { $0.mode == "cycling" }))
        XCTAssertEqual(cycling.pointCount, 3)
        XCTAssertTrue(detail.hasContent)
    }

    func testDetailDoesNotEagerDecodeCoordinates() throws {
        let (store, session, reader, dayId) = try makeStore()
        defer { store.close() }
        let adapter = LocalTimelineDayDetailViewStateAdapter(reader: reader, session: session)
        let detail = try XCTUnwrap(try adapter.viewState(forDayId: dayId))
        // Path-Metadata trägt nur `pointCount`, keine echte `[Double]`-Liste.
        let cycling = try XCTUnwrap(detail.paths.first(where: { $0.mode == "cycling" }))
        XCTAssertEqual(cycling.pointCount, 3)
    }

    func testExplicitCoordinateLookup() throws {
        let (store, session, reader, dayId) = try makeStore()
        defer { store.close() }
        let adapter = LocalTimelineDayDetailViewStateAdapter(reader: reader, session: session)
        let detail = try XCTUnwrap(try adapter.viewState(forDayId: dayId))
        let cycling = try XCTUnwrap(detail.paths.first(where: { $0.mode == "cycling" }))
        let coords = try adapter.coordinates(forPathId: cycling.id)
        XCTAssertEqual(coords.count, 3)
        XCTAssertEqual(coords[0].lat, 48.0, accuracy: 1e-6)
        XCTAssertEqual(coords[0].lon, 11.0, accuracy: 1e-6)
    }

    func testUnknownPathThrowsControlledError() throws {
        let (store, session, reader, _) = try makeStore()
        defer { store.close() }
        let adapter = LocalTimelineDayDetailViewStateAdapter(reader: reader, session: session)
        XCTAssertThrowsError(try adapter.coordinates(forPathId: "does-not-exist")) { error in
            guard let err = error as? LocalTimelineStoreReader.ReaderError,
                  case .unknownPath = err else {
                return XCTFail("expected ReaderError.unknownPath, got \(error)")
            }
        }
    }

    func testUnknownDayReturnsNil() throws {
        let (store, session, reader, _) = try makeStore()
        defer { store.close() }
        let adapter = LocalTimelineDayDetailViewStateAdapter(reader: reader, session: session)
        XCTAssertNil(try adapter.viewState(forDayId: "missing"))
    }
}
