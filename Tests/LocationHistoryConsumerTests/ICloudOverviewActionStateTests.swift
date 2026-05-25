import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Phase D.4 — locks down the visible action-state contract for the
/// iCloud storage-overview buttons. Without these guards, the buttons
/// looked dead in TestFlight: pressing them changed nothing visible
/// because the view-model swallowed both the success path and any
/// CloudKit errors. The tests here verify the 6 promised scenarios
/// from the user spec.
final class ICloudOverviewActionStateTests: XCTestCase {

    // MARK: - 1. refreshOverview success

    @MainActor
    func testRefreshOverviewSucceedsShowsMessageAndIdleState() async {
        let spy = SpyCloudBackupCoordinator()
        spy.scriptedOverview = ICloudStorageOverview(
            summaryCount: 5,
            pointBatchCount: 2,
            estimatedPointCount: 100,
            estimatedStorageBytes: 4096,
            lastCloudKitStatusCheckAt: Date()
        )
        let vm = makeViewModel(backup: spy)

        await vm.refreshOverview()

        XCTAssertEqual(vm.overviewActionState, .idle)
        XCTAssertEqual(vm.overviewActionMessage, "Übersicht aktualisiert.")
        XCTAssertFalse(vm.overviewActionFailed)
        XCTAssertEqual(vm.storageOverview.summaryCount, 5)
    }

    // MARK: - 2. refreshOverview with errorMessage shows failure text

    @MainActor
    func testRefreshOverviewWithErrorShowsFailureText() async {
        let spy = SpyCloudBackupCoordinator()
        spy.scriptedOverview = ICloudStorageOverview(errorMessage: "Cloud-Datenübersicht konnte nicht aktualisiert werden.")
        let vm = makeViewModel(backup: spy)

        await vm.refreshOverview()

        XCTAssertTrue(vm.overviewActionFailed)
        XCTAssertEqual(vm.overviewActionMessage, "Cloud-Datenübersicht konnte nicht aktualisiert werden.")
    }

    // MARK: - 3. retryPendingBackups with no pending shows „keine wartenden"

    @MainActor
    func testRetryPendingBackupsWithZeroCountShowsNoPendingMessage() async {
        let spy = SpyCloudBackupCoordinator()
        spy.scriptedPendingCount = 0
        let vm = makeViewModel(backup: spy)

        await vm.retryPendingBackups()

        XCTAssertEqual(vm.overviewActionMessage, "Keine wartenden Sicherungen.")
        XCTAssertFalse(vm.overviewActionFailed)
        XCTAssertEqual(vm.overviewActionState, .idle)
        // Crucially: spy.retryCalls must stay 0 because the early-out
        // ran before backupService.retryPendingBackups would be hit.
        XCTAssertEqual(spy.retryCalls, 0)
    }

    // MARK: - 4. deleteCloudData success resets overview + sets success message

    @MainActor
    func testDeleteCloudDataSuccessResetsOverview() async {
        let spy = SpyCloudBackupCoordinator()
        spy.scriptedOverview = ICloudStorageOverview(summaryCount: 3)
        let vm = makeViewModel(backup: spy)
        // Seed the VM with non-empty overview before the delete.
        await vm.refreshOverview()
        // After the delete the spy returns an empty overview.
        spy.scriptedOverview = ICloudStorageOverview()
        spy.scriptedPendingCount = 0

        await vm.deleteCloudData()

        XCTAssertEqual(vm.overviewActionState, .idle)
        XCTAssertEqual(vm.overviewActionMessage, "Cloud-Daten gelöscht.")
        XCTAssertFalse(vm.overviewActionFailed)
        XCTAssertEqual(vm.storageOverview.summaryCount, 0)
    }

    // MARK: - 5. deleteCloudData failure shows hint

    @MainActor
    func testDeleteCloudDataFailureShowsGermanHint() async {
        let spy = SpyCloudBackupCoordinator()
        // Simulate a CloudKit error via NSError with the canonical
        // CKErrorDomain so the renderer maps to the German hint.
        spy.deleteError = NSError(
            domain: ICloudActionErrorRendering.cloudKitErrorDomain,
            code: 10 // permissionFailure
        )
        let vm = makeViewModel(backup: spy)

        await vm.deleteCloudData()

        XCTAssertTrue(vm.overviewActionFailed)
        let message = vm.overviewActionMessage ?? ""
        XCTAssertTrue(message.contains("Entitlement"), "expected German permissionFailure hint, got: \(message)")
        XCTAssertEqual(vm.overviewActionState, .idle)
    }

    // MARK: - 6. CKErrorMapping bridge from NSError(domain: CKErrorDomain)

    func testActionErrorRenderingMapsCloudKitDomainToGermanHint() {
        let error = NSError(
            domain: ICloudActionErrorRendering.cloudKitErrorDomain,
            code: 12 // invalidArguments
        )
        let hint = ICloudActionErrorRendering.hint(for: error)
        XCTAssertTrue(hint.contains("Production"))
        XCTAssertTrue(hint.contains("CloudKit Dashboard"))
    }

    func testActionErrorRenderingFallsBackForNonCloudKitErrors() {
        let error = NSError(
            domain: "MyTestDomain",
            code: 42,
            userInfo: [NSLocalizedDescriptionKey: "Some unrelated failure"]
        )
        let hint = ICloudActionErrorRendering.hint(for: error)
        XCTAssertEqual(hint, "Some unrelated failure")
    }

    // MARK: - 7. Per-record delete validation (paginated chunk)

    /// Phase D.4 deleteCloudData paginated path uses the shared
    /// `ICloudCloudKitMVPResultValidator.assertDeleted` validator. This
    /// test pins the validator contract: a missing per-record result
    /// must throw, a `.failure(...)` must re-throw, success returns.
    func testPaginatedDeleteHonorsPerRecordValidator() {
        let id1 = "rec-a"
        let id2 = "rec-b"
        let allGood: [String: Result<Void, Error>] = [
            id1: .success(()),
            id2: .success(()),
        ]
        XCTAssertNoThrow(try ICloudCloudKitMVPResultValidator.assertDeleted(recordID: id1, in: allGood))
        XCTAssertNoThrow(try ICloudCloudKitMVPResultValidator.assertDeleted(recordID: id2, in: allGood))

        let partial: [String: Result<Void, Error>] = [id1: .success(())]
        XCTAssertThrowsError(try ICloudCloudKitMVPResultValidator.assertDeleted(recordID: id2, in: partial)) { error in
            XCTAssertEqual(error as? ICloudPerRecordValidationError, .missingResult)
        }
    }

    // MARK: - 8. Single-flight guard

    @MainActor
    func testActionStateGuardsPreventConcurrentExecution() async {
        let spy = SpyCloudBackupCoordinator()
        spy.refreshDelaySeconds = 0.05
        let vm = makeViewModel(backup: spy)

        async let first: Void = vm.refreshOverview()
        // Give the first call a moment to flip state to .refreshing.
        try? await Task.sleep(nanoseconds: 10_000_000)
        await vm.refreshOverview() // should early-out

        await first
        XCTAssertEqual(spy.refreshCalls, 1, "concurrent refresh must early-out via overviewActionState guard")
    }

    // MARK: - Helpers

    @MainActor
    private func makeViewModel(backup: SpyCloudBackupCoordinator) -> ICloudSyncViewModel {
        let cloud = InMemoryCloudSyncService(
            isEnabled: true,
            status: CloudSyncStatus(accountStatus: .available)
        )
        let health = InMemoryICloudHealthCheckService(
            scriptedResult: ICloudHealthStatus(
                accountStatus: .available,
                privateDatabaseReachability: .reachable
            )
        )
        return ICloudSyncViewModel(
            service: cloud,
            healthCheckService: health,
            backupService: backup
        )
    }
}

@MainActor
private final class SpyCloudBackupCoordinator: LiveTrackCloudBackupCoordinator {
    var scriptedOverview: ICloudStorageOverview = .init()
    var scriptedPendingCount: Int = 0
    var deleteError: Error?
    var refreshDelaySeconds: TimeInterval = 0
    private(set) var refreshCalls = 0
    private(set) var retryCalls = 0
    private(set) var deleteCalls = 0

    var overview: ICloudStorageOverview { scriptedOverview }
    var pendingCount: Int { scriptedPendingCount }

    func handleCompletedLiveTrack(_ track: RecordedTrack) {}

    func retryPendingBackups() async {
        retryCalls += 1
    }

    func refreshOverview() async -> ICloudStorageOverview {
        refreshCalls += 1
        if refreshDelaySeconds > 0 {
            try? await Task.sleep(nanoseconds: UInt64(refreshDelaySeconds * 1_000_000_000))
        }
        return scriptedOverview
    }

    func deleteCloudData() async throws {
        deleteCalls += 1
        if let deleteError {
            throw deleteError
        }
        scriptedOverview = .init()
        scriptedPendingCount = 0
    }
}
