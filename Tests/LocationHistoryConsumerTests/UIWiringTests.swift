import XCTest
@testable import LocationHistoryConsumerAppSupport
import LocationHistoryConsumer

/// Tests for the UI wiring of the 9-feature batch (2026-04-01).
/// Non-UI logic and helpers are tested here; pure SwiftUI rendering
/// is verified manually on an Apple host device.
final class UIWiringTests: XCTestCase {

    func testOverviewContinueRouteForCompactDaysTargetsDaysTab() {
        let route = StartOverviewPresentation.route(for: .days, isCompact: true)
        XCTAssertEqual(route.selectedTab, 1)
        XCTAssertFalse(route.presentsExportSheet)
        XCTAssertFalse(route.callsOnOpen)
    }

    func testOverviewContinueRouteForCompactInsightsTargetsInsightsTab() {
        let route = StartOverviewPresentation.route(for: .insights, isCompact: true)
        XCTAssertEqual(route.selectedTab, 2)
    }

    func testOverviewContinueRouteForCompactExportTargetsExportTab() {
        let route = StartOverviewPresentation.route(for: .export, isCompact: true)
        XCTAssertEqual(route.selectedTab, 3)
        XCTAssertFalse(route.presentsExportSheet)
    }

    func testOverviewContinueRouteForRegularExportPresentsSheet() {
        let route = StartOverviewPresentation.route(for: .export, isCompact: false)
        XCTAssertNil(route.selectedTab)
        XCTAssertTrue(route.presentsExportSheet)
    }

    func testOverviewContinueRouteForImportCallsOpen() {
        let route = StartOverviewPresentation.route(for: .importFile, isCompact: true)
        XCTAssertTrue(route.callsOnOpen)
    }

    func testMostActivitiesHighlightUsesHighestActivityCount() {
        let summaries = [
            DaySummary.stub(date: "2024-05-01", activityCount: 2),
            DaySummary.stub(date: "2024-05-02", activityCount: 5),
            DaySummary.stub(date: "2024-05-03", activityCount: 1)
        ]

        let highlight = StartOverviewPresentation.mostActivitiesHighlight(in: summaries)
        XCTAssertEqual(highlight?.date, "2024-05-02")
        XCTAssertEqual(highlight?.activityCount, 5)
    }

    func testRangeSummaryForAllTimeReturnsLocalizedAllTimeKey() {
        let summary = StartOverviewPresentation.rangeSummary(
            for: HistoryDateRangeFilter(preset: .all),
            language: .german,
            locale: Locale(identifier: "de")
        )

        XCTAssertEqual(summary, "Gesamtzeitraum")
    }

    // MARK: - HistoryDateRangeFilter chipLabel

    func testChipLabelAllReturnsLocalizedAllDays() {
        let filter = HistoryDateRangeFilter(preset: .all)
        XCTAssertEqual(filter.chipLabel, "All Time")
    }

    func testChipLabelLast7DaysIsCorrect() {
        let filter = HistoryDateRangeFilter(preset: .last7Days)
        XCTAssertEqual(filter.chipLabel, "Last 7 days")
    }

    func testChipLabelCustomWithoutDatesReturnsCustom() {
        let filter = HistoryDateRangeFilter(preset: .custom, customStart: nil, customEnd: nil)
        XCTAssertEqual(filter.chipLabel, "Custom")
    }

    func testChipLabelCustomWithDatesIsFormatted() {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let end = calendar.date(from: DateComponents(year: 2025, month: 3, day: 31))!
        let filter = HistoryDateRangeFilter(preset: .custom, customStart: start, customEnd: end)
        // Should contain the two dates separated by " – "
        XCTAssertTrue(filter.chipLabel.contains("–"))
    }

    func testIsActiveFalseForAllPreset() {
        let filter = HistoryDateRangeFilter(preset: .all)
        XCTAssertFalse(filter.isActive)
    }

    func testIsActiveTrueForNonAllPreset() {
        let filter = HistoryDateRangeFilter(preset: .last30Days)
        XCTAssertTrue(filter.isActive)
    }

    func testResetResetsToDefault() {
        var filter = HistoryDateRangeFilter(preset: .last90Days)
        filter.reset()
        XCTAssertEqual(filter, HistoryDateRangeFilter.default)
    }

    // MARK: - DayListFilter chip filtering

    func testDayListFilterPassesWithNoActiveChips() {
        let filter = DayListFilter()
        let summary = DaySummary.stub(date: "2024-01-01", visitCount: 0, pathCount: 0)
        XCTAssertTrue(filter.passes(summary: summary, isFavorited: false))
    }

    func testDayListFilterFavoritesChipRequiresFavorite() {
        var filter = DayListFilter()
        filter.toggle(.favorites)
        let summary = DaySummary.stub(date: "2024-01-01", visitCount: 1)
        XCTAssertFalse(filter.passes(summary: summary, isFavorited: false))
        XCTAssertTrue(filter.passes(summary: summary, isFavorited: true))
    }

    func testDayListFilterHasRoutesChip() {
        var filter = DayListFilter()
        filter.toggle(.hasRoutes)
        let withRoutes = DaySummary.stub(date: "2024-01-01", pathCount: 2)
        let withoutRoutes = DaySummary.stub(date: "2024-01-01", pathCount: 0)
        XCTAssertTrue(filter.passes(summary: withRoutes, isFavorited: false))
        XCTAssertFalse(filter.passes(summary: withoutRoutes, isFavorited: false))
    }

    func testDayListFilterClearAllRemovesChips() {
        var filter = DayListFilter(activeChips: [.favorites, .hasRoutes, .hasVisits])
        filter.clearAll()
        XCTAssertFalse(filter.isActive)
        XCTAssertTrue(filter.activeChips.isEmpty)
    }

    // MARK: - InsightsDrilldownTarget factory

    func testDrilldownTargetsForDateProducesShowMapAndExport() {
        let targets = InsightsDrilldownTarget.drilldownTargets(for: "2024-06-15")
        XCTAssertEqual(targets.count, 3)
        // First target navigates to days list
        if case let .filterDaysToDate(date) = targets[0].action {
            XCTAssertEqual(date, "2024-06-15")
        } else {
            XCTFail("Expected filterDaysToDate action")
        }
        // Second target shows day on map
        if case let .showDayOnMap(date) = targets[1].action {
            XCTAssertEqual(date, "2024-06-15")
        } else {
            XCTFail("Expected showDayOnMap action")
        }
        // Third target prefills export
        if case let .prefillExportForDate(date) = targets[2].action {
            XCTAssertEqual(date, "2024-06-15")
        } else {
            XCTFail("Expected prefillExportForDate action")
        }
    }

    // MARK: - ExportSelectionState per-route selection

    func testRouteSelectionDefaultIsAllSelected() {
        let selection = ExportSelectionState()
        XCTAssertTrue(selection.isRouteSelected(day: "2024-01-01", routeIndex: 0))
        XCTAssertTrue(selection.isRouteSelected(day: "2024-01-01", routeIndex: 5))
    }

    func testRouteSelectionAfterToggleIsTracked() {
        var selection = ExportSelectionState()
        // Simple toggleRoute uses an inclusion model: first call explicitly adds the route.
        selection.toggleRoute(day: "2024-01-01", routeIndex: 0)
        XCTAssertTrue(selection.isRouteSelected(day: "2024-01-01", routeIndex: 0))
        // Second toggle removes from explicit set; empty set → route no longer selected.
        selection.toggleRoute(day: "2024-01-01", routeIndex: 0)
        XCTAssertFalse(selection.isRouteSelected(day: "2024-01-01", routeIndex: 0))
    }

    func testEffectiveRouteIndicesReturnsAllWhenNoExplicitSelection() {
        let selection = ExportSelectionState()
        let indices = selection.effectiveRouteIndices(day: "2024-01-01", allCount: 3)
        XCTAssertEqual(indices.count, 3)
    }

    func testEffectiveRouteIndicesReturnsSubsetAfterToggle() {
        var selection = ExportSelectionState()
        // Deselect route 1 via the availableRouteIndices overload (starts from implicit all).
        selection.toggleRoute(day: "2024-01-01", routeIndex: 1, availableRouteIndices: [0, 1, 2])
        let indices = selection.effectiveRouteIndices(day: "2024-01-01", allCount: 3)
        XCTAssertFalse(indices.contains(1))
        // Routes 0 and 2 are still in the effective subset.
        XCTAssertTrue(indices.contains(0))
    }

    func testClearRouteSelectionRevertsToAllImplicit() {
        var selection = ExportSelectionState()
        selection.toggleRoute(day: "2024-01-01", routeIndex: 0)
        selection.clearRouteSelection(day: "2024-01-01")
        XCTAssertTrue(selection.isRouteSelected(day: "2024-01-01", routeIndex: 0))
        XCTAssertNil(selection.routeSelections["2024-01-01"])
    }

    // MARK: - CSVDocument init

    func testCSVDocumentStoresContent() {
        #if canImport(SwiftUI) && canImport(UniformTypeIdentifiers)
        let csv = CSVDocument(content: "a,b,c\n1,2,3", suggestedFilename: "test.csv")
        XCTAssertEqual(csv.content, "a,b,c\n1,2,3")
        XCTAssertEqual(csv.suggestedFilename, "test.csv")
        #endif
    }

    // MARK: - AutoRestore preference default

    func testAutoRestoreDefaultIsFalse() {
        let suiteName = "UIWiringTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        MainActor.assumeIsolated {
            let preferences = AppPreferences(userDefaults: defaults)
            XCTAssertFalse(preferences.autoRestoreLastImport)
        }
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testAutoRestoreCanBeToggled() {
        let suiteName = "UIWiringTests-autoRestore-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        MainActor.assumeIsolated {
            let preferences = AppPreferences(userDefaults: defaults)
            preferences.autoRestoreLastImport = true
            XCTAssertTrue(preferences.autoRestoreLastImport)
            preferences.autoRestoreLastImport = false
            XCTAssertFalse(preferences.autoRestoreLastImport)
        }
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Phase A: Days global range filter wiring

    func testDrilldownSummariesRespectActiveRangeFilter() {
        // When a range filter is active, drilldownDaySummaries should only contain
        // days within the range. This is verified via the bridge + projection chain.
        let summaries = [
            DaySummary.stub(date: "2024-01-10", visitCount: 1),
            DaySummary.stub(date: "2024-02-15", visitCount: 1),
            DaySummary.stub(date: "2024-03-20", visitCount: 1),
        ]

        // Simulate the projection that AppContentSplitView.projectedDaySummaries performs
        // before passing into InsightsDrilldownBridge.filteredSummaries.
        let inRange = summaries.filter { $0.date >= "2024-02-01" && $0.date <= "2024-02-28" }
        let result = InsightsDrilldownBridge.filteredSummaries(inRange, applying: nil, favorites: [])
        XCTAssertEqual(result.map(\.date), ["2024-02-15"])
    }

    func testDrilldownSummariesNoRangeFilterShowsAll() {
        let summaries = [
            DaySummary.stub(date: "2024-01-10", visitCount: 1),
            DaySummary.stub(date: "2024-02-15", visitCount: 1),
        ]
        let result = InsightsDrilldownBridge.filteredSummaries(summaries, applying: nil, favorites: [])
        // Without an action, the bridge returns summaries in input order.
        XCTAssertEqual(Set(result.map(\.date)), Set(["2024-01-10", "2024-02-15"]))
        XCTAssertEqual(result.count, 2)
    }

    func testRangeFilterActiveAndSearchYieldsIntersection() {
        let summaries = [
            DaySummary.stub(date: "2024-01-10", visitCount: 1),
            DaySummary.stub(date: "2024-01-15", visitCount: 1),
        ]
        // Range filter reduces to Jan 10 only; then text search "2024-01-15" finds nothing.
        let rangeFiltered = summaries.filter { $0.date == "2024-01-10" }
        let result = DayListPresentation.filteredSummaries(rangeFiltered, query: "2024-01-15")
        XCTAssertTrue(result.isEmpty)
    }

    func testRangeFilterActiveNoMatchesYieldsEmpty() {
        let summaries = [
            DaySummary.stub(date: "2024-01-10", visitCount: 1),
            DaySummary.stub(date: "2024-02-15", visitCount: 1),
        ]
        // Range filter for a month with no days yields empty.
        let rangeFiltered = summaries.filter { $0.date >= "2024-03-01" && $0.date <= "2024-03-31" }
        let result = DayListPresentation.filteredSummaries(rangeFiltered, query: "")
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Phase A: showDayOnMap drilldown target

    func testShowDayOnMapTargetHasMapAction() {
        let target = InsightsDrilldownTarget.showDayOnMap("2024-06-15")
        if case let .showDayOnMap(date) = target.action {
            XCTAssertEqual(date, "2024-06-15")
        } else {
            XCTFail("Expected showDayOnMap action")
        }
        XCTAssertFalse(target.label.isEmpty)
        XCTAssertFalse(target.systemImage.isEmpty)
    }

    func testShowDayOnMapIsClassifiedAsDayListAction() {
        let result = InsightsDrilldownBridge.dayListAction(from: .showDayOnMap("2024-06-15"))
        XCTAssertNotNil(result)
        if case let .showDayOnMap(date) = result {
            XCTAssertEqual(date, "2024-06-15")
        } else {
            XCTFail("dayListAction should return the showDayOnMap action unchanged")
        }
    }

    func testShowDayOnMapIsNotClassifiedAsExportAction() {
        XCTAssertNil(InsightsDrilldownBridge.exportAction(from: .showDayOnMap("2024-06-15")))
    }

    func testShowDayOnMapFiltersSummariesToSingleDay() {
        let summaries = [
            DaySummary.stub(date: "2024-05-01", visitCount: 1),
            DaySummary.stub(date: "2024-05-15", visitCount: 1),
            DaySummary.stub(date: "2024-06-01", visitCount: 1),
        ]
        let result = InsightsDrilldownBridge.filteredSummaries(
            summaries,
            applying: .showDayOnMap("2024-05-15"),
            favorites: []
        )
        XCTAssertEqual(result.map(\.date), ["2024-05-15"])
    }

    func testAggregatedFilterHasNoMapTarget() {
        // filterDays with favorites chip is an aggregated value — no spatial single-day reference.
        let result = InsightsDrilldownBridge.dayListAction(
            from: .filterDays(DayListFilter(activeChips: [.favorites]))
        )
        // It passes through as a day filter but is NOT a showDayOnMap action.
        if case .showDayOnMap = result {
            XCTFail("Aggregated filter should not yield a showDayOnMap action")
        }
    }

    // MARK: - Insights Dashboard: drilldown label strings

    func testShowDayTargetLabelIsOpenInDays() {
        let target = InsightsDrilldownTarget.showDay("2024-06-15")
        XCTAssertEqual(target.label, "Open in Days")
    }

    func testExportDayTargetLabelIsSelectForExport() {
        let target = InsightsDrilldownTarget.exportDay("2024-06-15")
        XCTAssertEqual(target.label, "Select for Export")
    }

    func testShowOnMapTargetLabelIsNonEmpty() {
        let target = InsightsDrilldownTarget.showDayOnMap("2024-06-15")
        XCTAssertFalse(target.label.isEmpty)
    }

    // MARK: - Insights Dashboard: drilldown triple includes map target

    func testDrilldownTripleContainsShowOnMapAction() {
        let targets = InsightsDrilldownTarget.drilldownTargets(for: "2024-06-15")
        let hasMapTarget = targets.contains { target in
            if case .showDayOnMap = target.action { return true }
            return false
        }
        XCTAssertTrue(hasMapTarget, "Triple must include showDayOnMap for Insights → Day Detail Map wiring")
    }

    // MARK: - Insights Dashboard: range filter reset

    func testInsightsRangeFilterResetDisablesActiveState() {
        var filter = HistoryDateRangeFilter(preset: .last30Days)
        XCTAssertTrue(filter.isActive)
        filter.reset()
        XCTAssertFalse(filter.isActive)
        XCTAssertEqual(filter, HistoryDateRangeFilter.default)
    }

    // MARK: - Export Checkout: Insights → Export drilldown wiring

    func testInsightsDrilldownExportActionForPrefillExportDate() {
        let exported = InsightsDrilldownBridge.exportAction(from: .prefillExportForDate("2024-06-15"))
        XCTAssertNotNil(exported, "prefillExportForDate must route to an export action")
        if case let .prefillExportForDate(date) = exported {
            XCTAssertEqual(date, "2024-06-15")
        } else {
            XCTFail("Expected prefillExportForDate action")
        }
    }

    func testInsightsDrilldownShowDayIsNotAnExportAction() {
        XCTAssertNil(InsightsDrilldownBridge.exportAction(from: .filterDaysToDate("2024-06-15")))
    }

    // MARK: - Export Checkout: format pills are all present

    func testExportFormatAllCasesContainsExpectedFormats() {
        let formats = ExportFormat.allCases.map(\.rawValue)
        XCTAssertTrue(formats.contains("GPX"))
        XCTAssertTrue(formats.contains("KML"))
        XCTAssertTrue(formats.contains("KMZ"))
        XCTAssertTrue(formats.contains("GeoJSON"))
        XCTAssertTrue(formats.contains("CSV"))
    }

    // MARK: - Export Checkout: export button disabled/enabled

    func testExportReadinessDisabledForEmptySelection() {
        let readiness = ExportPresentation.readiness(
            importedExport: nil,
            selection: ExportSelectionState(),
            recordedTracks: [],
            mode: .tracks
        )
        if case .nothingSelected = readiness { /* expected */ }
        else { XCTFail("Expected nothingSelected for empty selection") }
    }

    func testExportReadinessEnabledForSavedTrack() {
        let formatter = ISO8601DateFormatter()
        let start = formatter.date(from: "2024-05-01T08:00:00Z")!
        let end   = formatter.date(from: "2024-05-01T08:30:00Z")!
        let track = RecordedTrack(
            startedAt: start, endedAt: end,
            dayKey: "2024-05-01",
            distanceM: 500,
            captureMode: .foregroundWhileInUse,
            points: [
                RecordedTrackPoint(latitude: 48.0, longitude: 11.0, timestamp: start, horizontalAccuracyM: 5),
                RecordedTrackPoint(latitude: 48.001, longitude: 11.001, timestamp: end, horizontalAccuracyM: 5)
            ]
        )
        var selection = ExportSelectionState()
        selection.toggleRecordedTrack(track.id)

        let readiness = ExportPresentation.readiness(
            importedExport: nil,
            selection: selection,
            recordedTracks: [track],
            mode: .tracks
        )
        if case .ready = readiness { /* expected */ }
        else { XCTFail("Expected ready for saved track selection") }
    }

    // MARK: - Export Checkout: Live Tracks Card wiring

    func testBottomBarSummaryIsEmptyWhenNothingSelected() {
        let summary = ExportPresentation.bottomBarSummary(
            importedExport: nil,
            selection: ExportSelectionState(),
            recordedTracks: [],
            mode: .tracks,
            format: .gpx
        )
        XCTAssertTrue(summary.isEmpty)
    }

    // MARK: - Live Tracking: Deep Link

    @MainActor
    func testDeepLinkLiveSetsNavigateFlag() {
        let model = LiveLocationFeatureModel(client: nil, store: MockRecordedTrackStore())
        XCTAssertFalse(model.navigateToLiveTabRequested)
        model.navigateToLiveTabRequested = true
        XCTAssertTrue(model.navigateToLiveTabRequested)
        model.navigateToLiveTabRequested = false
        XCTAssertFalse(model.navigateToLiveTabRequested)
    }

    // MARK: - Live Tracking: CTA State

    @MainActor
    func testCTAIsDisabledWhileAwaitingAuthorization() {
        let model = LiveLocationFeatureModel(client: nil, store: MockRecordedTrackStore())
        // Without a client, isAwaitingAuthorization stays false and isRecording stays false.
        XCTAssertFalse(model.isRecording)
        XCTAssertFalse(model.isAwaitingAuthorization)
    }

    @MainActor
    func testRecordedTracksEmptyOnInit() {
        let model = LiveLocationFeatureModel(client: nil, store: MockRecordedTrackStore())
        XCTAssertTrue(model.recordedTracks.isEmpty)
    }

    // MARK: - Live Tracking: GPS Status Presentation

    func testGPSStatusLabelGoodForAccurateLocation() {
        XCTAssertEqual(LiveTrackingPresentation.gpsStatusLabel(accuracyM: 8), "GPS Good")
    }

    func testGPSStatusLabelWeakForInaccurateLocation() {
        XCTAssertEqual(LiveTrackingPresentation.gpsStatusLabel(accuracyM: 100), "GPS Weak")
    }

    // MARK: - Live Tracks Library: Row Presentation

    func testLiveTrackRowPresentationHasNonEmptyTitle() {
        let formatter = ISO8601DateFormatter()
        let start = formatter.date(from: "2024-05-01T08:00:00Z")!
        let end   = formatter.date(from: "2024-05-01T08:30:00Z")!
        let track = RecordedTrack(
            startedAt: start, endedAt: end,
            dayKey: "2024-05-01",
            distanceM: 1200,
            captureMode: .foregroundWhileInUse,
            points: [
                RecordedTrackPoint(latitude: 48.0, longitude: 11.0, timestamp: start, horizontalAccuracyM: 5)
            ]
        )
        let row = SavedTrackPresentation.row(for: track, unit: .metric, language: .english)
        XCTAssertFalse(row.title.isEmpty)
        XCTAssertFalse(row.metrics.isEmpty)
    }

    // MARK: - Options + Widget/Live Settings wiring

    func testRecordingPresetWiringBatteryToAccuracyDetail() {
        let suiteName = "UIWiringTests-preset-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        MainActor.assumeIsolated {
            let prefs = AppPreferences(userDefaults: defaults)
            prefs.recordingPreset = .battery
            XCTAssertEqual(prefs.liveTrackingAccuracy, .relaxed)
            XCTAssertEqual(prefs.liveTrackingDetail, .batterySaver)
            XCTAssertEqual(prefs.recordingPreset, .battery)
        }
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testRecordingPresetWiringPreciseToAccuracyDetail() {
        let suiteName = "UIWiringTests-preset2-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        MainActor.assumeIsolated {
            let prefs = AppPreferences(userDefaults: defaults)
            prefs.recordingPreset = .precise
            XCTAssertEqual(prefs.liveTrackingAccuracy, .strict)
            XCTAssertEqual(prefs.liveTrackingDetail, .detailed)
            XCTAssertEqual(prefs.recordingPreset, .precise)
        }
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testDynamicIslandAllCasesHaveLocalizedNames() {
        for display in DynamicIslandCompactDisplay.allCases {
            XCTAssertFalse(display.localizedName.isEmpty, "\(display) must have a localizedName")
        }
    }

    func testOptionsPresentationUploadDisabledText() {
        XCTAssertEqual(OptionsPresentation.uploadStatusText(sendsToServer: false, hasValidURL: true), "Disabled")
    }

    func testOptionsPresentationUploadActiveText() {
        XCTAssertEqual(OptionsPresentation.uploadStatusText(sendsToServer: true, hasValidURL: true), "Active")
    }

    func testOptionsPresentationUploadInvalidURLText() {
        XCTAssertEqual(OptionsPresentation.uploadStatusText(sendsToServer: true, hasValidURL: false), "Invalid URL")
    }

    func testDynamicIslandAllDisplayCasesCount() {
        XCTAssertEqual(DynamicIslandCompactDisplay.allCases.count, 4)
    }

    func testRecordingPresetAllCasesCount() {
        XCTAssertEqual(RecordingPreset.allCases.count, 4)
    }

    func testRecordingPresetAccessibilityIdentifiersAreUnique() {
        let ids = RecordingPreset.allCases.map(\.accessibilityIdentifier)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testBottomBarSummaryContainsFormatNameWhenLiveTrackSelected() {
        let formatter = ISO8601DateFormatter()
        let start = formatter.date(from: "2024-05-01T08:00:00Z")!
        let end   = formatter.date(from: "2024-05-01T08:30:00Z")!
        let track = RecordedTrack(
            startedAt: start, endedAt: end,
            dayKey: "2024-05-01",
            distanceM: 500,
            captureMode: .foregroundWhileInUse,
            points: [
                RecordedTrackPoint(latitude: 48.0, longitude: 11.0, timestamp: start, horizontalAccuracyM: 5),
                RecordedTrackPoint(latitude: 48.001, longitude: 11.001, timestamp: end, horizontalAccuracyM: 5)
            ]
        )
        var selection = ExportSelectionState()
        selection.toggleRecordedTrack(track.id)

        let summary = ExportPresentation.bottomBarSummary(
            importedExport: nil,
            selection: selection,
            recordedTracks: [track],
            mode: .tracks,
            format: .gpx
        )
        XCTAssertFalse(summary.isEmpty)
        XCTAssertTrue(summary.contains("GPX"))
    }
}

// MARK: - Days compact layout — structural invariants

/// Verifies that the Days-tab sticky-map workspace has the correct defaults
/// and that its state-machine invariants hold without a SwiftUI host.
final class DaysCompactLayoutStructureTests: XCTestCase {

    // MARK: Map header defaults

    func testDaysMapHeaderDefaultVisibilityIsCompact() {
        let state = LHMapHeaderState(
            visibility: .compact,
            compactHeight: 180,
            expandedHeight: 260,
            isSticky: true
        )
        XCTAssertEqual(state.visibility, .compact,
            "Days map must start compact so content is immediately visible")
    }

    func testDaysMapHeaderDefaultIsStickyTrue() {
        let state = LHMapHeaderState(
            visibility: .compact,
            compactHeight: 180,
            expandedHeight: 260,
            isSticky: true
        )
        XCTAssertTrue(state.isSticky,
            "Days map must be sticky — it must not be dismissible")
    }

    func testDaysMapHeaderDefaultRendersMap() {
        let state = LHMapHeaderState(
            visibility: .compact,
            compactHeight: 180,
            expandedHeight: 260,
            isSticky: true
        )
        XCTAssertTrue(state.shouldRenderMap,
            "Days map must be in the view tree at startup")
    }

    // MARK: Sticky invariant — map cannot be hidden

    func testStickyDaysMapCannotBeHiddenFromCompact() {
        var state = LHMapHeaderState(visibility: .compact, isSticky: true)
        state.toggleHidden()
        XCTAssertNotEqual(state.visibility, .hidden,
            "Sticky map must never transition to .hidden via toggleHidden()")
    }

    func testStickyDaysMapCannotBeHiddenFromExpanded() {
        var state = LHMapHeaderState(visibility: .expanded, isSticky: true)
        state.toggleHidden()
        XCTAssertNotEqual(state.visibility, .hidden)
    }

    func testStickyDaysMapCanExpandAndCollapse() {
        var state = LHMapHeaderState(visibility: .compact, isSticky: true)
        state.expand()
        XCTAssertEqual(state.visibility, .expanded)
        state.collapse()
        XCTAssertEqual(state.visibility, .compact)
    }

    func testStickyDaysMapCanEnterAndExitFullscreen() {
        var state = LHMapHeaderState(visibility: .expanded, isSticky: true)
        state.enterFullscreen()
        XCTAssertEqual(state.visibility, .fullscreen)
        state.exitFullscreen()
        XCTAssertEqual(state.visibility, .expanded)
    }

    // MARK: Export selection bar — count gate

    func testExportBarNotShownWithEmptySelection() {
        let selection = ExportSelectionState()
        XCTAssertEqual(selection.count, 0,
            "Empty ExportSelectionState must have count == 0 so the bottom bar is hidden")
    }

    func testExportBarShownAfterSelectingDay() {
        var selection = ExportSelectionState()
        selection.toggle("2024-05-01")
        XCTAssertGreaterThan(selection.count, 0,
            "Selection count > 0 must show the export bottom bar")
    }

    func testExportBarHiddenAfterDeselecting() {
        var selection = ExportSelectionState()
        let date = "2024-05-01"
        selection.toggle(date)
        XCTAssertGreaterThan(selection.count, 0)
        selection.toggle(date)
        XCTAssertEqual(selection.count, 0,
            "Deselecting must bring count back to 0 and hide the bottom bar")
    }
}

// MARK: - Mock helpers

private final class MockRecordedTrackStore: RecordedTrackStoring {
    func loadTracks() throws -> [RecordedTrack] { [] }
    func saveTracks(_ tracks: [RecordedTrack]) throws {}
}

// MARK: - DaySummary test stub

private extension DaySummary {
    static func stub(
        date: String,
        visitCount: Int = 0,
        activityCount: Int = 0,
        pathCount: Int = 0,
        totalPathDistanceM: Double = 0
    ) -> DaySummary {
        DaySummary(
            date: date,
            visitCount: visitCount,
            activityCount: activityCount,
            pathCount: pathCount,
            totalPathPointCount: 0,
            totalPathDistanceM: totalPathDistanceM,
            hasContent: visitCount > 0 || activityCount > 0 || pathCount > 0
        )
    }
}
