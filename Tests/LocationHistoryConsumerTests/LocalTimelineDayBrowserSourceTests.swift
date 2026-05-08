import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-9B — `LocalTimelineDayBrowserSource` ist die Foundation-only
/// Quelle für den Store-DayList/DayDetail-UI-Hook. Die Tests sichern, daß
/// Liste und Detail über den gebundenen Reader korrekt fließen, ohne daß
/// `coord_blob`-Daten dekodiert werden.
final class LocalTimelineDayBrowserSourceTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTDayBrowser-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    private func makeSession(visitDates: [String]) throws
        -> (LocalTimelineStore, LocalTimelineSession, LocalTimelineStoreReader)
    {
        let url = tempDir.appendingPathComponent("browser.sqlite")
        let store = try LocalTimelineStore(url: url)
        let writer = try LocalTimelineImportWriter(store: store, source: "browser.json")
        for date in visitDates {
            try writer.addVisit(.init(startTime: "\(date)T08:00:00Z",
                                      endTime: "\(date)T09:30:00Z",
                                      latitude: 48.1, longitude: 11.5,
                                      name: "Spot \(date)"))
        }
        let summary = try writer.finalize()
        let reader = LocalTimelineStoreReader(store: store)
        let session = try LocalTimelineSession.make(reader: reader,
                                                    importID: summary.importId,
                                                    storeURL: url)
        return (store, session, reader)
    }

    func testBindLoadsDayListNewestFirst() throws {
        let (store, session, reader) = try makeSession(
            visitDates: ["2024-01-10", "2024-03-12", "2024-02-20"]
        )
        defer { store.close() }

        let source = LocalTimelineDayBrowserSource.bind(session: session, reader: reader)
        let list = try source.loadList()

        XCTAssertEqual(list.rows.map(\.date),
                       ["2024-03-12", "2024-02-20", "2024-01-10"])
        XCTAssertEqual(list.sourceFilename, "browser.json")
    }

    func testBindLoadsDayDetailVisitsActivitiesPathMetadata() throws {
        let (store, session, reader) = try makeSession(visitDates: ["2024-04-01"])
        defer { store.close() }

        let source = LocalTimelineDayBrowserSource.bind(session: session, reader: reader)
        let list = try source.loadList()
        let firstDay = try XCTUnwrap(list.rows.first)

        let detail = try XCTUnwrap(try source.loadDetail(firstDay.dayId))
        XCTAssertEqual(detail.date, "2024-04-01")
        XCTAssertEqual(detail.visits.count, 1)
        XCTAssertEqual(detail.visits.first?.name, "Spot 2024-04-01")
        XCTAssertEqual(detail.totalPathPointCount, 0)
    }

    func testBindReturnsNilDetailForUnknownDay() throws {
        let (store, session, reader) = try makeSession(visitDates: ["2024-04-01"])
        defer { store.close() }

        let source = LocalTimelineDayBrowserSource.bind(session: session, reader: reader)
        let detail = try source.loadDetail("unknown-day-id")
        XCTAssertNil(detail)
    }

    func testBindCarriesSession() throws {
        let (store, session, reader) = try makeSession(visitDates: ["2024-04-01"])
        defer { store.close() }
        let source = LocalTimelineDayBrowserSource.bind(session: session, reader: reader)
        XCTAssertEqual(source.session.importID, session.importID)
    }
}
