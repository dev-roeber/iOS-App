import XCTest
@testable import LocationHistoryConsumerAppSupport

final class RecordedTrackEditorPresentationTests: XCTestCase {
    func testSummaryUsesReadableTimeRangeAndMetrics() {
        let draft = RecordedTrackEditorDraft(track: makeTrack())

        let presentation = RecordedTrackEditorPresentation.summary(
            draft: draft,
            unit: .metric
        )

        XCTAssertFalse(presentation.title.contains("2026-03-19"))
        XCTAssertTrue(presentation.title.contains("2026"))
        XCTAssertNotNil(presentation.timeRangeText)
        XCTAssertTrue(presentation.timeRangeText?.contains("–") == true)
        XCTAssertEqual(presentation.metrics.map { $0.text }, ["3 points", "1.3 km", "20 min"])
        XCTAssertNil(presentation.validationMessage)
    }

    func testFirstPointPresentationUsesStartRoleAndNextSegment() {
        let draft = RecordedTrackEditorDraft(track: makeTrack())

        let presentation = RecordedTrackEditorPresentation.point(
            at: 0,
            in: draft,
            unit: .metric
        )

        XCTAssertEqual(presentation.title, "Start Point")
        XCTAssertEqual(presentation.roleLabel, "Track begins here")
        XCTAssertFalse(presentation.timeText.contains("T07:15:00Z"))
        XCTAssertEqual(presentation.coordinateText, "48.00000, 11.00000")
        XCTAssertEqual(presentation.metrics.map { $0.id }, ["accuracy", "next-segment"])
        XCTAssertTrue(presentation.metrics[1].text.contains("to next"))
    }

    func testLastPointPresentationUsesEndRoleAndPreviousSegment() {
        let draft = RecordedTrackEditorDraft(track: makeTrack())

        let presentation = RecordedTrackEditorPresentation.point(
            at: 2,
            in: draft,
            unit: .metric
        )

        XCTAssertEqual(presentation.title, "End Point")
        XCTAssertEqual(presentation.roleLabel, "Track ends here")
        XCTAssertEqual(presentation.metrics.map { $0.id }, ["accuracy", "prev-segment"])
        XCTAssertTrue(presentation.metrics[1].text.contains("from previous"))
    }

    private func makeTrack() -> RecordedTrack {
        let formatter = ISO8601DateFormatter()
        let startedAt = formatter.date(from: "2026-03-19T07:15:00Z")!
        let mid = formatter.date(from: "2026-03-19T07:25:00Z")!
        let endedAt = formatter.date(from: "2026-03-19T07:35:00Z")!

        return RecordedTrack(
            startedAt: startedAt,
            endedAt: endedAt,
            dayKey: "2026-03-19",
            distanceM: 1600,
            captureMode: .foregroundWhileInUse,
            points: [
                RecordedTrackPoint(latitude: 48.0, longitude: 11.0, timestamp: startedAt, horizontalAccuracyM: 5),
                RecordedTrackPoint(latitude: 48.005, longitude: 11.005, timestamp: mid, horizontalAccuracyM: 6),
                RecordedTrackPoint(latitude: 48.010, longitude: 11.010, timestamp: endedAt, horizontalAccuracyM: 7),
            ]
        )
    }
}
