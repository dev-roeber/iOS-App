import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-10A P1-A/B (Weg 2) — Tests für `LocalTimelineImportUIState`,
/// die UI-Bridge zwischen Controller und SwiftUI/AppShell.
@MainActor
final class LocalTimelineImportUIStateTests: XCTestCase {

    func testInitialStateHasNoSnapshotOrController() async {
        let state = LocalTimelineImportUIState()
        XCTAssertNil(state.snapshot)
        XCTAssertNil(state.controller)
        XCTAssertNil(state.presentation)
        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.hasObservedSnapshot)
    }

    func testStartNewImportInstallsControllerAndClearsSnapshot() async {
        let state = LocalTimelineImportUIState()
        // Pre-populate a stale snapshot via the test helper to ensure
        // startNewImport() clears it.
        state.acceptSnapshotForTesting(
            LocalTimelineImportProgress.initial().transitioned(to: .preparing)
        )
        XCTAssertNotNil(state.snapshot)

        let controller = state.startNewImport()
        XCTAssertNotNil(state.controller)
        XCTAssertTrue(state.controller === controller)
        XCTAssertNil(state.snapshot)
    }

    func testAcceptSnapshotForTestingPopulatesPresentation() async {
        let state = LocalTimelineImportUIState()

        // Active (non-terminal) phases.
        for phase in [LocalTimelineImportProgress.Phase.preparing, .sniffing, .importing, .finalizing] {
            let snap = LocalTimelineImportProgress.initial().transitioned(to: phase)
            state.acceptSnapshotForTesting(snap)
            XCTAssertEqual(state.presentation?.phase, phase)
            XCTAssertTrue(state.hasObservedSnapshot)
            XCTAssertTrue(state.isActive, "phase \(phase) should be active")
        }

        // Terminal / idle phases.
        for phase in [LocalTimelineImportProgress.Phase.idle, .completed, .cancelled, .failed] {
            let snap = LocalTimelineImportProgress.initial().transitioned(to: phase)
            state.acceptSnapshotForTesting(snap)
            XCTAssertEqual(state.presentation?.phase, phase)
            XCTAssertTrue(state.hasObservedSnapshot)
            XCTAssertFalse(state.isActive, "phase \(phase) must not be active")
        }
    }

    func testStartNewImportTwiceReplacesController() async {
        let state = LocalTimelineImportUIState()
        let c1 = state.startNewImport()
        let id1 = ObjectIdentifier(c1)
        let c2 = state.startNewImport()
        let id2 = ObjectIdentifier(c2)

        XCTAssertNotEqual(id1, id2)
        guard let current = state.controller else {
            return XCTFail("controller must not be nil after second startNewImport")
        }
        XCTAssertEqual(ObjectIdentifier(current), id2)
        XCTAssertNotEqual(ObjectIdentifier(current), id1)
    }

    func testCancelDelegatesToController() async {
        let state = LocalTimelineImportUIState()
        let c = state.startNewImport()
        XCTAssertFalse(c.cancellation.isCancelled)
        state.cancel()
        XCTAssertTrue(c.cancellation.isCancelled)
    }

    func testResetClearsAll() async {
        let state = LocalTimelineImportUIState()
        _ = state.startNewImport()
        state.acceptSnapshotForTesting(
            LocalTimelineImportProgress.initial().transitioned(to: .importing)
        )
        XCTAssertNotNil(state.controller)
        XCTAssertNotNil(state.snapshot)

        state.reset()
        XCTAssertNil(state.controller)
        XCTAssertNil(state.snapshot)
        XCTAssertNil(state.presentation)
        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.hasObservedSnapshot)
    }

    func testProducerThreadObserverDeliversSnapshotToMain() async {
        let state = LocalTimelineImportUIState()
        let controller = state.startNewImport()
        let sink = controller.progressSink

        let producerSnap = LocalTimelineImportProgress.initial()
            .transitioned(to: .preparing)

        // Fire from a background queue — UIState observer hops to MainActor.
        let bg = DispatchQueue(label: "uistate.tests.bg")
        bg.async {
            sink(producerSnap)
        }

        // Poll on MainActor for up to 2s.
        let deadline = Date().addingTimeInterval(2.0)
        while Date() < deadline {
            if state.snapshot?.phase == .preparing { break }
            try? await Task.sleep(nanoseconds: 20_000_000) // 20 ms
        }

        XCTAssertEqual(state.snapshot?.phase, .preparing)
        XCTAssertTrue(state.hasObservedSnapshot)
        XCTAssertTrue(state.isActive)
    }
}
