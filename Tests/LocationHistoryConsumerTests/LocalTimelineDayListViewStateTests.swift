import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-7B — Store-backed DayList-Presentation.
final class LocalTimelineDayListViewStateTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTDayList-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    private func makeAdapter(visitDates: [String] = ["2024-01-01", "2024-02-15", "2024-03-30"])
        throws -> (LocalTimelineStore, LocalTimelineAppSessionAdapter)
    {
        let url = tempDir.appendingPathComponent("store.sqlite")
        let store = try LocalTimelineStore(url: url)
        let writer = try LocalTimelineImportWriter(store: store, source: "phase7b.json")
        for date in visitDates {
            try writer.addVisit(.init(startTime: "\(date)T08:00:00Z",
                                      endTime: "\(date)T09:00:00Z",
                                      latitude: 48.0, longitude: 11.0,
                                      name: "Spot \(date)"))
        }
        let summary = try writer.finalize()
        let reader = LocalTimelineStoreReader(store: store)
        let session = try LocalTimelineSession.make(reader: reader,
                                                    importID: summary.importId,
                                                    storeURL: url)
        return (store, LocalTimelineAppSessionAdapter(reader: reader, session: session))
    }

    func testDayListReturnsOneRowPerDayNewestFirst() throws {
        let (store, adapter) = try makeAdapter()
        defer { store.close() }

        let viewState = try LocalTimelineDayListViewState.make(adapter: adapter)
        XCTAssertEqual(viewState.rowCount, 3)
        XCTAssertEqual(viewState.rows.map(\.date), ["2024-03-30", "2024-02-15", "2024-01-01"])
        XCTAssertEqual(viewState.sourceFilename, "phase7b.json")
        XCTAssertEqual(viewState.importID, adapter.session.importID)
        XCTAssertTrue(viewState.rows.allSatisfy { $0.visitCount == 1 })
        XCTAssertTrue(viewState.rows.allSatisfy(\.hasContent))
    }

    func testDayListIsEmptyForFreshSessionWithoutDays() throws {
        let url = tempDir.appendingPathComponent("empty.sqlite")
        let store = try LocalTimelineStore(url: url)
        defer { store.close() }
        let writer = try LocalTimelineImportWriter(store: store, source: "empty.json")
        // Fügen nichts hinzu — finalize() liefert leeren Import.
        let summary = try writer.finalize()
        let reader = LocalTimelineStoreReader(store: store)
        let session = try LocalTimelineSession.make(reader: reader,
                                                    importID: summary.importId,
                                                    storeURL: url)
        let viewState = try LocalTimelineDayListViewState.make(reader: reader,
                                                               session: session)
        XCTAssertTrue(viewState.isEmpty)
        XCTAssertEqual(viewState.rowCount, 0)
    }

    func testDayListDoesNotDecodeCoordinates() throws {
        // 50 visits + 1 path mit Geometrie → DayList darf keine Geometrie ziehen.
        let url = tempDir.appendingPathComponent("geo.sqlite")
        let store = try LocalTimelineStore(url: url)
        defer { store.close() }
        let writer = try LocalTimelineImportWriter(store: store, source: "geo.json")
        for i in 0..<50 {
            let date = String(format: "2024-04-%02d", (i % 28) + 1)
            try writer.addVisit(.init(startTime: "\(date)T08:00:00Z",
                                      latitude: 48.0, longitude: 11.0, name: "x"))
        }
        var coords: [Double] = []
        for i in 0..<256 {
            coords.append(48.0 + Double(i) * 0.0001)
            coords.append(11.0 + Double(i) * 0.0001)
        }
        try writer.addPath(.init(startTime: "2024-04-01T10:00:00Z",
                                 endTime: "2024-04-01T11:00:00Z",
                                 mode: "walking",
                                 distanceM: 1234,
                                 flatCoordinates: coords))
        let summary = try writer.finalize()
        let reader = LocalTimelineStoreReader(store: store)
        let session = try LocalTimelineSession.make(reader: reader,
                                                    importID: summary.importId,
                                                    storeURL: url)
        let viewState = try LocalTimelineDayListViewState.make(reader: reader,
                                                               session: session)
        XCTAssertGreaterThan(viewState.rowCount, 0)
        // Korrekte Aggregat-Werte ohne dass irgendwo `[Double]`-Coords gehalten wurden.
        let totalRoutes = viewState.rows.reduce(0) { $0 + $1.routeCount }
        XCTAssertEqual(totalRoutes, 1)
    }
}
