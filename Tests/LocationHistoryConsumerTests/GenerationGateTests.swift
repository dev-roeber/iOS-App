import XCTest
@testable import LocationHistoryConsumerAppSupport

final class GenerationGateTests: XCTestCase {
    func testStartingTokenIsZeroByDefault() {
        let gate = GenerationGate()
        XCTAssertEqual(gate.current, 0)
        XCTAssertTrue(gate.isStillCurrent(0))
    }

    func testStartingTokenIsConfigurable() {
        let gate = GenerationGate(startingAt: 42)
        XCTAssertEqual(gate.current, 42)
        XCTAssertTrue(gate.isStillCurrent(42))
        XCTAssertFalse(gate.isStillCurrent(0))
    }

    func testBumpAdvancesCurrentAndReturnsNew() {
        var gate = GenerationGate()
        let next = gate.bump()
        XCTAssertEqual(next, 1)
        XCTAssertEqual(gate.current, 1)
    }

    func testStaleTokenIsNotCurrentAfterBump() {
        var gate = GenerationGate()
        let captured = gate.current
        gate.bump()
        XCTAssertFalse(gate.isStillCurrent(captured),
                       "Token captured before bump must be stale")
    }

    func testFreshTokenStaysCurrentUntilNextBump() {
        var gate = GenerationGate()
        let captured = gate.bump()
        XCTAssertTrue(gate.isStillCurrent(captured))
        gate.bump()
        XCTAssertFalse(gate.isStillCurrent(captured))
    }

    func testMultipleBumpsAreMonotonic() {
        var gate = GenerationGate()
        var prev: UInt64 = gate.current
        for _ in 0..<256 {
            let next = gate.bump()
            XCTAssertGreaterThan(next, prev)
            prev = next
        }
    }

    func testBumpWrapsAroundWithoutTrap() {
        var gate = GenerationGate(startingAt: UInt64.max - 1)
        XCTAssertEqual(gate.bump(), UInt64.max)
        XCTAssertEqual(gate.bump(), 0,
                       "Wraparound must not trap — &+= is intentional")
        XCTAssertTrue(gate.isStillCurrent(0))
    }

    func testSimulatedRaceOnlyLatestTokenWins() {
        var gate = GenerationGate()
        let workA = gate.bump()
        let workB = gate.bump()
        // Stale completion arrives first.
        XCTAssertFalse(gate.isStillCurrent(workA))
        // Fresh completion still wins.
        XCTAssertTrue(gate.isStillCurrent(workB))
    }
}
