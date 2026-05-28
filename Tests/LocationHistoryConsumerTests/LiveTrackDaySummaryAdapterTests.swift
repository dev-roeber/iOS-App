import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class LiveTrackDaySummaryAdapterTests: XCTestCase {
    private func makeTrack(
        id: UUID = UUID(),
        dayKey: String = "2026-05-28",
        distanceM: Double = 1500,
        points: Int = 120
    ) -> RecordedTrack {
        let start = Date(timeIntervalSince1970: 1_716_840_000)
        let end = start.addingTimeInterval(Double(max(1, points)) * 5)
        let samplePoints: [RecordedTrackPoint] = (0..<points).map { i in
            RecordedTrackPoint(
                latitude: 52.5 + Double(i) * 0.0001,
                longitude: 13.4 + Double(i) * 0.0001,
                timestamp: start.addingTimeInterval(Double(i) * 5),
                horizontalAccuracyM: 5,
                speedMps: nil,
                courseDegrees: nil,
                altitudeM: nil,
                verticalAccuracyM: nil
            )
        }
        return RecordedTrack(
            id: id,
            startedAt: start,
            endedAt: end,
            dayKey: dayKey,
            distanceM: distanceM,
            captureMode: .balanced,
            points: samplePoints
        )
    }

    func testAdapterMapsCompletedTrackToDaySummary() {
        let track = makeTrack(dayKey: "2026-05-28", distanceM: 1234.5, points: 50)
        let summary = LiveTrackDaySummaryAdapter.daySummary(from: track)
        XCTAssertEqual(summary.date, "2026-05-28")
        XCTAssertEqual(summary.kind, .liveCompleted)
        XCTAssertEqual(summary.pathCount, 1)
        XCTAssertEqual(summary.totalPathPointCount, 50)
        XCTAssertEqual(summary.totalPathDistanceM, 1234.5, accuracy: 0.001)
        XCTAssertTrue(summary.hasContent)
        XCTAssertEqual(summary.exportablePathCount, 0)
        XCTAssertNotNil(summary.firstEntryStartTime)
        XCTAssertNotNil(summary.lastEntryEndTime)
    }

    func testAdapterMarksLiveNowAsLive() {
        let track = makeTrack(dayKey: "2026-05-28")
        let summary = LiveTrackDaySummaryAdapter.daySummary(from: track, isLiveNow: true)
        XCTAssertEqual(summary.kind, .live)
    }

    func testAdapterEmptyTrackHasNoContent() {
        let track = makeTrack(distanceM: 0, points: 0)
        let summary = LiveTrackDaySummaryAdapter.daySummary(from: track)
        XCTAssertFalse(summary.hasContent)
        XCTAssertEqual(summary.totalPathPointCount, 0)
    }

    func testAdapterNegativeDistanceClampedToZero() {
        let track = makeTrack(distanceM: -42, points: 10)
        let summary = LiveTrackDaySummaryAdapter.daySummary(from: track)
        XCTAssertEqual(summary.totalPathDistanceM, 0)
    }

    func testBatchMapMarksActiveRecordingAsLive() {
        let activeID = UUID()
        let tracks = [
            makeTrack(id: UUID(), dayKey: "2026-05-26"),
            makeTrack(id: activeID, dayKey: "2026-05-28"),
            makeTrack(id: UUID(), dayKey: "2026-05-27")
        ]
        let summaries = LiveTrackDaySummaryAdapter.daySummaries(
            from: tracks,
            activeRecordingID: activeID
        )
        XCTAssertEqual(summaries.count, 3)
        XCTAssertEqual(summaries[0].kind, .liveCompleted)
        XCTAssertEqual(summaries[1].kind, .live)
        XCTAssertEqual(summaries[2].kind, .liveCompleted)
    }
}
