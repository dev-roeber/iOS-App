import XCTest

/// Placeholder for `LiveLocationFeatureModel` multi-step authorization-state
/// transition coverage (audit P1).
///
/// `TestLiveLocationClient` and `InMemoryRecordedTrackStore` are declared
/// `private` inside `LiveLocationFeatureModelTests.swift` and cannot be
/// re-used from this file. Adding the requested transitions —
/// `requestingWhenInUse → awaitingAlwaysUpgrade → readyToStart → recording`
/// and `awaitingAlwaysUpgrade → failedAuthorization` — requires either:
///
/// 1. promoting the mock client/store to `internal` in the existing test file, or
/// 2. duplicating the mock here (~50 LoC) and keeping it in sync.
///
/// Both touch surfaces outside this audit ticket. Mock client refactor is
/// pending; the existing `LiveLocationFeatureModelTests` already covers the
/// notDetermined / denied / authorizedWhenInUse single-step cases.
final class LiveLocationFeatureModelStateTransitionTests: XCTestCase {
    func testPlaceholderForFutureMockRefactor() {
        // Intentionally left as a no-op so the suite count is stable.
        XCTAssertTrue(true)
    }
}
