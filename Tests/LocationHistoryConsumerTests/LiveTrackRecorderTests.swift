import XCTest
@testable import LocationHistoryConsumerAppSupport

final class LiveTrackRecorderTests: XCTestCase {
    func testRecorderStartsEmpty() {
        let recorder = LiveTrackRecorder()
        XCTAssertTrue(recorder.points.isEmpty)
        XCTAssertFalse(recorder.isRecording)
    }

    func testFirstAccuratePointIsAccepted() {
        var recorder = LiveTrackRecorder()
        recorder.start()

        let didAccept = recorder.append(sample(offsetSeconds: 0, latitude: 52.52, longitude: 13.40, accuracy: 8))

        XCTAssertTrue(didAccept)
        XCTAssertEqual(recorder.points.count, 1)
    }

    func testDuplicatePointIsRejected() {
        var recorder = LiveTrackRecorder()
        recorder.start()
        XCTAssertTrue(recorder.append(sample(offsetSeconds: 0, latitude: 52.52, longitude: 13.40, accuracy: 5)))

        let didAccept = recorder.append(sample(offsetSeconds: 12, latitude: 52.52, longitude: 13.40, accuracy: 5))

        XCTAssertFalse(didAccept)
        XCTAssertEqual(recorder.points.count, 1)
    }

    func testPoorAccuracyIsRejected() {
        var recorder = LiveTrackRecorder()
        recorder.start()

        let didAccept = recorder.append(sample(offsetSeconds: 0, latitude: 52.52, longitude: 13.40, accuracy: 150))

        XCTAssertFalse(didAccept)
        XCTAssertTrue(recorder.points.isEmpty)
    }

    func testStopClearsDraftAndRequiresNewStart() {
        var recorder = LiveTrackRecorder()
        recorder.start()
        XCTAssertTrue(recorder.append(sample(offsetSeconds: 0, latitude: 52.52, longitude: 13.40, accuracy: 5)))
        XCTAssertTrue(recorder.append(sample(offsetSeconds: 12, latitude: 52.5202, longitude: 13.4002, accuracy: 5)))

        let track = recorder.stop()
        let didAcceptAfterStop = recorder.append(sample(offsetSeconds: 24, latitude: 52.5204, longitude: 13.4004, accuracy: 5))

        XCTAssertNotNil(track)
        XCTAssertFalse(recorder.isRecording)
        XCTAssertTrue(recorder.points.isEmpty)
        XCTAssertFalse(didAcceptAfterStop)
    }

    func testMinimumRecordingIntervalGate_rejectsEarlyPoint() {
        var config = LiveTrackRecorderConfiguration()
        config.minimumRecordingIntervalS = 30
        var recorder = LiveTrackRecorder(configuration: config)
        recorder.start()
        XCTAssertTrue(recorder.append(sample(offsetSeconds: 0, latitude: 52.52, longitude: 13.40, accuracy: 5)))

        // Only 10 s later – below the 30 s interval floor
        let didAccept = recorder.append(sample(offsetSeconds: 10, latitude: 52.5210, longitude: 13.4015, accuracy: 5))

        XCTAssertFalse(didAccept)
        XCTAssertEqual(recorder.points.count, 1)
    }

    func testMinimumRecordingIntervalGate_acceptsPointAfterInterval() {
        var config = LiveTrackRecorderConfiguration()
        config.minimumRecordingIntervalS = 30
        var recorder = LiveTrackRecorder(configuration: config)
        recorder.start()
        XCTAssertTrue(recorder.append(sample(offsetSeconds: 0, latitude: 52.52, longitude: 13.40, accuracy: 5)))

        // 35 s later – above the 30 s floor
        let didAccept = recorder.append(sample(offsetSeconds: 35, latitude: 52.5210, longitude: 13.4015, accuracy: 5))

        XCTAssertTrue(didAccept)
        XCTAssertEqual(recorder.points.count, 2)
    }

    // MARK: - Quality gate + recording interval interaction

    /// When the user sets a short recording interval (e.g. 1 s), a point that arrives after that
    /// interval must NOT be blocked by minimumTimeDeltaS (8 s from the Detail setting), even when
    /// the distance moved is below minimumDistanceDeltaM. Without the fix, setting 1 s would have
    /// no effect: the quality gate's 8 s threshold would silently reject every point.
    func testShortRecordingInterval_overridesQualityTimeGate() {
        var config = LiveTrackRecorderConfiguration(
            minimumDistanceDeltaM: 15,
            minimumTimeDeltaS: 8         // default from Detail setting
        )
        config.minimumRecordingIntervalS = 1   // user chose 1 s
        var recorder = LiveTrackRecorder(configuration: config)
        recorder.start()
        XCTAssertTrue(recorder.append(sample(offsetSeconds: 0, latitude: 52.52, longitude: 13.40, accuracy: 5)))

        // 1 s later, small movement (~13 m: above duplicate threshold 3 m, below minimumDistanceDeltaM 15 m)
        // — quality gate alone would reject (timeDelta 1 s < 8 s), but recording interval has been
        // satisfied so the point must be accepted.
        let didAccept = recorder.append(sample(offsetSeconds: 1, latitude: 52.5201, longitude: 13.4001, accuracy: 5))

        XCTAssertTrue(didAccept, "Point should be accepted: recording interval (1 s) satisfied and overrides quality time gate (8 s)")
        XCTAssertEqual(recorder.points.count, 2)
    }

    /// Without a user-configured interval (minimumRecordingIntervalS == 0), the quality gate's
    /// minimumTimeDeltaS must still apply — no regression.
    func testNoRecordingInterval_qualityGateStillApplies() {
        let config = LiveTrackRecorderConfiguration(
            minimumDistanceDeltaM: 15,
            minimumTimeDeltaS: 8
        )   // minimumRecordingIntervalS defaults to 0
        var recorder = LiveTrackRecorder(configuration: config)
        recorder.start()
        XCTAssertTrue(recorder.append(sample(offsetSeconds: 0, latitude: 52.52, longitude: 13.40, accuracy: 5)))

        // 1 s later, small movement (~13 m) — quality gate (8 s) must still block this.
        let didAccept = recorder.append(sample(offsetSeconds: 1, latitude: 52.5201, longitude: 13.4001, accuracy: 5))

        XCTAssertFalse(didAccept, "Point should be rejected: quality gate (8 s) applies when no recording interval is set")
    }

    func testZeroRecordingInterval_doesNotGate() {
        var config = LiveTrackRecorderConfiguration()
        config.minimumRecordingIntervalS = 0
        var recorder = LiveTrackRecorder(configuration: config)
        recorder.start()
        XCTAssertTrue(recorder.append(sample(offsetSeconds: 0, latitude: 52.52, longitude: 13.40, accuracy: 5)))

        // Only 1 s later but large movement – should pass when no interval gate active
        let didAccept = recorder.append(sample(offsetSeconds: 1, latitude: 52.5250, longitude: 13.4060, accuracy: 5))

        XCTAssertTrue(didAccept)
    }

    // MARK: - Auto-split (maximumGapSeconds)

    func testAutoSplit_producesSplitOffTrack() {
        var config = LiveTrackRecorderConfiguration()
        config.maximumGapSeconds = 60
        var recorder = LiveTrackRecorder(configuration: config)
        recorder.start()
        XCTAssertTrue(recorder.append(sample(offsetSeconds: 0, latitude: 52.52, longitude: 13.40, accuracy: 5)))
        XCTAssertTrue(recorder.append(sample(offsetSeconds: 12, latitude: 52.5203, longitude: 13.4003, accuracy: 5)))

        // 200 s gap → exceeds maximumGapSeconds → split
        let didAccept = recorder.append(sample(offsetSeconds: 212, latitude: 52.5210, longitude: 13.4010, accuracy: 5))

        XCTAssertTrue(didAccept)
        XCTAssertNotNil(recorder.splitOffTrack, "splitOffTrack must be set after gap exceeds maximumGapSeconds")
        XCTAssertEqual(recorder.splitOffTrack?.points.count, 2)
        XCTAssertEqual(recorder.points.count, 1)
    }

    func testAutoSplit_startDoesNotClearPendingSplitOffTrack() {
        // Regression test: start() must NOT clear splitOffTrack.
        // The auto-split path calls stop() → assigns splitOffTrack → calls start().
        // If start() cleared splitOffTrack the caller would never see the split.
        var config = LiveTrackRecorderConfiguration()
        config.maximumGapSeconds = 60
        var recorder = LiveTrackRecorder(configuration: config)
        recorder.start()
        XCTAssertTrue(recorder.append(sample(offsetSeconds: 0, latitude: 52.52, longitude: 13.40, accuracy: 5)))
        XCTAssertTrue(recorder.append(sample(offsetSeconds: 12, latitude: 52.5203, longitude: 13.4003, accuracy: 5)))
        _ = recorder.append(sample(offsetSeconds: 212, latitude: 52.5210, longitude: 13.4010, accuracy: 5))

        XCTAssertNotNil(recorder.splitOffTrack, "start() must not clear splitOffTrack")
    }

    func testTakeSplitOffTrack_returnsOnceAndClears() {
        var config = LiveTrackRecorderConfiguration()
        config.maximumGapSeconds = 60
        var recorder = LiveTrackRecorder(configuration: config)
        recorder.start()
        XCTAssertTrue(recorder.append(sample(offsetSeconds: 0, latitude: 52.52, longitude: 13.40, accuracy: 5)))
        XCTAssertTrue(recorder.append(sample(offsetSeconds: 12, latitude: 52.5203, longitude: 13.4003, accuracy: 5)))
        _ = recorder.append(sample(offsetSeconds: 212, latitude: 52.5210, longitude: 13.4010, accuracy: 5))

        let first = recorder.takeSplitOffTrack()
        let second = recorder.takeSplitOffTrack()

        XCTAssertNotNil(first)
        XCTAssertNil(second, "takeSplitOffTrack() must return nil on second call")
    }

    func testAutoSplit_newSegmentAcceptsSubsequentPoints() {
        var config = LiveTrackRecorderConfiguration()
        config.maximumGapSeconds = 60
        var recorder = LiveTrackRecorder(configuration: config)
        recorder.start()
        XCTAssertTrue(recorder.append(sample(offsetSeconds: 0, latitude: 52.52, longitude: 13.40, accuracy: 5)))
        XCTAssertTrue(recorder.append(sample(offsetSeconds: 12, latitude: 52.5203, longitude: 13.4003, accuracy: 5)))
        _ = recorder.append(sample(offsetSeconds: 212, latitude: 52.5210, longitude: 13.4010, accuracy: 5)) // split

        // Point in the new segment — should be accepted
        let didAccept = recorder.append(sample(offsetSeconds: 240, latitude: 52.5220, longitude: 13.4020, accuracy: 5))

        XCTAssertTrue(didAccept)
        XCTAssertEqual(recorder.points.count, 2)
    }

    private func sample(offsetSeconds: TimeInterval, latitude: Double, longitude: Double, accuracy: Double) -> LiveLocationSample {
        LiveLocationSample(
            latitude: latitude,
            longitude: longitude,
            timestamp: Date(timeIntervalSince1970: 1_710_000_000 + offsetSeconds),
            horizontalAccuracyM: accuracy
        )
    }
}
