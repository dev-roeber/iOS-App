import Foundation
import XCTest
@testable import LocationHistoryConsumer

final class PerformanceTests: XCTestCase {

    // MARK: - Decoding

    func testLargeExportDecoding() throws {
        let url = try TestSupport.contractFixtureURL(named: "perf_app_export_large.json")
        measure {
            _ = try? AppExportDecoder.decode(contentsOf: url)
        }
    }

    // MARK: - Query layer

    func testLargeExportQueryLayer() throws {
        let url = try TestSupport.contractFixtureURL(named: "perf_app_export_large.json")
        let export = try AppExportDecoder.decode(contentsOf: url)
        measure {
            _ = AppExportQueries.overview(from: export)
            _ = AppExportQueries.daySummaries(from: export)
        }
    }

    func testLargeExportDayDetailQueries() throws {
        let url = try TestSupport.contractFixtureURL(named: "perf_app_export_large.json")
        let export = try AppExportDecoder.decode(contentsOf: url)
        let summaries = AppExportQueries.daySummaries(from: export)
        measure {
            for summary in summaries {
                _ = AppExportQueries.dayDetail(for: summary.date, in: export)
            }
        }
    }

    // MARK: - Map data extraction

    func testLargeExportMapDataExtraction() throws {
        let url = try TestSupport.contractFixtureURL(named: "perf_app_export_large.json")
        let export = try AppExportDecoder.decode(contentsOf: url)
        let summaries = AppExportQueries.daySummaries(from: export)
        let details = summaries.compactMap { AppExportQueries.dayDetail(for: $0.date, in: export) }
        measure {
            for detail in details {
                _ = DayMapDataExtractor.mapData(from: detail)
            }
        }
    }

    // MARK: - Memory

    @available(macOS 13.0, iOS 16.0, *)
    func testLargeExportDecodingMemory() throws {
        let url = try TestSupport.contractFixtureURL(named: "perf_app_export_large.json")
        measure(metrics: [XCTMemoryMetric()]) {
            _ = try? AppExportDecoder.decode(contentsOf: url)
        }
    }
}
