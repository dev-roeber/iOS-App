import XCTest
@testable import LocationHistoryConsumerAppSupport

final class DayFavoritesStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "DayFavoritesStoreTests-\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testLoadReturnsEmptySetInitially() {
        XCTAssertTrue(DayFavoritesStore.load(userDefaults: defaults).isEmpty)
    }

    func testAddInsertsDayIdentifier() {
        DayFavoritesStore.add(dayIdentifier: "2024-05-01", userDefaults: defaults)
        XCTAssertTrue(DayFavoritesStore.contains(dayIdentifier: "2024-05-01", userDefaults: defaults))
    }

    func testRemoveDeletesDayIdentifier() {
        DayFavoritesStore.add(dayIdentifier: "2024-05-01", userDefaults: defaults)
        DayFavoritesStore.remove(dayIdentifier: "2024-05-01", userDefaults: defaults)
        XCTAssertFalse(DayFavoritesStore.contains(dayIdentifier: "2024-05-01", userDefaults: defaults))
    }

    func testToggleAddsThenRemoves() {
        let id = "2024-06-15"
        let added = DayFavoritesStore.toggle(dayIdentifier: id, userDefaults: defaults)
        XCTAssertTrue(added)
        XCTAssertTrue(DayFavoritesStore.contains(dayIdentifier: id, userDefaults: defaults))

        let removed = DayFavoritesStore.toggle(dayIdentifier: id, userDefaults: defaults)
        XCTAssertFalse(removed)
        XCTAssertFalse(DayFavoritesStore.contains(dayIdentifier: id, userDefaults: defaults))
    }

    func testClearRemovesAllFavorites() {
        DayFavoritesStore.add(dayIdentifier: "2024-05-01", userDefaults: defaults)
        DayFavoritesStore.add(dayIdentifier: "2024-05-02", userDefaults: defaults)
        DayFavoritesStore.clear(userDefaults: defaults)
        XCTAssertTrue(DayFavoritesStore.load(userDefaults: defaults).isEmpty)
    }

    func testMultipleDayIdentifiersCanBeStored() {
        let ids = ["2024-01-01", "2024-03-15", "2024-12-31"]
        for id in ids {
            DayFavoritesStore.add(dayIdentifier: id, userDefaults: defaults)
        }
        let loaded = DayFavoritesStore.load(userDefaults: defaults)
        XCTAssertEqual(loaded, Set(ids))
    }

    func testContainsReturnsFalseForUnknownIdentifier() {
        XCTAssertFalse(DayFavoritesStore.contains(dayIdentifier: "2024-07-04", userDefaults: defaults))
    }

    func testPersistenceRoundTrip() {
        // Write with one instance
        DayFavoritesStore.add(dayIdentifier: "2024-11-11", userDefaults: defaults)
        // Read back (simulates re-load)
        let loaded = DayFavoritesStore.load(userDefaults: defaults)
        XCTAssertTrue(loaded.contains("2024-11-11"))
    }
}
