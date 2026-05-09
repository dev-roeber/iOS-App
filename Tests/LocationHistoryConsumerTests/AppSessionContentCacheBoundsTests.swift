import XCTest
import LocationHistoryConsumer
import LocationHistoryConsumerAppSupport

/// Deep Audit 2026-05-09 L-04 — Behavior-Tests, dass viele unterschiedliche
/// Filter-/Day-Keys keine unbounded Cache-Akkumulation in `AppSessionContent`
/// auslösen und dass die Ausgabe nach Eviction semantisch identisch
/// nachberechnet wird. Wir prüfen das zugesicherte Verhalten, ohne private
/// API zu exponieren: bei vielen verschiedenen Keys liefert der Cache trotz
/// LRU-Eviction stabile Resultate (Recompute liefert gleichen Wert).
final class AppSessionContentCacheBoundsTests: XCTestCase {

    private func loadContent() throws -> AppSessionContent {
        let url = try TestSupport.contractFixtureURL(named: "golden_app_export_sample_small.json")
        let export = try AppExportDecoder.decode(contentsOf: url)
        return AppSessionContent(export: export, source: .demoFixture(name: "golden_app_export_sample_small"))
    }

    private func makeFilter(year: Int, month: Int) -> AppExportQueryFilter {
        AppExportQueryFilter(year: year, month: month)
    }

    func testManyDistinctFilterKeysProduceStableOverviewResults() throws {
        let content = try loadContent()
        // Erzeuge weit mehr distinct keys als jede konservative LRU-Capacity.
        var observed: [AppExportQueryFilter: ExportOverview] = [:]
        for year in 2000..<2100 {
            for month in 1...3 {
                let filter = makeFilter(year: year, month: month)
                let overview = content.overview(applying: filter)
                observed[filter] = overview
            }
        }
        // 300 Keys insgesamt — jeder Re-Read muss denselben Wert liefern.
        for (filter, expected) in observed {
            XCTAssertEqual(content.overview(applying: filter), expected)
        }
    }

    func testManyDistinctFilterKeysProduceStableDaySummaries() throws {
        let content = try loadContent()
        var observed: [AppExportQueryFilter: [DaySummary]] = [:]
        for year in 2000..<2050 {
            for month in 1...4 {
                let filter = makeFilter(year: year, month: month)
                observed[filter] = content.daySummaries(applying: filter)
            }
        }
        for (filter, expected) in observed {
            let recomputed = content.daySummaries(applying: filter)
            XCTAssertEqual(recomputed.map { $0.date }, expected.map { $0.date })
        }
    }

    func testEvictionDoesNotChangeInsightsResult() throws {
        let content = try loadContent()
        let filter = makeFilter(year: 2024, month: 6)
        let first = content.insights(applying: filter)
        // Cache mit vielen anderen Filter-Keys fluten → ursprünglicher Key
        // soll evictet sein, wird aber beim nächsten Aufruf neu berechnet.
        for year in 1900..<2000 {
            _ = content.insights(applying: makeFilter(year: year, month: 1))
        }
        XCTAssertEqual(content.insights(applying: filter), first)
    }

    func testManyDayDetailKeysProduceStableResults() throws {
        let content = try loadContent()
        // Wir haben i.d.R. nur wenige distinct Tage in der Fixture; deshalb
        // kreuzen wir mit unterschiedlichen Filter-Variationen, um den
        // dayDetailCache mit vielen unterschiedlichen Composite-Keys zu
        // füllen.
        guard let date = content.daySummaries.first?.date else {
            throw XCTSkip("Fixture hat keine Days")
        }
        let baseDetail = content.detail(for: date)
        for year in 1900..<2050 {
            _ = content.detail(for: date, applying: makeFilter(year: year, month: 1))
        }
        let recomputed = content.detail(for: date)
        XCTAssertEqual(recomputed?.date, baseDetail?.date)
    }

    func testManyDayMapKeysProduceStableResults() throws {
        let content = try loadContent()
        guard let date = content.daySummaries.first?.date else {
            throw XCTSkip("Fixture hat keine Days")
        }
        let baseMap = content.mapData(for: date)
        for year in 1900..<2000 {
            _ = content.mapData(for: date, applying: makeFilter(year: year, month: 1))
        }
        XCTAssertEqual(content.mapData(for: date), baseMap)
    }
}
