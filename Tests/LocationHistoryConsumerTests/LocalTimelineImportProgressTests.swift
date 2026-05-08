import Foundation
import XCTest
@testable import LocationHistoryConsumerAppSupport

final class LocalTimelineImportProgressTests: XCTestCase {

    func testInitialProgressIsIdleAndNotCancellable() {
        let p = LocalTimelineImportProgress.initial()
        XCTAssertEqual(p.phase, .idle)
        XCTAssertEqual(p.entriesProcessed, 0)
        XCTAssertEqual(p.visitsWritten, 0)
        XCTAssertEqual(p.activitiesWritten, 0)
        XCTAssertEqual(p.pathsWritten, 0)
        XCTAssertEqual(p.skippedEntries, 0)
        XCTAssertNil(p.bytesRead)
        XCTAssertNil(p.totalBytes)
        XCTAssertNil(p.currentDay)
        XCTAssertFalse(p.isCancellable)
    }

    func testTransitionToImportingMakesCancellable() {
        let p = LocalTimelineImportProgress.initial()
            .transitioned(to: .importing)
        XCTAssertEqual(p.phase, .importing)
        XCTAssertTrue(p.isCancellable)
    }

    func testTerminalPhasesClearCancellable() {
        for terminal in [LocalTimelineImportProgress.Phase.completed,
                         .cancelled, .failed] {
            let p = LocalTimelineImportProgress.initial()
                .transitioned(to: .importing)
                .transitioned(to: terminal)
            XCTAssertEqual(p.phase, terminal)
            XCTAssertFalse(p.isCancellable, "\(terminal) must clear cancellable")
        }
    }

    func testThrottleEmitsOnPhaseChangeImmediately() {
        let throttle = LocalTimelineImportProgressThrottle(entryStride: 500)
        let prev = LocalTimelineImportProgress.initial().transitioned(to: .preparing)
        let next = prev.transitioned(to: .importing)
        XCTAssertTrue(throttle.shouldEmit(previous: prev, current: next))
    }

    func testThrottleSuppressesUntilStrideReached() {
        let throttle = LocalTimelineImportProgressThrottle(entryStride: 100)
        var prev = LocalTimelineImportProgress.initial().transitioned(to: .importing)
        var current = prev
        current.entriesProcessed = 50
        XCTAssertFalse(throttle.shouldEmit(previous: prev, current: current))
        current.entriesProcessed = 100
        XCTAssertTrue(throttle.shouldEmit(previous: prev, current: current))
        prev = current
        current.entriesProcessed = 150
        XCTAssertFalse(throttle.shouldEmit(previous: prev, current: current))
    }

    func testThrottleAlwaysEmitsTerminalPhase() {
        let throttle = LocalTimelineImportProgressThrottle(entryStride: 1_000_000)
        let prev = LocalTimelineImportProgress.initial().transitioned(to: .importing)
        let cancelled = prev.transitioned(to: .cancelled)
        XCTAssertTrue(throttle.shouldEmit(previous: prev, current: cancelled))
    }

    func testThrottleEmitsFirstSnapshot() {
        let throttle = LocalTimelineImportProgressThrottle()
        let initial = LocalTimelineImportProgress.initial()
        XCTAssertTrue(throttle.shouldEmit(previous: nil, current: initial))
    }
}
