import XCTest
@testable import LocationHistoryConsumerAppSupport

#if canImport(CloudKit)
import CloudKit

final class CloudKitRetryPolicyTests: XCTestCase {

    // CKError.networkUnavailable (rawValue 3) — transient
    private func transientError() -> NSError {
        NSError(domain: CKErrorDomain, code: CKError.networkUnavailable.rawValue)
    }

    // CKError.permissionFailure (rawValue 10) — permanent
    private func permanentError() -> NSError {
        NSError(domain: CKErrorDomain, code: CKError.permissionFailure.rawValue)
    }

    func testSucceedsOnFirstAttempt() async throws {
        actor Counter { var n = 0; func inc() { n += 1 } }
        let counter = Counter()
        let value = try await CloudKitRetryPolicy.retry(maxAttempts: 3) {
            await counter.inc()
            return 42
        }
        let calls = await counter.n
        XCTAssertEqual(value, 42)
        XCTAssertEqual(calls, 1)
    }

    func testRetriesOnTransientErrorAndSucceeds() async throws {
        actor Counter { var n = 0; func inc() { n += 1 } }
        let counter = Counter()
        let transient = transientError()
        let value = try await CloudKitRetryPolicy.retry(maxAttempts: 3) {
            await counter.inc()
            let n = await counter.n
            if n < 2 { throw transient }
            return "ok"
        }
        let calls = await counter.n
        XCTAssertEqual(value, "ok")
        XCTAssertEqual(calls, 2)
    }

    func testDoesNotRetryOnPermanentError() async {
        actor Counter { var n = 0; func inc() { n += 1 } }
        let counter = Counter()
        let permanent = permanentError()
        do {
            _ = try await CloudKitRetryPolicy.retry(maxAttempts: 5) {
                await counter.inc()
                throw permanent
            }
            XCTFail("Expected throw")
        } catch {
            XCTAssertEqual((error as NSError).code, permanent.code)
        }
        let calls = await counter.n
        XCTAssertEqual(calls, 1, "permanent error must not be retried")
    }

    func testGivesUpAfterMaxAttempts() async {
        actor Counter { var n = 0; func inc() { n += 1 } }
        let counter = Counter()
        let transient = transientError()
        do {
            _ = try await CloudKitRetryPolicy.retry(maxAttempts: 3) {
                await counter.inc()
                throw transient
            }
            XCTFail("Expected throw after exhausting attempts")
        } catch {
            XCTAssertEqual((error as NSError).code, transient.code)
        }
        let calls = await counter.n
        XCTAssertEqual(calls, 3)
    }

    func testRespectsCKErrorRetryAfterKey() {
        let err = NSError(
            domain: CKErrorDomain,
            code: CKError.requestRateLimited.rawValue,
            userInfo: ["CKErrorRetryAfterKey": NSNumber(value: 2.5)]
        )
        XCTAssertEqual(CloudKitRetryPolicy.backoffSeconds(for: err, attempt: 1), 2.5)
    }

    func testExponentialBackoffWithoutRetryAfter() {
        let err = transientError()
        XCTAssertEqual(CloudKitRetryPolicy.backoffSeconds(for: err, attempt: 1), 1.0)
        XCTAssertEqual(CloudKitRetryPolicy.backoffSeconds(for: err, attempt: 2), 2.0)
        XCTAssertEqual(CloudKitRetryPolicy.backoffSeconds(for: err, attempt: 3), 4.0)
    }

    func testTransientClassification() {
        XCTAssertTrue(CloudKitRetryPolicy.isTransient(transientError()))
        XCTAssertTrue(CloudKitRetryPolicy.isTransient(
            NSError(domain: CKErrorDomain, code: CKError.networkFailure.rawValue)
        ))
        XCTAssertTrue(CloudKitRetryPolicy.isTransient(
            NSError(domain: CKErrorDomain, code: CKError.requestRateLimited.rawValue)
        ))
        XCTAssertTrue(CloudKitRetryPolicy.isTransient(
            NSError(domain: CKErrorDomain, code: CKError.serverResponseLost.rawValue)
        ))
        XCTAssertTrue(CloudKitRetryPolicy.isTransient(
            NSError(domain: CKErrorDomain, code: CKError.zoneBusy.rawValue)
        ))
        XCTAssertTrue(CloudKitRetryPolicy.isTransient(
            NSError(domain: CKErrorDomain, code: CKError.serviceUnavailable.rawValue)
        ))
        XCTAssertFalse(CloudKitRetryPolicy.isTransient(permanentError()))
        XCTAssertFalse(CloudKitRetryPolicy.isTransient(
            NSError(domain: CKErrorDomain, code: CKError.unknownItem.rawValue)
        ))
        XCTAssertFalse(CloudKitRetryPolicy.isTransient(
            NSError(domain: CKErrorDomain, code: CKError.invalidArguments.rawValue)
        ))
        XCTAssertFalse(CloudKitRetryPolicy.isTransient(
            NSError(domain: CKErrorDomain, code: CKError.quotaExceeded.rawValue)
        ))
        XCTAssertFalse(CloudKitRetryPolicy.isTransient(
            NSError(domain: CKErrorDomain, code: CKError.notAuthenticated.rawValue)
        ))
        XCTAssertFalse(CloudKitRetryPolicy.isTransient(
            NSError(domain: "OtherDomain", code: 3)
        ))
    }
}

#endif

final class CloudFileValidatorReadErrorTests: XCTestCase {
    /// Wenn die Datei nicht geöffnet werden kann, muss `fileNotReadable`
    /// fliegen — nicht stillschweigend `Data()` zurückgegeben werden.
    func testThrowsForNonExistentFile() {
        let url = URL(fileURLWithPath: "/tmp/does-not-exist-\(UUID().uuidString).gpx")
        XCTAssertThrowsError(try CloudFileContentValidator.validate(url: url, expected: .gpx)) { error in
            guard case CloudFileContentValidator.ValidationError.fileNotReadable = error else {
                return XCTFail("Expected fileNotReadable, got \(error)")
            }
        }
    }

    /// Leere Datei → `empty` (nicht `readFailed`).
    func testEmptyFileMapsToEmpty() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("empty-\(UUID().uuidString).gpx")
        FileManager.default.createFile(atPath: url.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try CloudFileContentValidator.validate(url: url, expected: .gpx)) { error in
            guard case CloudFileContentValidator.ValidationError.empty = error else {
                return XCTFail("Expected .empty, got \(error)")
            }
        }
    }

    /// Datei mit Inhalt, der nicht zum erwarteten Format passt →
    /// `formatMismatch`, NICHT `empty` und NICHT `Data()`.
    func testNonMatchingContentMapsToFormatMismatch() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("garbage-\(UUID().uuidString).gpx")
        try Data("not a gpx file".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try CloudFileContentValidator.validate(url: url, expected: .gpx)) { error in
            guard case CloudFileContentValidator.ValidationError.formatMismatch = error else {
                return XCTFail("Expected formatMismatch, got \(error)")
            }
        }
    }
}
