import XCTest
@testable import LocationHistoryConsumerAppSupport

final class SavedTracksPresentationTests: XCTestCase {
    func testUsesSavedTracksForLibraryAccess() {
        XCTAssertEqual(SavedTracksPresentation.libraryTitle, "Saved Tracks")
        XCTAssertEqual(SavedTracksPresentation.libraryButtonTitle, "View Library")
        XCTAssertEqual(SavedTracksPresentation.editorTitle, "Edit Track")
    }

    func testOverviewMessagesDifferentiateEmptyAndPopulatedLibrary() {
        let emptyMessage = SavedTracksPresentation.overviewMessage(hasTracks: false)
        let populatedMessage = SavedTracksPresentation.overviewMessage(hasTracks: true)

        XCTAssertTrue(emptyMessage.contains("Saved Tracks"))
        XCTAssertTrue(emptyMessage.contains("separate from imported history"))
        XCTAssertTrue(populatedMessage.contains("Saved Tracks library"))
        XCTAssertTrue(populatedMessage.contains("point editing"))
    }

    func testLiveAndUnavailableMessagesStayAlignedToLibraryNaming() {
        XCTAssertTrue(SavedTracksPresentation.liveEmptyMessage.contains("Saved Tracks library"))
        XCTAssertTrue(SavedTracksPresentation.liveListMessage.contains("edit points directly"))
        XCTAssertEqual(SavedTracksPresentation.unavailableTitle, "Saved Tracks Unavailable")
        XCTAssertTrue(SavedTracksPresentation.unavailableMessage.contains("track library"))
    }

    func testRowPresentationUsesReadableTimeRangeAndMetrics() {
        let presentation = SavedTrackPresentation.row(
            for: makeTrack(
                start: "2026-03-19T07:15:00Z",
                end: "2026-03-19T07:47:00Z",
                distanceM: 29500,
                pointCount: 14
            ),
            unit: .metric
        )

        XCTAssertFalse(presentation.title.contains("T07:15:00Z"))
        XCTAssertNotNil(presentation.timeRangeText)
        XCTAssertFalse(presentation.timeRangeText?.contains("T07:15:00Z") == true)
        XCTAssertTrue(presentation.timeRangeText?.contains("–") == true)
        XCTAssertEqual(presentation.metrics.map { $0.text }, ["29.5 km", "32 min", "14 points"])
        XCTAssertTrue(presentation.accessibilityLabel.contains("29.5 km distance"))
    }

    func testRowPresentationOmitsDistanceWhenTrackHasNoUsableDistance() {
        let presentation = SavedTrackPresentation.row(
            for: makeTrack(
                start: "2026-03-19T12:00:00Z",
                end: "2026-03-19T12:12:00Z",
                distanceM: 0,
                pointCount: 2
            ),
            unit: .metric
        )

        XCTAssertEqual(presentation.metrics.map { $0.id }, ["duration", "points"])
        XCTAssertEqual(presentation.metrics.map { $0.text }, ["12 min", "2 points"])
    }

    private func makeTrack(
        start: String,
        end: String,
        distanceM: Double,
        pointCount: Int
    ) -> RecordedTrack {
        let formatter = ISO8601DateFormatter()
        let startedAt = formatter.date(from: start)!
        let endedAt = formatter.date(from: end)!
        let points = (0..<pointCount).map { index in
            RecordedTrackPoint(
                latitude: 48.0 + Double(index) * 0.001,
                longitude: 11.0 + Double(index) * 0.001,
                timestamp: startedAt.addingTimeInterval(Double(index) * 60),
                horizontalAccuracyM: 5
            )
        }
        return RecordedTrack(
            startedAt: startedAt,
            endedAt: endedAt,
            dayKey: "2026-03-19",
            distanceM: distanceM,
            captureMode: .foregroundWhileInUse,
            points: points
        )
    }
}
