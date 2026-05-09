import XCTest
import LocationHistoryConsumerAppSupport

final class BoundedLRUTests: XCTestCase {

    func testInsertAndReadReturnsValue() {
        let cache = BoundedLRU<String, Int>(capacity: 4)
        cache.insert(42, forKey: "a")
        XCTAssertEqual(cache.value(forKey: "a"), 42)
        XCTAssertEqual(cache["a"], 42)
        XCTAssertEqual(cache.count, 1)
    }

    func testReadMakesKeyMostRecent() {
        let cache = BoundedLRU<String, Int>(capacity: 3)
        cache.insert(1, forKey: "a")
        cache.insert(2, forKey: "b")
        cache.insert(3, forKey: "c")
        // Touch "a" — wird most recent.
        _ = cache.value(forKey: "a")
        // Insert "d" — soll least recent ("b") evictieren, nicht "a".
        cache.insert(4, forKey: "d")
        XCTAssertEqual(cache.value(forKey: "a"), 1)
        XCTAssertNil(cache.value(forKey: "b"))
        XCTAssertEqual(cache.value(forKey: "c"), 3)
        XCTAssertEqual(cache.value(forKey: "d"), 4)
        XCTAssertEqual(cache.count, 3)
    }

    func testInsertOverCapacityEvictsLeastRecent() {
        let cache = BoundedLRU<Int, String>(capacity: 2)
        cache.insert("a", forKey: 1)
        cache.insert("b", forKey: 2)
        cache.insert("c", forKey: 3)
        XCTAssertNil(cache.value(forKey: 1))
        XCTAssertEqual(cache.value(forKey: 2), "b")
        XCTAssertEqual(cache.value(forKey: 3), "c")
        XCTAssertEqual(cache.count, 2)
    }

    func testUpdateExistingKeyDoesNotIncreaseCount() {
        let cache = BoundedLRU<String, Int>(capacity: 4)
        cache.insert(1, forKey: "a")
        cache.insert(2, forKey: "a")
        cache.insert(3, forKey: "a")
        XCTAssertEqual(cache.count, 1)
        XCTAssertEqual(cache.value(forKey: "a"), 3)
    }

    func testUpdateExistingKeyMakesItMostRecent() {
        let cache = BoundedLRU<String, Int>(capacity: 2)
        cache.insert(1, forKey: "a")
        cache.insert(2, forKey: "b")
        cache.insert(99, forKey: "a")  // re-insert "a", wird most recent
        cache.insert(3, forKey: "c")    // soll "b" evictieren, nicht "a"
        XCTAssertEqual(cache.value(forKey: "a"), 99)
        XCTAssertNil(cache.value(forKey: "b"))
        XCTAssertEqual(cache.value(forKey: "c"), 3)
    }

    func testRemoveValue() {
        let cache = BoundedLRU<String, Int>(capacity: 4)
        cache.insert(1, forKey: "a")
        cache.insert(2, forKey: "b")
        let removed = cache.removeValue(forKey: "a")
        XCTAssertEqual(removed, 1)
        XCTAssertNil(cache.value(forKey: "a"))
        XCTAssertEqual(cache.count, 1)
        XCTAssertNil(cache.removeValue(forKey: "missing"))
    }

    func testRemoveAll() {
        let cache = BoundedLRU<String, Int>(capacity: 4)
        cache.insert(1, forKey: "a")
        cache.insert(2, forKey: "b")
        cache.removeAll()
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.value(forKey: "a"))
        XCTAssertNil(cache.value(forKey: "b"))
    }

    func testCapacityOneEvictsOnEachInsert() {
        let cache = BoundedLRU<String, Int>(capacity: 1)
        cache.insert(1, forKey: "a")
        cache.insert(2, forKey: "b")
        XCTAssertNil(cache.value(forKey: "a"))
        XCTAssertEqual(cache.value(forKey: "b"), 2)
        XCTAssertEqual(cache.count, 1)
    }

    func testDeterministicEvictionOrder() {
        let cache = BoundedLRU<Int, String>(capacity: 3)
        for i in 0..<10 {
            cache.insert("v\(i)", forKey: i)
        }
        // Cache hält die letzten 3 (7, 8, 9), most recent first.
        XCTAssertEqual(cache.keysMostRecentFirst, [9, 8, 7])
        XCTAssertEqual(cache.count, 3)
    }

    func testKeysMostRecentFirstReflectsTouches() {
        let cache = BoundedLRU<String, Int>(capacity: 3)
        cache.insert(1, forKey: "a")
        cache.insert(2, forKey: "b")
        cache.insert(3, forKey: "c")
        _ = cache.value(forKey: "a")
        XCTAssertEqual(cache.keysMostRecentFirst, ["a", "c", "b"])
    }

    func testSubscriptSetNilRemovesEntry() {
        let cache = BoundedLRU<String, Int>(capacity: 4)
        cache.insert(1, forKey: "a")
        cache["a"] = nil
        XCTAssertNil(cache.value(forKey: "a"))
        XCTAssertEqual(cache.count, 0)
    }

    func testSubscriptSetInsertsValue() {
        let cache = BoundedLRU<String, Int>(capacity: 4)
        cache["a"] = 7
        XCTAssertEqual(cache.value(forKey: "a"), 7)
    }

    func testHighInsertCountRespectsCapacity() {
        let capacity = 16
        let cache = BoundedLRU<Int, Int>(capacity: capacity)
        for i in 0..<10_000 {
            cache.insert(i, forKey: i)
        }
        XCTAssertEqual(cache.count, capacity)
        // Letzte `capacity` Keys sind erhalten.
        for i in (10_000 - capacity)..<10_000 {
            XCTAssertEqual(cache.value(forKey: i), i)
        }
    }
}
