import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-10A P1-A/B (Weg 2) — Tests für die Foundation-only
/// Presentation-Schicht von `LocalTimelineImportProgress`.
final class LocalTimelineImportProgressPresentationTests: XCTestCase {

    // MARK: - Helpers

    private func snapshot(
        phase: LocalTimelineImportProgress.Phase = .importing,
        bytesRead: Int64? = nil,
        totalBytes: Int64? = nil,
        entriesProcessed: Int = 0,
        visitsWritten: Int = 0,
        activitiesWritten: Int = 0,
        pathsWritten: Int = 0,
        skippedEntries: Int = 0,
        currentDay: String? = nil
    ) -> LocalTimelineImportProgress {
        LocalTimelineImportProgress.initial()
            .transitioned(to: phase)
            .with(
                bytesRead: bytesRead,
                totalBytes: totalBytes,
                entriesProcessed: entriesProcessed,
                visitsWritten: visitsWritten,
                activitiesWritten: activitiesWritten,
                pathsWritten: pathsWritten,
                skippedEntries: skippedEntries,
                currentDay: currentDay
            )
    }

    // MARK: - Tests

    func testIdleConstantIsIdlePhaseAndNotCancellable() {
        let p = LocalTimelineImportProgressPresentation.idle
        XCTAssertEqual(p.phase, .idle)
        XCTAssertFalse(p.isCancellable)
    }

    func testStatusTextCoversAllPhases() {
        let phases: [LocalTimelineImportProgress.Phase] = [
            .idle, .preparing, .sniffing, .importing,
            .finalizing, .completed, .cancelled, .failed
        ]
        for phase in phases {
            let snap = LocalTimelineImportProgress.initial().transitioned(to: phase)
            let p = LocalTimelineImportProgressPresentation(progress: snap)
            XCTAssertFalse(p.statusText.isEmpty, "statusText must be non-empty for \(phase)")
            XCTAssertEqual(p.phaseLabel, phase.rawValue, "phaseLabel must match rawValue for \(phase)")
        }
    }

    func testCountsTextFormatsThousandsSeparator() {
        let snap = snapshot(phase: .importing, entriesProcessed: 12_345)
        let p = LocalTimelineImportProgressPresentation(progress: snap)
        XCTAssertTrue(
            p.countsText.contains("Entries 12,345"),
            "expected countsText to contain 'Entries 12,345', got \(p.countsText)"
        )
    }

    func testSkippedTextNilWhenZeroAndPresentWhenPositive() {
        let zero = snapshot(phase: .importing, skippedEntries: 0)
        let pZero = LocalTimelineImportProgressPresentation(progress: zero)
        XCTAssertNil(pZero.skippedText)

        let positive = snapshot(phase: .importing, skippedEntries: 7)
        let pPositive = LocalTimelineImportProgressPresentation(progress: positive)
        XCTAssertEqual(pPositive.skippedText, "Skipped 7")
    }

    func testPercentTextOnlyWhenTotalAndReadValid() {
        // valid 10/100 → "10%"
        let valid = snapshot(phase: .importing, bytesRead: 10, totalBytes: 100)
        let pValid = LocalTimelineImportProgressPresentation(progress: valid)
        XCTAssertEqual(pValid.percentText, "10%")
        XCTAssertNotNil(pValid.bytesText)

        // both nil → both nil
        let nilSnap = snapshot(phase: .importing, bytesRead: nil, totalBytes: nil)
        let pNil = LocalTimelineImportProgressPresentation(progress: nilSnap)
        XCTAssertNil(pNil.percentText)
        XCTAssertNil(pNil.bytesText)

        // read>total → both nil
        let overflow = snapshot(phase: .importing, bytesRead: 200, totalBytes: 100)
        let pOver = LocalTimelineImportProgressPresentation(progress: overflow)
        XCTAssertNil(pOver.percentText)
        XCTAssertNil(pOver.bytesText)

        // total=0 → both nil
        let zero = snapshot(phase: .importing, bytesRead: 0, totalBytes: 0)
        let pZero = LocalTimelineImportProgressPresentation(progress: zero)
        XCTAssertNil(pZero.percentText)
        XCTAssertNil(pZero.bytesText)
    }

    func testCurrentDayOnlyForISODate() {
        let iso = snapshot(phase: .importing, currentDay: "2024-07-12")
        XCTAssertEqual(
            LocalTimelineImportProgressPresentation(progress: iso).currentDayText,
            "Day 2024-07-12"
        )

        let notDate = snapshot(phase: .importing, currentDay: "not a date")
        XCTAssertNil(
            LocalTimelineImportProgressPresentation(progress: notDate).currentDayText
        )

        let pathLike = snapshot(phase: .importing, currentDay: "/etc/passwd")
        XCTAssertNil(
            LocalTimelineImportProgressPresentation(progress: pathLike).currentDayText
        )
    }

    func testNoSensitiveDataInOneLineSummary() {
        let snap = snapshot(
            phase: .importing,
            bytesRead: 10,
            totalBytes: 100,
            entriesProcessed: 5,
            currentDay: "/var/secret/path"
        )
        let p = LocalTimelineImportProgressPresentation(progress: snap)
        let banned = ["/var", "secret", "path"]
        for needle in banned {
            XCTAssertFalse(
                p.oneLineSummary.contains(needle),
                "oneLineSummary leaked '\(needle)': \(p.oneLineSummary)"
            )
            XCTAssertFalse(
                p.statusText.contains(needle),
                "statusText leaked '\(needle)': \(p.statusText)"
            )
            XCTAssertFalse(
                p.countsText.contains(needle),
                "countsText leaked '\(needle)': \(p.countsText)"
            )
            if let bytes = p.bytesText {
                XCTAssertFalse(
                    bytes.contains(needle),
                    "bytesText leaked '\(needle)': \(bytes)"
                )
            }
        }
        // Sanity: invalid currentDay must not have produced a currentDayText.
        XCTAssertNil(p.currentDayText)
    }

    func testTerminalPhasesAreNotCancellableInPresentation() {
        for phase in [LocalTimelineImportProgress.Phase.completed, .cancelled, .failed] {
            let snap = LocalTimelineImportProgress.initial().transitioned(to: phase)
            let p = LocalTimelineImportProgressPresentation(progress: snap)
            XCTAssertFalse(p.isCancellable, "phase \(phase) must not be cancellable")
        }
    }
}

// MARK: - Local mutation helper

private extension LocalTimelineImportProgress {
    /// Convenience for tests: returns a copy with selected counter/byte
    /// fields overridden. Phase + isCancellable bleiben unverändert.
    func with(
        bytesRead: Int64? = nil,
        totalBytes: Int64? = nil,
        entriesProcessed: Int = 0,
        visitsWritten: Int = 0,
        activitiesWritten: Int = 0,
        pathsWritten: Int = 0,
        skippedEntries: Int = 0,
        currentDay: String? = nil
    ) -> LocalTimelineImportProgress {
        var copy = self
        copy.bytesRead = bytesRead
        copy.totalBytes = totalBytes
        copy.entriesProcessed = entriesProcessed
        copy.visitsWritten = visitsWritten
        copy.activitiesWritten = activitiesWritten
        copy.pathsWritten = pathsWritten
        copy.skippedEntries = skippedEntries
        copy.currentDay = currentDay
        return copy
    }
}
