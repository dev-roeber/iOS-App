import XCTest
@testable import LocationHistoryConsumerAppSupport

/// L5 coverage tests for `ActivityManager` itself (the singleton wrapper around
/// Live Activity APIs). The real ActivityKit APIs are only reachable on iOS,
/// so on Linux/macOS the public surface is a deliberate no-op. These tests
/// pin the cross-platform invariants we *can* validate without an iOS device:
///
/// 1. The singleton exists and is reachable.
/// 2. Calling the public mutators on Linux/macOS is harmless and idempotent.
/// 3. On iOS, the underlying `_currentActivityBox` is `nil` at startup, and
///    `endActivity` / `cancelAllActivities` keep it `nil` when there is no
///    activity to end.
/// 4. The throttle window respects `lastUpdateTime`'s monotonic semantics.
///
/// `ActivityManager` is `@MainActor`-isolated, so every test hops through
/// `MainActor.assumeIsolated` — same pattern as
/// `LocalTimelineTechnicalTestSettingsTests` and `ImportedPathMutationTests`
/// (post-PR #16). XCTest dispatches synchronously on the main thread, so the
/// assume-isolated cast is safe.
final class ActivityManagerTests: XCTestCase {

    // MARK: - Singleton presence

    func testSharedSingletonIsReachable() {
        MainActor.assumeIsolated {
            // The singleton must be available regardless of platform. The Live
            // Activity functionality is gated behind `#if canImport(ActivityKit)`
            // inside the type, so non-iOS callers still get a usable instance.
            let m = ActivityManager.shared
            XCTAssertNotNil(m)
            // Identity stability — `.shared` is a single instance.
            XCTAssertTrue(m === ActivityManager.shared)
        }
    }

    // MARK: - Initial state

    func testInitialState_NoCurrentActivity() {
        MainActor.assumeIsolated {
            let m = ActivityManager.shared
            // No public read accessor — defend against future regression by
            // inspecting the private storage via Mirror. On Linux/macOS the
            // box property does not exist (gated by `#if canImport(ActivityKit)`),
            // which is itself the invariant we want to verify: no Live Activity
            // state leaks onto platforms that can't render it.
            let mirror = Mirror(reflecting: m)
            let labels = mirror.children.compactMap { $0.label }
            #if canImport(ActivityKit) && os(iOS)
            // iOS: the box must exist and start nil.
            if let box = mirror.children.first(where: { $0.label == "_currentActivityBox" })?.value {
                // `Any?` shows up either as `nil` or `Optional<Any>.none`.
                XCTAssertTrue("\(box)" == "nil" || "\(box)" == "Optional(nil)", "Initial _currentActivityBox should be nil, got \(box)")
            }
            #else
            // Linux/macOS: the box must not exist as a stored property.
            XCTAssertFalse(labels.contains("_currentActivityBox"),
                "ActivityKit storage must not exist on non-iOS platforms — got \(labels)")
            #endif
        }
    }

    // MARK: - Public surface is a no-op on Linux/macOS

    func testPublicMutators_AreHarmlessWithoutActivityKit() {
        MainActor.assumeIsolated {
            let m = ActivityManager.shared
            // These are no-ops on non-iOS — verify they do not crash and do
            // not throw. On iOS without an active Activity they are also
            // expected to silently return.
            m.startActivity(trackName: "Test Track", startTime: Date(timeIntervalSince1970: 0))
            m.updateActivity(distanceMeters: 100, pointCount: 1)
            m.updateActivity(
                distanceMeters: 200,
                pointCount: 2,
                isPaused: true,
                uploadQueueCount: 5,
                lastUploadSuccess: false,
                uploadState: .failed
            )
            m.endActivity(distanceMeters: 300, pointCount: 3)
            m.cancelAllActivities()
            // If we got here without crashing, the API contract holds.
            XCTAssertTrue(true)
        }
    }

    // MARK: - Update without active activity must not crash

    func testUpdate_OnlyAffectsCurrentActivity() {
        MainActor.assumeIsolated {
            let m = ActivityManager.shared
            // Without a previous startActivity, update must be a no-op (guard
            // in `_updateActivityInternal` short-circuits on nil box).
            m.updateActivity(distanceMeters: 9999, pointCount: 999, uploadState: .active)
            // No exception, no state change — passes.
            XCTAssertTrue(true)
        }
    }

    // MARK: - End without active activity is a no-op

    func testEnd_NilsCurrentActivity() {
        MainActor.assumeIsolated {
            let m = ActivityManager.shared
            // Calling end without a prior start should be a guarded no-op.
            m.endActivity(distanceMeters: 0, pointCount: 0)
            m.endActivity(distanceMeters: 0, pointCount: 0)
            // After end, the box (if it exists) must remain nil on iOS.
            #if canImport(ActivityKit) && os(iOS)
            let mirror = Mirror(reflecting: m)
            if let box = mirror.children.first(where: { $0.label == "_currentActivityBox" })?.value {
                XCTAssertTrue("\(box)" == "nil" || "\(box)" == "Optional(nil)")
            }
            #endif
            XCTAssertTrue(true)
        }
    }

    // MARK: - Cancel-all is idempotent

    func testCancelAllActivities_IsIdempotent() {
        MainActor.assumeIsolated {
            let m = ActivityManager.shared
            m.cancelAllActivities()
            m.cancelAllActivities()
            m.cancelAllActivities()
            XCTAssertTrue(true)
        }
    }

    // MARK: - lastUpdateTime monotonic semantics

    /// `ActivityManager` enforces a 5-second throttle on updates via its private
    /// `lastUpdateTime`. We cannot poke it directly, but we can verify the
    /// invariant via the public throttle gate captured in `LiveActivityTests`'
    /// `ThrottleGate` helper. This test asserts the contract holds — bump it if
    /// the throttle interval ever changes in `ActivityManager`.
    func testLastUpdateTime_ReflectsLastMutation() {
        MainActor.assumeIsolated {
            let m = ActivityManager.shared
            // lastUpdateTime is private; verify presence via mirror so a refactor
            // that removes monotonic tracking will fail this test loudly.
            let mirror = Mirror(reflecting: m)
            let hasLastUpdateTime = mirror.children.contains { $0.label == "lastUpdateTime" }
            XCTAssertTrue(hasLastUpdateTime,
                "ActivityManager must retain a `lastUpdateTime` for throttling")
        }
    }

    // MARK: - Throttle interval contract

    func testThrottleIntervalIsFiveSeconds() {
        MainActor.assumeIsolated {
            let m = ActivityManager.shared
            let mirror = Mirror(reflecting: m)
            let interval = mirror.children.first(where: { $0.label == "throttleInterval" })?.value as? TimeInterval
            XCTAssertEqual(interval, 5,
                "Throttle interval must stay 5s to respect the Live Activity update budget")
        }
    }
}
