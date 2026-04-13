import XCTest
@testable import LocationHistoryConsumer
#if canImport(Combine)
@testable import LocationHistoryConsumerAppSupport
#endif

final class ImportedPathMutationTests: XCTestCase {

    // MARK: - Helpers

    private func makePath(pointCount: Int = 2) -> DayDetailViewState.PathItem {
        let points = (0..<pointCount).map { i in
            DayDetailViewState.PathPointItem(
                lat: 48.0 + Double(i) * 0.001,
                lon: 11.0,
                time: nil,
                accuracyM: nil
            )
        }
        return DayDetailViewState.PathItem(
            startTime: nil,
            endTime: nil,
            activityType: "WALKING",
            distanceM: 100.0,
            pointCount: pointCount,
            sourceType: nil,
            points: points
        )
    }

    private func makeDetail(dayKey: String = "2024-05-01", pathCount: Int = 3) -> DayDetailViewState {
        let paths = (0..<pathCount).map { _ in makePath() }
        return DayDetailViewState(
            date: dayKey,
            visits: [],
            activities: [],
            paths: paths,
            totalPathPointCount: paths.reduce(0) { $0 + $1.pointCount },
            hasContent: !paths.isEmpty
        )
    }

    // MARK: - DayDetailViewState.removingDeletedPaths

    func testDeletesCorrectPath() {
        let detail = makeDetail(pathCount: 3)
        let mutations = ImportedPathMutationSet(
            deletions: [ImportedPathDeletion(dayKey: "2024-05-01", pathIndex: 1)]
        )
        let result = detail.removingDeletedPaths(for: mutations)
        XCTAssertEqual(result.paths.count, 2)
    }

    func testPreservesOtherPaths() {
        let detail = makeDetail(pathCount: 3)
        let mutations = ImportedPathMutationSet(
            deletions: [ImportedPathDeletion(dayKey: "2024-05-01", pathIndex: 1)]
        )
        let result = detail.removingDeletedPaths(for: mutations)
        // Original indices 0 and 2 survive
        XCTAssertEqual(result.paths.count, 2)
        XCTAssertEqual(result.totalPathPointCount, 4)
    }

    func testIgnoresUnknownDayKey() {
        let detail = makeDetail(dayKey: "2024-05-01", pathCount: 2)
        let mutations = ImportedPathMutationSet(
            deletions: [ImportedPathDeletion(dayKey: "2024-12-31", pathIndex: 0)]
        )
        let result = detail.removingDeletedPaths(for: mutations)
        XCTAssertEqual(result.paths.count, 2)
        XCTAssertEqual(result, detail)
    }

    func testIgnoresOutOfBoundsIndex() {
        let detail = makeDetail(pathCount: 2)
        let mutations = ImportedPathMutationSet(
            deletions: [ImportedPathDeletion(dayKey: "2024-05-01", pathIndex: 99)]
        )
        let result = detail.removingDeletedPaths(for: mutations)
        XCTAssertEqual(result.paths.count, 2)
    }

    func testEmptyMutationSetLeavesDetailUnchanged() {
        let detail = makeDetail(pathCount: 2)
        let result = detail.removingDeletedPaths(for: .empty)
        XCTAssertEqual(result.paths.count, 2)
    }

    // MARK: - AppImportedPathMutationStore

    #if canImport(Combine)

    func testAddAndPersistDeletion() {
        let suiteName = "test.ImportedPathMutation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = AppImportedPathMutationStore(userDefaults: defaults)

        let deletion = ImportedPathDeletion(dayKey: "2024-05-01", pathIndex: 0)
        store.addDeletion(deletion)

        XCTAssertEqual(store.currentMutations.deletions.count, 1)
        XCTAssertEqual(store.currentMutations.deletions.first, deletion)

        // Reload from same UserDefaults to verify persistence
        let store2 = AppImportedPathMutationStore(userDefaults: defaults)
        XCTAssertEqual(store2.currentMutations.deletions.count, 1)
        XCTAssertEqual(store2.currentMutations.deletions.first, deletion)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testResetClearsAllDeletions() {
        let suiteName = "test.ImportedPathMutation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = AppImportedPathMutationStore(userDefaults: defaults)

        store.addDeletion(ImportedPathDeletion(dayKey: "2024-05-01", pathIndex: 0))
        store.addDeletion(ImportedPathDeletion(dayKey: "2024-05-02", pathIndex: 1))
        XCTAssertEqual(store.currentMutations.deletions.count, 2)

        store.reset()
        XCTAssertTrue(store.currentMutations.deletions.isEmpty)

        // Reload: should also be empty
        let store2 = AppImportedPathMutationStore(userDefaults: defaults)
        XCTAssertTrue(store2.currentMutations.deletions.isEmpty)

        defaults.removePersistentDomain(forName: suiteName)
    }

    #endif
}
