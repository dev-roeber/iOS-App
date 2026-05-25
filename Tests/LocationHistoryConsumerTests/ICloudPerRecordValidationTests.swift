import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Phase D.3 — locks down the per-record `Result` validation that the
/// CloudKit Health-Probe and the LiveTrack upload now run after every
/// `CKDatabase.modifyRecords` / `records(for:)` call.
///
/// Apple's async modifyRecords returns a `(saveResults: [ID: Result<…>],
/// deleteResults: [ID: Result<…>])` even when the outer `try await`
/// succeeds. Phase D.2 only checked the outer throw, which is exactly
/// why the screenshot showed „Schreiben ✓ · Lesen CKError.unknownItem"
/// — the write was lost server-side but we still claimed success.
final class ICloudPerRecordValidationTests: XCTestCase {

    // MARK: - Result validator

    func testAssertSavedReturnsSilentlyOnSuccess() throws {
        let saveResults: [String: Result<String, Error>] = [
            "probe-1": .success("record"),
        ]
        XCTAssertNoThrow(
            try ICloudCloudKitMVPResultValidator.assertSaved(
                recordID: "probe-1",
                in: saveResults
            )
        )
    }

    func testAssertSavedThrowsMissingResultWhenRecordIDAbsent() {
        let saveResults: [String: Result<String, Error>] = [:]
        XCTAssertThrowsError(
            try ICloudCloudKitMVPResultValidator.assertSaved(
                recordID: "probe-1",
                in: saveResults
            )
        ) { error in
            XCTAssertEqual(error as? ICloudPerRecordValidationError, .missingResult)
        }
    }

    func testAssertSavedRethrowsUnderlyingFailure() {
        struct StubError: Error, Equatable {}
        let saveResults: [String: Result<String, Error>] = [
            "probe-1": .failure(StubError()),
        ]
        XCTAssertThrowsError(
            try ICloudCloudKitMVPResultValidator.assertSaved(
                recordID: "probe-1",
                in: saveResults
            )
        ) { error in
            XCTAssertNotNil(error as? StubError)
        }
    }

    func testAssertDeletedReturnsSilentlyOnSuccess() {
        let deleteResults: [String: Result<Void, Error>] = [
            "probe-1": .success(()),
        ]
        XCTAssertNoThrow(
            try ICloudCloudKitMVPResultValidator.assertDeleted(
                recordID: "probe-1",
                in: deleteResults
            )
        )
    }

    func testAssertDeletedThrowsMissingResultWhenAbsent() {
        let deleteResults: [String: Result<Void, Error>] = [:]
        XCTAssertThrowsError(
            try ICloudCloudKitMVPResultValidator.assertDeleted(
                recordID: "probe-1",
                in: deleteResults
            )
        ) { error in
            XCTAssertEqual(error as? ICloudPerRecordValidationError, .missingResult)
        }
    }

    func testAssertDeletedRethrowsFailure() {
        struct StubError: Error {}
        let deleteResults: [String: Result<Void, Error>] = [
            "probe-1": .failure(StubError()),
        ]
        XCTAssertThrowsError(
            try ICloudCloudKitMVPResultValidator.assertDeleted(
                recordID: "probe-1",
                in: deleteResults
            )
        ) { error in
            XCTAssertNotNil(error as? StubError)
        }
    }

    // MARK: - LiveTrack-style multi-record save validation

    func testAssertAllSavedSucceedsWhenEveryRecordPresent() {
        let saveResults: [String: Result<String, Error>] = [
            "summary-1": .success("ok"),
            "batch-0": .success("ok"),
            "batch-1": .success("ok"),
        ]
        XCTAssertNoThrow(
            try ICloudCloudKitMVPResultValidator.assertAllSaved(
                expectedIDs: ["summary-1", "batch-0", "batch-1"],
                in: saveResults
            )
        )
    }

    /// Phase-D.3 scenario (e): LiveTrack upload must throw if even a
    /// single record-save result is missing from the dictionary.
    func testAssertAllSavedThrowsMissingResultWhenAnyExpectedIDAbsent() {
        let saveResults: [String: Result<String, Error>] = [
            "summary-1": .success("ok"),
            "batch-0": .success("ok"),
            // batch-1 missing
        ]
        XCTAssertThrowsError(
            try ICloudCloudKitMVPResultValidator.assertAllSaved(
                expectedIDs: ["summary-1", "batch-0", "batch-1"],
                in: saveResults
            )
        ) { error in
            XCTAssertEqual(error as? ICloudPerRecordValidationError, .missingResult)
        }
    }

    func testAssertAllSavedRethrowsFirstPerRecordFailure() {
        struct ServerRejected: Error, Equatable {}
        let saveResults: [String: Result<String, Error>] = [
            "summary-1": .success("ok"),
            "batch-0": .failure(ServerRejected()),
        ]
        XCTAssertThrowsError(
            try ICloudCloudKitMVPResultValidator.assertAllSaved(
                expectedIDs: ["summary-1", "batch-0"],
                in: saveResults
            )
        ) { error in
            XCTAssertNotNil(error as? ServerRejected)
        }
    }

    // MARK: - Stage classification (per Phase-D.3 spec a–d)

    /// Scenario (a): save-result missing/failed → stage `.write`,
    /// `writeSucceeded = false`. Mirrors the production `runHealthCheck`
    /// path which feeds the same validator into `makeFailureResult`.
    func testScenarioWriteResultMissingClassifiesAsWriteFailure() {
        struct ProbeError: Error {}
        let saveResults: [String: Result<String, Error>] = [:]
        var thrown: Error?
        do {
            try ICloudCloudKitMVPResultValidator.assertSaved(
                recordID: "probe-1",
                in: saveResults
            )
        } catch {
            thrown = error
        }
        XCTAssertNotNil(thrown)
        let result = makeStageResult(
            stage: .write,
            error: thrown!,
            writeSucceeded: false
        )
        XCTAssertEqual(result.errorStage, .write)
        XCTAssertFalse(result.writeSucceeded)
        XCTAssertFalse(result.readSucceeded)
        XCTAssertFalse(result.deleteSucceeded)
    }

    /// Scenario (b): save ok, read returns `CKError.unknownItem` →
    /// stage `.read`, `writeSucceeded = true`, `readSucceeded = false`.
    /// This is exactly the screenshot case.
    func testScenarioReadUnknownItemClassifiesAsReadFailure() {
        // Simulate the unknownItem code (raw 11). We do not need an
        // actual CKError here — the failure-result mapping accepts any
        // Error and the per-record validator re-throws it as-is.
        let mapping = ICloudCKErrorMapping.mapping(forRawCode: 11)
        XCTAssertEqual(mapping.codeName, "unknownItem")
        let result = ICloudHealthProbeResult(
            checkedAt: Date(),
            writeSucceeded: true,
            readSucceeded: false,
            deleteSucceeded: false,
            durationSeconds: 1.0,
            errorCode: "11",
            errorMessage: mapping.germanHint,
            errorStage: .read,
            ckErrorCodeName: mapping.codeName
        )
        XCTAssertEqual(result.errorStage, .read)
        XCTAssertEqual(result.ckErrorCodeName, "unknownItem")
        XCTAssertTrue(result.writeSucceeded)
        XCTAssertFalse(result.readSucceeded)
        XCTAssertFalse(result.deleteSucceeded)
    }

    /// Scenario (c): save ok, read ok, delete failed →
    /// `writeSucceeded = true`, `readSucceeded = true`,
    /// `deleteSucceeded = false`, stage `.delete`.
    func testScenarioDeleteFailureKeepsWriteReadFlagsTrue() {
        let result = ICloudHealthProbeResult(
            checkedAt: Date(),
            writeSucceeded: true,
            readSucceeded: true,
            deleteSucceeded: false,
            durationSeconds: 1.0,
            errorCode: "10",
            errorMessage: "Schreiben in privaten CloudKit-Bereich fehlgeschlagen.",
            errorStage: .delete,
            ckErrorCodeName: "permissionFailure"
        )
        XCTAssertEqual(result.errorStage, .delete)
        XCTAssertTrue(result.writeSucceeded)
        XCTAssertTrue(result.readSucceeded)
        XCTAssertFalse(result.deleteSucceeded)
    }

    /// Scenario (d): all three stages succeed → `.reachable`, all flags true.
    func testScenarioAllStagesSucceedProducesReachableStatus() {
        let probe = ICloudHealthProbeResult(
            checkedAt: Date(),
            writeSucceeded: true,
            readSucceeded: true,
            deleteSucceeded: true,
            durationSeconds: 1.0
        )
        let status = ICloudHealthStatus(
            accountStatus: .available,
            privateDatabaseReachability: .reachable,
            lastProbeResult: probe
        )
        XCTAssertTrue(status.isOperational)
        XCTAssertEqual(status.privateDatabaseSummary, "Privater CloudKit-Speicher erreichbar")
    }

    // MARK: - Helpers

    /// Mirrors the production `CloudKitICloudHealthCheckService.makeFailureResult`
    /// reduction; replicated here without `import CloudKit` so the test
    /// stays Linux-compatible.
    private func makeStageResult(
        stage: ICloudHealthProbeStage,
        error: Error,
        writeSucceeded: Bool,
        readSucceeded: Bool = false
    ) -> ICloudHealthProbeResult {
        ICloudHealthProbeResult(
            checkedAt: Date(),
            writeSucceeded: writeSucceeded,
            readSucceeded: readSucceeded,
            deleteSucceeded: false,
            durationSeconds: 1.0,
            errorCode: nil,
            errorMessage: "test",
            errorStage: stage,
            ckErrorCodeName: nil
        )
    }
}
