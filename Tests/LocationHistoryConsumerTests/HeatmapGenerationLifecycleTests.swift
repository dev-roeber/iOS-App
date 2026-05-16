import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Train L, Phase 1 — documents the race-gate lifecycle that
/// `AppHeatmapModel` relies on, by exercising `GenerationGate` in the
/// exact sequences the heatmap pipeline can produce (`startPrecomputation`,
/// `updateScale`, `ensureDensityPrecomputation`, plus an A→B→A region
/// flip). The MainActor wiring itself is Apple-only and untestable on
/// Linux; this suite stands in as deterministic, time-free coverage of
/// the policy under those exact sequences.
final class HeatmapGenerationLifecycleTests: XCTestCase {

    // MARK: - Single-pipeline staleness

    func testFreshPrecomputationTokenIsCurrent() {
        var gate = GenerationGate()
        let token = gate.bump()
        XCTAssertTrue(gate.isStillCurrent(token),
                      "First bump captures the latest token; no other bump has happened.")
    }

    func testStalePrecomputationCompletionIsIgnored() {
        var gate = GenerationGate()
        let staleToken = gate.bump()       // startPrecomputation T1
        gate.bump()                         // updateScale supersedes T1
        XCTAssertFalse(gate.isStillCurrent(staleToken),
                       "A completion arriving for T1 after a scale switch must be rejected.")
    }

    func testNewestCompletionStillWinsAfterStaleBypass() {
        var gate = GenerationGate()
        _ = gate.bump()
        let fresh = gate.bump()
        XCTAssertTrue(gate.isStillCurrent(fresh))
    }

    // MARK: - A → B → A flip (rapid region/scale toggles)

    func testRapidABAFlipDoesNotReviveStaleATokenA() {
        var gate = GenerationGate()
        let firstA = gate.bump()
        _ = gate.bump()                     // B request
        let secondA = gate.bump()           // A again
        XCTAssertFalse(gate.isStillCurrent(firstA),
                       "The first A's completion must not commit, even though the latest user-intent is also A.")
        XCTAssertTrue(gate.isStillCurrent(secondA),
                      "Only the most recent A bump's token may commit.")
    }

    func testABFlipBothEarlierAreStale() {
        var gate = GenerationGate()
        let a = gate.bump()
        let b = gate.bump()
        gate.bump()
        XCTAssertFalse(gate.isStillCurrent(a))
        XCTAssertFalse(gate.isStillCurrent(b))
    }

    // MARK: - Update-scale invalidation pattern

    /// Models `AppHeatmapModel.updateScale`: it bumps the gate even if no
    /// inflight task exists, so any cached completion path is invalidated.
    func testUpdateScaleAlwaysInvalidatesPriorToken() {
        var gate = GenerationGate()
        let priorToken = gate.bump()
        // updateScale: cancel inflight task, bump gate.
        gate.bump()
        XCTAssertFalse(gate.isStillCurrent(priorToken))
    }

    // MARK: - ensureDensityPrecomputation guard pattern

    /// Models `ensureDensityPrecomputation`: it bumps once per call. If the
    /// task is already running, the early `guard densityPrecomputationTask == nil`
    /// path skips the bump entirely — verifies that pattern by NOT bumping.
    func testEnsureDensityPrecomputationEarlyReturnLeavesTokenStable() {
        var gate = GenerationGate()
        let token = gate.bump()                  // first call enters and bumps
        // second call's `guard densityPrecomputationTask == nil` returns early
        // → no bump → token still current
        XCTAssertTrue(gate.isStillCurrent(token))
    }

    // MARK: - Long-running sequence stability

    func testMonotonicGateNeverReissuesAStaleToken() {
        var gate = GenerationGate()
        var seenTokens: Set<UInt64> = []
        for _ in 0..<32 {
            let t = gate.bump()
            XCTAssertFalse(seenTokens.contains(t),
                           "Gate must not reissue any earlier token within practical range.")
            seenTokens.insert(t)
        }
    }
}
