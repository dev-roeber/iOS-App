import XCTest
import LocationHistoryConsumerAppSupport

final class RecordedTrackEditorDraftTests: XCTestCase {
    func testInsertMidpointAddsInterpolatedPointBetweenNeighbors() {
        var draft = RecordedTrackEditorDraft(track: makeTrack())

        draft.insertMidpoint(after: 0)

        XCTAssertEqual(draft.points.count, 3)
        XCTAssertEqual(draft.points[1].latitude, 52.52015, accuracy: 0.000001)
        XCTAssertEqual(draft.points[1].longitude, 13.40015, accuracy: 0.000001)
        XCTAssertEqual(draft.points[1].timestamp, Date(timeIntervalSince1970: 1_710_000_010))
    }

    func testDeletePointBelowMinimumMakesDraftInvalid() {
        var draft = RecordedTrackEditorDraft(track: makeTrack())

        draft.deletePoints(at: IndexSet(integer: 0))

        XCTAssertEqual(draft.points.count, 1)
        XCTAssertEqual(draft.validationMessage, "A saved track needs at least 2 points.")
        XCTAssertNil(draft.savedTrack)
    }

    func testSavedTrackRecomputesDistanceAndPreservesIdentity() throws {
        var draft = RecordedTrackEditorDraft(track: makeTrack())

        draft.updateCoordinate(at: 1, latitude: 52.5210, longitude: 13.4010)
        let savedTrack = try XCTUnwrap(draft.savedTrack)

        XCTAssertEqual(savedTrack.id, makeTrack().id)
        XCTAssertTrue(savedTrack.distanceM > makeTrack().distanceM)
        XCTAssertEqual(savedTrack.points[1].latitude, 52.5210, accuracy: 0.000001)
        XCTAssertEqual(savedTrack.points[1].longitude, 13.4010, accuracy: 0.000001)
    }

    func testResetRestoresOriginalPoints() {
        let track = makeTrack()
        var draft = RecordedTrackEditorDraft(track: track)

        draft.updateCoordinate(at: 0, latitude: 51.0)
        XCTAssertTrue(draft.isModified)

        draft.reset()

        XCTAssertEqual(draft.points, track.points)
        XCTAssertFalse(draft.isModified)
    }

    private func makeTrack() -> RecordedTrack {
        let start = Date(timeIntervalSince1970: 1_710_000_000)
        let end = start.addingTimeInterval(20)
        return RecordedTrack(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE") ?? UUID(),
            startedAt: start,
            endedAt: end,
            dayKey: "2024-03-09",
            distanceM: 42,
            captureMode: .foregroundWhileInUse,
            points: [
                RecordedTrackPoint(
                    latitude: 52.52,
                    longitude: 13.40,
                    timestamp: start,
                    horizontalAccuracyM: 5
                ),
                RecordedTrackPoint(
                    latitude: 52.5203,
                    longitude: 13.4003,
                    timestamp: end,
                    horizontalAccuracyM: 5
                ),
            ]
        )
    }
}
