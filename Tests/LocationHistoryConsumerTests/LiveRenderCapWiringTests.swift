import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Train H-Wire-1 (2026-05-16) wiring contract tests.
///
/// AppLiveTrackingView is a SwiftUI view and cannot be rendered on Linux —
/// these tests therefore only assert the *contract* that the wiring relies on:
/// the helper API exists with the expected shape, the localized hint string
/// is present in both English and German, and the cap default (10 000) leaves
/// realistic recordings unmodified while protecting overflow scenarios.
final class LiveRenderCapWiringTests: XCTestCase {

    private let en = AppLanguagePreference.english
    private let de = AppLanguagePreference.german
    private let hintEnglish = "Live route display optimized for performance. Full tracking data remains unchanged."
    private let hintGerman = "Live-Routenanzeige für Performance optimiert. Vollständige Trackingdaten bleiben unverändert."

    func testEnglishHintIsIdentity() {
        XCTAssertEqual(en.localized(hintEnglish), hintEnglish)
    }

    func testGermanHintIsTranslated() {
        XCTAssertEqual(de.localized(hintEnglish), hintGerman)
    }

    func testCapAtDefaultBudgetLeavesTypicalRecordingsUntouched() {
        let typical = makePoints(8_000) // typical long live session
        let result = LiveTrackRenderCap.apply(points: typical, cap: 10_000)
        XCTAssertFalse(result.wasCapped, "8 000 points must not be capped at the 10 000 budget")
        XCTAssertEqual(result.renderedCount, 8_000)
    }

    func testCapAtDefaultBudgetCapsExtremeRecordings() {
        let extreme = makePoints(25_000) // multi-day continuous recording
        let result = LiveTrackRenderCap.apply(points: extreme, cap: 10_000)
        XCTAssertTrue(result.wasCapped)
        XCTAssertLessThanOrEqual(result.renderedCount, 10_000)
        XCTAssertEqual(result.originalCount, 25_000)
        XCTAssertEqual(result.points.first, extreme.first, "Track start preserved")
        XCTAssertEqual(result.points.last, extreme.last, "Current position preserved")
    }

    func testCappedFlagDrivesHintDecision() {
        // When cap is below the input, the wiring should surface wasCapped=true,
        // which the view uses to show the hint. Verify that contract directly.
        let pts = makePoints(20_000)
        let capped = LiveTrackRenderCap.apply(points: pts, cap: 10_000)
        XCTAssertTrue(capped.wasCapped, "Hint must appear for 20 000-point session")
        let uncapped = LiveTrackRenderCap.apply(points: makePoints(2_000), cap: 10_000)
        XCTAssertFalse(uncapped.wasCapped, "Hint must NOT appear for typical session")
    }

    func testEmptyAndSinglePointDoNotTriggerHint() {
        XCTAssertFalse(LiveTrackRenderCap.apply(points: [], cap: 10_000).wasCapped)
        XCTAssertFalse(LiveTrackRenderCap.apply(points: makePoints(1), cap: 10_000).wasCapped)
    }

    // MARK: - Fixture

    private func makePoints(_ count: Int) -> [RecordedTrackPoint] {
        (0..<count).map { i in
            RecordedTrackPoint(
                latitude: 48.0 + Double(i) * 0.0001,
                longitude: 11.0 + Double(i) * 0.0001,
                timestamp: Date(timeIntervalSince1970: TimeInterval(i)),
                horizontalAccuracyM: 5.0
            )
        }
    }
}
