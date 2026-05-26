#if canImport(SwiftUI)
import XCTest
import SwiftUI
@testable import LocationHistoryConsumerAppSupport

/// Compile-and-instantiate smoke tests for `AppAcquiringLocationCard`.
///
/// The card is purely presentational, so these tests do not attempt to render
/// the SwiftUI view. They simply exercise the public initializer in the three
/// shapes the Live tab will use (no timer, timer only, timer + last accuracy)
/// and assert that the underlying helpers behave correctly.
@available(iOS 17.0, macOS 14.0, *)
final class AppAcquiringLocationCardTests: XCTestCase {

    func testInstantiatesWithoutElapsed() {
        let card = AppAcquiringLocationCard()
        XCTAssertNil(card.elapsed)
        XCTAssertNil(card.lastKnownAccuracyMeters)
        _ = card.body
    }

    func testInstantiatesWithElapsed() {
        let card = AppAcquiringLocationCard(elapsed: 30)
        XCTAssertEqual(card.elapsed ?? -1, 30, accuracy: 0.0001)
        XCTAssertNil(card.lastKnownAccuracyMeters)
        _ = card.body
    }

    func testInstantiatesWithLastKnownAccuracy() {
        let card = AppAcquiringLocationCard(elapsed: nil, lastKnownAccuracyMeters: 250)
        XCTAssertNil(card.elapsed)
        XCTAssertEqual(card.lastKnownAccuracyMeters ?? -1, 250, accuracy: 0.0001)
        _ = card.body
    }

    func testInstantiatesWithBothElapsedAndAccuracy() {
        let card = AppAcquiringLocationCard(elapsed: 95, lastKnownAccuracyMeters: 240)
        XCTAssertEqual(card.elapsed ?? -1, 95, accuracy: 0.0001)
        XCTAssertEqual(card.lastKnownAccuracyMeters ?? -1, 240, accuracy: 0.0001)
        _ = card.body
    }

    // MARK: - Helper

    func testFormatElapsedZero() {
        XCTAssertEqual(AppAcquiringLocationCard.formatElapsed(0), "0:00")
    }

    func testFormatElapsedSubMinute() {
        XCTAssertEqual(AppAcquiringLocationCard.formatElapsed(32), "0:32")
    }

    func testFormatElapsedMultiMinute() {
        XCTAssertEqual(AppAcquiringLocationCard.formatElapsed(125), "2:05")
    }

    func testFormatElapsedClampsNegativeToZero() {
        XCTAssertEqual(AppAcquiringLocationCard.formatElapsed(-5), "0:00")
    }
}
#endif
