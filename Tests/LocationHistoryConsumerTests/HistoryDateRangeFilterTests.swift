import XCTest
@testable import LocationHistoryConsumerAppSupport

final class HistoryDateRangeFilterTests: XCTestCase {

    // MARK: - isActive

    func testAllPresetIsNotActive() {
        let filter = HistoryDateRangeFilter(preset: .all)
        XCTAssertFalse(filter.isActive)
    }

    func testNonAllPresetsAreActive() {
        for preset in HistoryDateRangePreset.allCases where preset != .all {
            let filter = HistoryDateRangeFilter(preset: preset)
            XCTAssertTrue(filter.isActive, "Expected preset \(preset.rawValue) to be active")
        }
    }

    // MARK: - effectiveRange

    func testAllPresetReturnsNilRange() {
        let filter = HistoryDateRangeFilter(preset: .all)
        XCTAssertNil(filter.effectiveRange)
    }

    func testLast7DaysReturnsSevenDayRange() {
        let filter = HistoryDateRangeFilter(preset: .last7Days)
        guard let range = filter.effectiveRange else {
            return XCTFail("Expected a range for last7Days")
        }
        let days = Calendar.current.dateComponents([.day], from: range.lowerBound, to: range.upperBound).day ?? 0
        XCTAssertEqual(days, 6)
    }

    func testLast30DaysRangeSpans29Days() {
        let filter = HistoryDateRangeFilter(preset: .last30Days)
        guard let range = filter.effectiveRange else { return XCTFail("No range") }
        let days = Calendar.current.dateComponents([.day], from: range.lowerBound, to: range.upperBound).day ?? 0
        XCTAssertEqual(days, 29)
    }

    func testCustomPresetWithoutDatesReturnsNilRange() {
        let filter = HistoryDateRangeFilter(preset: .custom)
        XCTAssertNil(filter.effectiveRange)
    }

    func testCustomPresetWithValidDatesReturnsRange() {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -10, to: Date())!
        let end = Date()
        let filter = HistoryDateRangeFilter(preset: .custom, customStart: start, customEnd: end)
        XCTAssertNotNil(filter.effectiveRange)
    }

    func testCustomPresetStartAfterEndReturnsNilRange() {
        let end = Date()
        let start = end.addingTimeInterval(1000)
        let filter = HistoryDateRangeFilter(preset: .custom, customStart: start, customEnd: end)
        XCTAssertNil(filter.effectiveRange)
    }

    // MARK: - reset

    func testResetRestoresDefaults() {
        var filter = HistoryDateRangeFilter(preset: .last30Days, customStart: Date(), customEnd: Date())
        filter.reset()
        XCTAssertEqual(filter.preset, .all)
        XCTAssertNil(filter.customStart)
        XCTAssertNil(filter.customEnd)
        XCTAssertFalse(filter.isActive)
    }

    // MARK: - Validator

    func testValidatorAllowsValidRange() {
        let start = Date().addingTimeInterval(-86400)
        let end = Date()
        XCTAssertEqual(HistoryDateRangeValidator.validate(start: start, end: end), .valid)
    }

    func testValidatorRejectsStartAfterEnd() {
        let start = Date()
        let end = start.addingTimeInterval(-1)
        XCTAssertEqual(HistoryDateRangeValidator.validate(start: start, end: end), .startAfterEnd)
    }

    func testValidatorRejectsTooFarInPast() {
        let start = Calendar.current.date(byAdding: .year, value: -11, to: Date())!
        let end = Date()
        XCTAssertEqual(HistoryDateRangeValidator.validate(start: start, end: end), .startTooFarInPast)
    }

    // MARK: - Presets

    func testAllPresetsHaveNonEmptyTitles() {
        for preset in HistoryDateRangePreset.allCases {
            XCTAssertFalse(preset.title.isEmpty, "Preset \(preset.rawValue) has empty title")
            XCTAssertFalse(preset.shortLabel.isEmpty, "Preset \(preset.rawValue) has empty shortLabel")
        }
    }

    func testFromAndToDateStringsMatchRange() {
        let filter = HistoryDateRangeFilter(preset: .last7Days)
        XCTAssertNotNil(filter.fromDateString)
        XCTAssertNotNil(filter.toDateString)
    }

    func testAllPresetProducesNilDateStrings() {
        let filter = HistoryDateRangeFilter(preset: .all)
        XCTAssertNil(filter.fromDateString)
        XCTAssertNil(filter.toDateString)
    }

    // MARK: - Chip order (All Time must be last)

    func testChipOrderFirstPresetIsLast7Days() {
        XCTAssertEqual(HistoryDateRangePreset.allCases.first, .last7Days,
                       "The first chip must be Last 7 Days, not All Time")
    }

    func testChipOrderLastPresetIsAllTime() {
        XCTAssertEqual(HistoryDateRangePreset.allCases.last, .all,
                       "All Time must be the rightmost chip")
    }

    func testChipOrderCustomIsBeforeAllTime() {
        let cases = HistoryDateRangePreset.allCases
        guard let customIdx = cases.firstIndex(of: .custom),
              let allIdx = cases.firstIndex(of: .all) else {
            return XCTFail("Expected both .custom and .all in allCases")
        }
        XCTAssertLessThan(customIdx, allIdx, "Custom must appear before All Time")
    }

    // MARK: - App default

    func testAppSessionStateDefaultIsLast7Days() {
        let state = AppSessionState()
        XCTAssertEqual(state.historyDateRangeFilter.preset, .last7Days,
                       "Fresh AppSessionState must default to Last 7 Days")
    }
}
