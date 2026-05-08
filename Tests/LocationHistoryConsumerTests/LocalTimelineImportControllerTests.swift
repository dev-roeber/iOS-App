import Foundation
import XCTest
@testable import LocationHistoryConsumerAppSupport

final class LocalTimelineImportControllerTests: XCTestCase {

    func testProgressSinkUpdatesLatestProgress() {
        let controller = LocalTimelineImportController()
        XCTAssertNil(controller.latestProgress)

        let sink = controller.progressSink
        let snap = LocalTimelineImportProgress.initial().transitioned(to: .importing)
        sink(snap)

        XCTAssertEqual(controller.latestProgress?.phase, .importing)
        XCTAssertTrue(controller.latestProgress?.isCancellable ?? false)
    }

    func testCancelForwardsToSharedToken() {
        let controller = LocalTimelineImportController()
        XCTAssertFalse(controller.isCancelled)
        controller.cancel()
        XCTAssertTrue(controller.isCancelled)
        XCTAssertTrue(controller.cancellation.isCancelled)
    }

    func testObserverReceivesSnapshots() {
        let controller = LocalTimelineImportController()
        let received = NSMutableArray()
        let lock = NSLock()
        let handle = controller.addObserver { snap in
            lock.lock()
            received.add(snap.phase.rawValue)
            lock.unlock()
        }
        defer { handle.remove() }

        let sink = controller.progressSink
        sink(LocalTimelineImportProgress.initial().transitioned(to: .preparing))
        sink(LocalTimelineImportProgress.initial().transitioned(to: .completed))

        XCTAssertEqual(received.count, 2)
        XCTAssertEqual(received[0] as? String, "preparing")
        XCTAssertEqual(received[1] as? String, "completed")
    }

    func testRemovedObserverDoesNotReceiveFurtherSnapshots() {
        let controller = LocalTimelineImportController()
        let counter = NSMutableArray()
        let lock = NSLock()
        let handle = controller.addObserver { _ in
            lock.lock(); counter.add(1); lock.unlock()
        }
        let sink = controller.progressSink
        sink(LocalTimelineImportProgress.initial().transitioned(to: .preparing))
        handle.remove()
        sink(LocalTimelineImportProgress.initial().transitioned(to: .completed))
        XCTAssertEqual(counter.count, 1)
    }
}
