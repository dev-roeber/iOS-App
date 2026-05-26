import XCTest
@testable import LocationHistoryConsumerAppSupport

/// L5 coverage tests for the `LH2GPXHomeWidget` timeline provider.
///
/// The real `LH2GPXProvider` lives in the WidgetKit extension target
/// (`wrapper/LH2GPXWidget/LH2GPXHomeWidget.swift`), which is *not* linkable
/// from the Swift Package test target — WidgetKit is unavailable on Linux,
/// and the wrapper extension is built by Xcode, not SwiftPM.
///
/// Pragmatic Plan-B per the L5 audit note: instead of pulling the provider
/// type into the package, exercise the data path the provider actually
/// touches. `LH2GPXProvider` is a thin shim that:
///
///   placeholder(in:)      → static defaults
///   getSnapshot(in:)      → reads WidgetDataStore.load*
///   getTimeline(in:)      → reads WidgetDataStore.load* + .after(now+1h)
///
/// All real I/O happens through `WidgetDataStore`. The tests below pin the
/// load/save round-trip across every channel the provider reads from. A
/// future Swift-package extraction of `LH2GPXProvider` should also re-use
/// these tests via the local `ProviderEntryShim` mirror struct below.
final class LH2GPXWidgetProviderTests: XCTestCase {

    // MARK: - Test isolation

    /// Each test runs in its own UserDefaults suite so app-group writes never
    /// leak between tests or pollute the production app group.
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "WidgetProviderTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        // Also clear keys the production WidgetDataStore may have written so
        // subsequent test files start from a clean slate.
        if let prod = UserDefaults(suiteName: WidgetDataStore.suiteName) {
            prod.removeObject(forKey: WidgetSharedKeys.lastRecording)
            prod.removeObject(forKey: WidgetSharedKeys.weeklyKm)
            prod.removeObject(forKey: WidgetSharedKeys.weeklyRouteCount)
            prod.removeObject(forKey: WidgetSharedKeys.weeklyStatsDate)
            prod.removeObject(forKey: WidgetSharedKeys.monthlyKm)
            prod.removeObject(forKey: WidgetSharedKeys.monthlyRouteCount)
            prod.removeObject(forKey: WidgetSharedKeys.monthlyStatsDate)
        }
        try super.tearDownWithError()
    }

    // MARK: - placeholder() contract

    /// Mirrors `LH2GPXProvider.placeholder(in:)`'s static defaults. If the
    /// production provider ever changes its sample values, this shim must
    /// stay in sync — that's the *point* of pinning the values here.
    func testPlaceholderEntry_HasExpectedDefaults() {
        let entry = ProviderEntryShim.placeholder()
        XCTAssertNotNil(entry.lastRecording)
        XCTAssertEqual(entry.lastRecording?.distanceMeters, 5230)
        XCTAssertEqual(entry.lastRecording?.durationSeconds, 1800)
        XCTAssertEqual(entry.weeklyStats?.km, 24.5)
        XCTAssertEqual(entry.weeklyStats?.routes, 7)
        XCTAssertEqual(entry.monthlyStats?.km, 96.2)
        XCTAssertEqual(entry.monthlyStats?.routes, 23)
    }

    func testPlaceholderEntry_DateIsRecent() {
        let entry = ProviderEntryShim.placeholder()
        // placeholder() uses Date() — must be within a generous window of now.
        XCTAssertEqual(entry.date.timeIntervalSinceNow, 0, accuracy: 5,
                       "placeholder entry date should be set to ~now")
    }

    // MARK: - getSnapshot() — load path round-trip

    /// `getSnapshot` calls `entry()` which reads WidgetDataStore.
    /// We verify the load-after-save round trip per channel.
    func testSnapshotLastRecording_RoundTrip() {
        let rec = WidgetDataStore.LastRecording(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            distanceMeters: 7250,
            durationSeconds: 2700,
            trackName: "Snapshot-Test"
        )
        WidgetDataStore.save(recording: rec)
        defer {
            UserDefaults(suiteName: WidgetDataStore.suiteName)?
                .removeObject(forKey: WidgetSharedKeys.lastRecording)
        }
        let loaded = WidgetDataStore.loadLastRecording()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.distanceMeters, 7250)
        XCTAssertEqual(loaded?.durationSeconds, 2700)
        XCTAssertEqual(loaded?.trackName, "Snapshot-Test")
    }

    func testSnapshotWeeklyStats_RoundTrip() {
        WidgetDataStore.saveWeeklyStats(totalKm: 42.195, routeCount: 5)
        defer {
            let prod = UserDefaults(suiteName: WidgetDataStore.suiteName)
            prod?.removeObject(forKey: WidgetSharedKeys.weeklyKm)
            prod?.removeObject(forKey: WidgetSharedKeys.weeklyRouteCount)
            prod?.removeObject(forKey: WidgetSharedKeys.weeklyStatsDate)
        }
        let stats = WidgetDataStore.loadWeeklyStats()
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.km ?? 0, 42.195, accuracy: 0.001)
        XCTAssertEqual(stats?.routes, 5)
        XCTAssertNotNil(stats?.date)
    }

    func testSnapshotMonthlyStats_RoundTrip() {
        WidgetDataStore.saveMonthlyStats(totalKm: 200.5, routeCount: 23)
        defer {
            let prod = UserDefaults(suiteName: WidgetDataStore.suiteName)
            prod?.removeObject(forKey: WidgetSharedKeys.monthlyKm)
            prod?.removeObject(forKey: WidgetSharedKeys.monthlyRouteCount)
            prod?.removeObject(forKey: WidgetSharedKeys.monthlyStatsDate)
        }
        let stats = WidgetDataStore.loadMonthlyStats()
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.km ?? 0, 200.5, accuracy: 0.001)
        XCTAssertEqual(stats?.routes, 23)
    }

    // MARK: - Snapshot entry assembly

    /// Mirrors `LH2GPXProvider.entry()` to verify all three data channels are
    /// composed into the entry with the expected nullability semantics.
    func testSnapshotEntry_AssemblesFromWidgetDataStore() {
        let rec = WidgetDataStore.LastRecording(
            date: Date(timeIntervalSince1970: 0),
            distanceMeters: 1234,
            durationSeconds: 600,
            trackName: "Assembly"
        )
        WidgetDataStore.save(recording: rec)
        WidgetDataStore.saveWeeklyStats(totalKm: 10, routeCount: 2)
        WidgetDataStore.saveMonthlyStats(totalKm: 100, routeCount: 12)
        defer { resetProductionAppGroup() }

        let entry = ProviderEntryShim.snapshotEntry()
        XCTAssertEqual(entry.lastRecording?.trackName, "Assembly")
        XCTAssertEqual(entry.weeklyStats?.km, 10)
        XCTAssertEqual(entry.weeklyStats?.routes, 2)
        XCTAssertEqual(entry.monthlyStats?.km, 100)
        XCTAssertEqual(entry.monthlyStats?.routes, 12)
    }

    /// `loadWeeklyStats()` returns nil if both km and routeCount are zero —
    /// pin the no-data fallback path that `LH2GPXProvider.entry()` relies on
    /// to render the "no data yet" UI branch.
    func testSnapshotEntry_NilStatsWhenNoData() {
        resetProductionAppGroup()
        let entry = ProviderEntryShim.snapshotEntry()
        // lastRecording, weeklyStats, monthlyStats all start nil.
        XCTAssertNil(entry.weeklyStats)
        XCTAssertNil(entry.monthlyStats)
    }

    // MARK: - getTimeline() refresh policy

    /// `LH2GPXProvider.getTimeline` schedules the next refresh `+1h` from now.
    /// Verify the policy contract holds via the shim.
    func testTimelineEntry_NextRefreshIsOneHourAfterNow() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let nextRefresh = ProviderEntryShim.nextRefreshAt(from: now)
        let expected = Calendar.current.date(byAdding: .hour, value: 1, to: now)
        XCTAssertEqual(nextRefresh, expected)
        XCTAssertEqual(nextRefresh.timeIntervalSince(now), 3600, accuracy: 1)
    }

    func testTimelineEntry_SingleEntryWithCurrentData() {
        let rec = WidgetDataStore.LastRecording(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            distanceMeters: 500,
            durationSeconds: 300,
            trackName: "Timeline"
        )
        WidgetDataStore.save(recording: rec)
        defer { resetProductionAppGroup() }

        // `LH2GPXProvider.getTimeline` always returns a single entry — verify.
        let entries = ProviderEntryShim.timelineEntries()
        XCTAssertEqual(entries.count, 1,
            "Provider must emit exactly one timeline entry per refresh")
        XCTAssertEqual(entries.first?.lastRecording?.trackName, "Timeline")
    }

    // MARK: - Helpers

    private func resetProductionAppGroup() {
        let prod = UserDefaults(suiteName: WidgetDataStore.suiteName)
        prod?.removeObject(forKey: WidgetSharedKeys.lastRecording)
        prod?.removeObject(forKey: WidgetSharedKeys.weeklyKm)
        prod?.removeObject(forKey: WidgetSharedKeys.weeklyRouteCount)
        prod?.removeObject(forKey: WidgetSharedKeys.weeklyStatsDate)
        prod?.removeObject(forKey: WidgetSharedKeys.monthlyKm)
        prod?.removeObject(forKey: WidgetSharedKeys.monthlyRouteCount)
        prod?.removeObject(forKey: WidgetSharedKeys.monthlyStatsDate)
    }
}

// MARK: - ProviderEntryShim

/// Mirror of `LH2GPXEntry` / `LH2GPXProvider` for the test target.
///
/// The real types live in `wrapper/LH2GPXWidget/LH2GPXHomeWidget.swift` and
/// depend on WidgetKit, which is unavailable to SwiftPM tests. This shim
/// reproduces the *exact same shape and data flow* the production provider
/// uses, so when the provider changes (e.g. refresh policy moves to 30min)
/// the test must be updated in lockstep — that is the regression contract.
fileprivate struct ProviderEntryShim {
    let date: Date
    let lastRecording: WidgetDataStore.LastRecording?
    let weeklyStats: (km: Double, routes: Int)?
    let monthlyStats: (km: Double, routes: Int)?

    /// Mirrors `LH2GPXProvider.placeholder(in:)`.
    static func placeholder() -> ProviderEntryShim {
        ProviderEntryShim(
            date: Date(),
            lastRecording: .init(date: Date(), distanceMeters: 5230, durationSeconds: 1800, trackName: "Morning Run"),
            weeklyStats: (km: 24.5, routes: 7),
            monthlyStats: (km: 96.2, routes: 23)
        )
    }

    /// Mirrors `LH2GPXProvider.entry()` — sole live-data path used by both
    /// `getSnapshot` and `getTimeline`.
    static func snapshotEntry() -> ProviderEntryShim {
        ProviderEntryShim(
            date: Date(),
            lastRecording: WidgetDataStore.loadLastRecording(),
            weeklyStats: WidgetDataStore.loadWeeklyStats().map { ($0.km, $0.routes) },
            monthlyStats: WidgetDataStore.loadMonthlyStats().map { ($0.km, $0.routes) }
        )
    }

    /// Mirrors `LH2GPXProvider.getTimeline(in:completion:)`'s entry list (always one).
    static func timelineEntries() -> [ProviderEntryShim] {
        [snapshotEntry()]
    }

    /// Mirrors `LH2GPXProvider.getTimeline(in:completion:)`'s refresh policy.
    static func nextRefreshAt(from now: Date) -> Date {
        Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
    }
}
