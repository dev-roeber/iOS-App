import Foundation
import XCTest
@testable import LocationHistoryConsumerAppSupport

final class LocalTimelineImportCancellationTests: XCTestCase {

    func testDefaultIsNotCancelled() {
        let token = LocalTimelineImportCancellation()
        XCTAssertFalse(token.isCancelled)
        XCTAssertNoThrow(try token.checkCancellation())
    }

    func testCancelMarksToken() {
        let token = LocalTimelineImportCancellation()
        token.cancel()
        XCTAssertTrue(token.isCancelled)
    }

    func testCheckCancellationThrowsAfterCancel() {
        let token = LocalTimelineImportCancellation()
        token.cancel()
        XCTAssertThrowsError(try token.checkCancellation()) { err in
            XCTAssertEqual(err as? LocalTimelineImportCancellationError, .cancelled)
        }
    }

    func testCancelIsIdempotent() {
        let token = LocalTimelineImportCancellation()
        token.cancel()
        token.cancel()
        token.cancel()
        XCTAssertTrue(token.isCancelled)
        XCTAssertThrowsError(try token.checkCancellation())
    }

    func testCancelIsThreadSafe() {
        let token = LocalTimelineImportCancellation()
        let queue = DispatchQueue(label: "cancel.race", attributes: .concurrent)
        let group = DispatchGroup()
        for _ in 0..<200 {
            group.enter()
            queue.async {
                token.cancel()
                _ = token.isCancelled
                group.leave()
            }
        }
        group.wait()
        XCTAssertTrue(token.isCancelled)
    }
}
