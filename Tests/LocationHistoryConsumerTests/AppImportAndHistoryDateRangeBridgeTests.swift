import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class AppImportAndHistoryDateRangeBridgeTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "AppImportAndHistoryDateRangeBridgeTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testHistoryDateRangeBridgeProjectsOverviewInsightsAndSummaries() throws {
        let export = try AppExportDecoder.decode(contentsOf: TestSupport.contractFixtureURL(named: "golden_app_export_contract_gate.json"))
        let rangeFilter = HistoryDateRangeFilter(
            preset: .custom,
            customStart: date("2024-05-02"),
            customEnd: date("2024-05-02")
        )
        let queryFilter = AppHistoryDateRangeQueryBridge.mergedFilter(
            base: AppExportQueryFilter(exportFilters: export.meta.filters),
            rangeFilter: rangeFilter
        )

        let overview = AppExportQueries.overview(from: export, applying: queryFilter)
        let summaries = AppExportQueries.daySummaries(from: export, applying: queryFilter)
        let insights = AppExportQueries.insights(from: export, applying: queryFilter)

        XCTAssertEqual(queryFilter?.fromDate, "2024-05-02")
        XCTAssertEqual(queryFilter?.toDate, "2024-05-02")
        XCTAssertEqual(overview.dayCount, 1)
        XCTAssertEqual(summaries.map(\.date), ["2024-05-02"])
        XCTAssertEqual(insights.dateRange?.firstDate, "2024-05-02")
        XCTAssertEqual(insights.dateRange?.lastDate, "2024-05-02")
    }

    func testHistoryDateRangeBridgeRespectsUpstreamDateBounds() {
        let baseFilter = AppExportQueryFilter(
            fromDate: "2024-01-01",
            toDate: "2024-01-31",
            maxAccuracyM: 25
        )
        let rangeFilter = HistoryDateRangeFilter(
            preset: .custom,
            customStart: date("2024-01-10"),
            customEnd: date("2024-01-20")
        )

        let merged = AppHistoryDateRangeQueryBridge.mergedFilter(base: baseFilter, rangeFilter: rangeFilter)

        XCTAssertEqual(merged?.fromDate, "2024-01-10")
        XCTAssertEqual(merged?.toDate, "2024-01-20")
        XCTAssertEqual(merged?.maxAccuracyM, 25)
    }

    func testRememberImportedFilePersistsRecentEntryAndLastImportBookmark() {
        let url = makeTemporaryFile(name: "remember.json")
        defer { try? FileManager.default.removeItem(at: url) }

        AppImportStateBridge.rememberImportedFile(url, userDefaults: defaults)

        let recentEntries = RecentFilesStore.load(userDefaults: defaults)
        XCTAssertEqual(recentEntries.count, 1)
        XCTAssertEqual(recentEntries[0].displayName, "remember.json")
        XCTAssertEqual(ImportBookmarkStore.restore(userDefaults: defaults)?.lastPathComponent, "remember.json")
    }

    func testRestoreLastImportIfEnabledHonorsToggle() {
        let url = makeTemporaryFile(name: "restore.json")
        defer { try? FileManager.default.removeItem(at: url) }

        AppImportStateBridge.rememberImportedFile(url, userDefaults: defaults)

        XCTAssertNil(AppImportStateBridge.restoreLastImportIfEnabled(autoRestoreEnabled: false, userDefaults: defaults))
        XCTAssertEqual(
            AppImportStateBridge.restoreLastImportIfEnabled(autoRestoreEnabled: true, userDefaults: defaults)?.lastPathComponent,
            "restore.json"
        )
    }

    private func makeTemporaryFile(name: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        FileManager.default.createFile(atPath: url.path, contents: Data("{}".utf8))
        return url
    }

    private func date(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)!
    }
}
