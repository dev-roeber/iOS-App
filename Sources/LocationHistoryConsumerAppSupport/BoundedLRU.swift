import Foundation

/// Foundation-only bounded LRU cache. Insert über `capacity` evictet den
/// am längsten nicht zugegriffenen Key. Lesen markiert den Key als recent.
/// Update eines bestehenden Keys verändert den `count` nicht und schiebt
/// den Key auf "most recent". Nicht thread-safe; Aufrufer muss
/// Concurrency-Schutz selbst stellen (entspricht dem bisherigen
/// Cache-Pattern in `AppSessionContent`, das ebenfalls non-thread-safe ist).
///
/// Deep Audit 2026-05-09 L-04 — eingeführt, um die unbounded Filter-/
/// Projection-Caches in `AppSessionContent` (`filteredOverviewCache`,
/// `filteredDaySummariesCache`, `filteredInsightsCache`, `dayDetailCache`,
/// `dayMapDataCache`) durch eine harte Capacity-Grenze zu schützen. Auch
/// das vorhandene manuelle LRU für `projectedDaysCache` läuft jetzt über
/// diesen Wrapper, damit alle Caches eine gemeinsame, getestete Semantik
/// teilen.
public final class BoundedLRU<Key: Hashable, Value> {
    public let capacity: Int
    private var storage: [Key: Value] = [:]
    /// Insertion-/Touch-Order. Tail = most recently used. Wir nutzen einen
    /// flachen Array mit `firstIndex(of:)`-Lookup statt einer doppelt
    /// verketteten Liste — bei Capacity ≤ 64 (im Repo-Stil dieser Caches)
    /// ist das deutlich einfacher und weiterhin O(capacity), nicht O(n).
    private var order: [Key] = []

    public init(capacity: Int) {
        precondition(capacity > 0, "BoundedLRU capacity must be > 0")
        self.capacity = capacity
        storage.reserveCapacity(capacity)
        order.reserveCapacity(capacity)
    }

    public var count: Int { storage.count }

    public subscript(key: Key) -> Value? {
        get { value(forKey: key) }
        set {
            if let newValue {
                insert(newValue, forKey: key)
            } else {
                _ = removeValue(forKey: key)
            }
        }
    }

    public func value(forKey key: Key) -> Value? {
        guard let value = storage[key] else { return nil }
        touch(key)
        return value
    }

    public func insert(_ value: Value, forKey key: Key) {
        if storage[key] != nil {
            storage[key] = value
            touch(key)
            return
        }
        storage[key] = value
        order.append(key)
        if order.count > capacity {
            let evicted = order.removeFirst()
            storage.removeValue(forKey: evicted)
        }
    }

    @discardableResult
    public func removeValue(forKey key: Key) -> Value? {
        guard let value = storage.removeValue(forKey: key) else { return nil }
        if let index = order.firstIndex(of: key) {
            order.remove(at: index)
        }
        return value
    }

    public func removeAll() {
        storage.removeAll(keepingCapacity: true)
        order.removeAll(keepingCapacity: true)
    }

    /// Most-recently-used Keys zuerst. Nur für Tests/Debug. Die Reihenfolge
    /// ist deterministisch: zuletzt getouchter Key zuerst.
    public var keysMostRecentFirst: [Key] {
        Array(order.reversed())
    }

    private func touch(_ key: Key) {
        guard let index = order.firstIndex(of: key) else { return }
        order.remove(at: index)
        order.append(key)
    }
}
