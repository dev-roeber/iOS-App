import XCTest
@testable import LocationHistoryConsumerAppSupport

@MainActor
final class LoadingProgressEngineTests: XCTestCase {
    func testInitialProgressIsZero() {
        let engine = LoadingProgressEngine()
        XCTAssertEqual(engine.progress, 0.0)
    }

    func testStartJumpsToBaseFloor() {
        let engine = LoadingProgressEngine()
        engine.start()
        XCTAssertGreaterThanOrEqual(engine.progress, 0.05)
        XCTAssertLessThan(engine.progress, 1.0)
        engine.cancel()
    }

    func testStartIsIdempotentAndKeepsValue() {
        let engine = LoadingProgressEngine()
        engine.start()
        let firstValue = engine.progress
        engine.start() // second call must not reset
        XCTAssertEqual(engine.progress, firstValue, accuracy: 0.0001)
        engine.cancel()
    }

    func testCompleteSnapsToOne() {
        let engine = LoadingProgressEngine()
        engine.start()
        engine.complete()
        XCTAssertEqual(engine.progress, 1.0)
    }

    func testCancelResetsToZero() {
        let engine = LoadingProgressEngine()
        engine.start()
        engine.cancel()
        XCTAssertEqual(engine.progress, 0.0)
    }

    func testResetBehavesLikeCancel() {
        let engine = LoadingProgressEngine()
        engine.start()
        engine.reset()
        XCTAssertEqual(engine.progress, 0.0)
    }

    func testCompleteIsIdempotent() {
        let engine = LoadingProgressEngine()
        engine.complete()
        engine.complete()
        XCTAssertEqual(engine.progress, 1.0)
    }

    func testCancelAfterCompleteResetsToZero() {
        let engine = LoadingProgressEngine()
        engine.complete()
        engine.cancel()
        XCTAssertEqual(engine.progress, 0.0)
    }

    /// The engine never publishes a value above the soft ceiling without an
    /// explicit `complete()` — even if many ticks occur. Asserts the eased
    /// curve stays below 1.0 during normal driving.
    func testTimerDrivenProgressNeverExceedsCeilingWithoutComplete() async {
        let engine = LoadingProgressEngine()
        engine.start()
        // Wait long enough for many ticks to fire.
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        XCTAssertLessThan(engine.progress, 0.95)
        XCTAssertGreaterThan(engine.progress, 0.05)
        engine.cancel()
    }
}
