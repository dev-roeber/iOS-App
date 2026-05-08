import Foundation
import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Phase-7B — Presentation-Wrapper über `LocalTimelineDeletionService`.
final class LocalTimelineDeletionPresentationTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LTDelPres-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    private func makePresentation() throws -> LocalTimelineDeletionPresentation {
        let locations = LocalTimelineStorageLocations.temporary(under: tempDir)
        try locations.ensureDirectoriesExist()
        let lifecycle = LocalTimelineStoreLifecycle(locations: locations)
        return LocalTimelineDeletionPresentation(
            service: LocalTimelineDeletionService(lifecycle: lifecycle)
        )
    }

    func testIsAvailableDefaultsTrue() throws {
        let pres = try makePresentation()
        XCTAssertTrue(pres.isAvailable)
    }

    func testPerformDeleteOnEmptyStoreSucceeds() throws {
        let pres = try makePresentation()
        let result = pres.performDelete()
        guard case .deleted = result else {
            return XCTFail("expected .deleted, got \(result)")
        }
        XCTAssertEqual(pres.lastResult, result)
    }

    func testPerformDeleteIsIdempotent() throws {
        let pres = try makePresentation()
        let r1 = pres.performDelete()
        let r2 = pres.performDelete()
        guard case .deleted(let report1) = r1, case .deleted(let report2) = r2 else {
            return XCTFail("expected two .deleted results")
        }
        XCTAssertNil(report1.rowWipeError)
        XCTAssertNil(report2.rowWipeError)
    }

    func testPerformDeleteWipesPopulatedStore() throws {
        let locations = LocalTimelineStorageLocations.temporary(under: tempDir)
        try locations.ensureDirectoriesExist()
        let store = try LocalTimelineStore(url: locations.databaseFileURL)
        let writer = try LocalTimelineImportWriter(store: store, source: "x.json")
        try writer.addVisit(.init(startTime: "2024-01-01T08:00:00Z",
                                  latitude: 48, longitude: 11, name: "H"))
        _ = try writer.finalize()

        let lifecycle = LocalTimelineStoreLifecycle(locations: locations)
        let pres = LocalTimelineDeletionPresentation(
            service: LocalTimelineDeletionService(lifecycle: lifecycle),
            openStoreProvider: { store }
        )
        let result = pres.performDelete()
        guard case let .deleted(report) = result else {
            return XCTFail("expected .deleted, got \(result)")
        }
        XCTAssertTrue(report.didWipeRowsViaStore || !report.removedDBFiles.isEmpty)
    }
}
